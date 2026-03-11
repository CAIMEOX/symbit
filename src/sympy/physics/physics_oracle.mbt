///|
pub type OracleArg = @sympy.OracleArg

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
}

///|
fn repo_sympy_path_script() -> String {
  "import sys; p='/Users/caimeo/code/learning/sym-workspace/sympy'; sys.path.insert(0, p) if p not in sys.path else None"
}

///|
fn ensure_repo_sympy_path() -> Unit raise {
  match
    @sympy.sympy_call("builtins.exec", [
      OracleArg::Str(repo_sympy_path_script()),
    ]) {
    Some(_) => ()
    None => fail("sympy-call-none:builtins.exec")
  }
}

///|
fn sympy_call_must(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  ignore(
    @sympy.sympy_call("builtins.exec", [
      OracleArg::Str(repo_sympy_path_script()),
    ]),
  ) catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  match @sympy.sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
fn resolve_method_callable(
  obj : @py.PyObject,
  name : String,
) -> @py.PyCallable raise {
  let state = py_gil_ensure()
  let res = try {
    match obj.get_attr(name, print_err=false) {
      Some(PyCallable(callable)) => callable
      Some(other) =>
        @py.PyCallable::create(objenum_to_obj(other)) catch {
          _ => fail("sympy-oracle-callable")
        }
      None => fail("sympy-oracle-missing:\{name}")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  @cpython.py_incref(res.obj_ref())
  py_gil_release(state)
  res
}

///|
fn py_call_noargs(callable : @py.PyCallable) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args([])
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("sympy-oracle-call-none")
  }
}

///|
fn py_call(
  callable : @py.PyCallable,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  let py_kwargs = @sympy.py_pack_kwargs(kwargs)
  match callable.invoke(args=tup, kwargs=py_kwargs, print_err=true) {
    Some(obj) => obj
    None => fail("sympy-oracle-call-none")
  }
}

///|
fn py_list_to_pyobjects(value : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let state = py_gil_ensure()
  let out : Array[@py.PyObject] = Array::new()
  let res = try {
    match value {
      PyList(list) => {
        let len = list.len()
        for i in 0..<len {
          match list.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      PyTuple(tup) => {
        let len = tup.len().to_int()
        for i in 0..<len {
          match tup.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      _ => fail("expected list/tuple")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn try_bind_name(
  globals : @py.PyDict,
  mod : @py.PyModule,
  name : String,
) -> Unit {
  match mod.get_attr(name, print_err=false) {
    Some(obj) => globals.set(name, objenum_to_obj(obj))
    None => ()
  }
}

///|
fn pyimport_with_repo_fallback(module_path : String) -> @py.PyModule raise {
  ensure_repo_sympy_path()
  match @py.pyimport(module_path) {
    Some(v) => v
    None => {
      ignore(
        sympy_call_must("builtins.exec", [
          OracleArg::Str(
            "import sys; sys.path.insert(0, '/Users/caimeo/code/learning/sym-workspace/sympy')",
          ),
        ]),
      )
      match @py.pyimport(module_path) {
        Some(v) => v
        None => fail("python-missing:\{module_path}")
      }
    }
  }
}

///|
fn control_routh_loader_script() -> String {
  "import importlib.util as _iu\n_path = '/Users/caimeo/code/learning/sym-workspace/sympy/sympy/physics/control/routh_table.py'\n_spec = _iu.spec_from_file_location('_symbit_repo_routh_table', _path)\n_mod = _iu.module_from_spec(_spec)\n_spec.loader.exec_module(_mod)\n__symbit_routh_ctor__ = _mod.RouthHurwitz"
}

///|
fn control_routh_ctor() -> @py.PyCallable raise {
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  ignore(
    sympy_call_must("builtins.exec", [
      OracleArg::Str(control_routh_loader_script()),
      OracleArg::PyObj(globals.obj()),
    ]),
  )
  match globals.get("__symbit_routh_ctor__") {
    Some(PyCallable(callable)) => callable
    Some(other) =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("sympy-oracle-callable")
      }
    None => fail("sympy-oracle-missing:__symbit_routh_ctor__")
  }
}

///|
fn physics_globals() -> @py.PyDict raise {
  ensure_repo_sympy_path()
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let sympy_mod = match @py.pyimport("sympy") {
    Some(v) => v
    None => fail("python-missing:sympy")
  }
  let units_mod = match @py.pyimport("sympy.physics.units") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.units")
  }
  let units_prefixes_mod = match @py.pyimport("sympy.physics.units.prefixes") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.units.prefixes")
  }
  let quantum_mod = match @py.pyimport("sympy.physics.quantum") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum")
  }
  let quantum_cg_mod = match @py.pyimport("sympy.physics.quantum.cg") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.cg")
  }
  let quantum_dagger_mod = match @py.pyimport("sympy.physics.quantum.dagger") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.dagger")
  }
  let quantum_hilbert_mod = match
    @py.pyimport("sympy.physics.quantum.hilbert") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.hilbert")
  }
  let quantum_matrixutils_mod = match
    @py.pyimport("sympy.physics.quantum.matrixutils") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.matrixutils")
  }
  let paulialgebra_mod = match @py.pyimport("sympy.physics.paulialgebra") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.paulialgebra")
  }
  let constants_mod = match @py.pyimport("sympy.physics.quantum.constants") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.constants")
  }
  let optics_medium_mod = match @py.pyimport("sympy.physics.optics.medium") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.optics.medium")
  }
  let optics_polarization_mod = match
    @py.pyimport("sympy.physics.optics.polarization") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.optics.polarization")
  }
  let control_routh = control_routh_ctor()
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", sympy_mod.obj())
  for
    name in [
      "Abs", "KroneckerDelta", "I", "Sum", "TensorProduct", "Tuple", "Ynm", "Ynm_c",
      "Znm", "assoc_laguerre", "assoc_legendre", "conjugate", "cos", "exp", "factorial",
      "factorial2", "hermite", "Matrix", "Interval", "pi", "sin", "sqrt", "eye",
      "zeros", "oo",
    ] {
    try_bind_name(globals, sympy_mod, name)
  }
  for
    name in [
      "meter", "second", "kilogram", "ampere", "watt", "m", "s", "kg", "A", "W",
      "speed_of_light", "u0", "e0",
    ] {
    try_bind_name(globals, units_mod, name)
  }
  for
    name in [
      "Prefix", "PREFIXES", "BIN_PREFIXES", "kilo", "mega", "milli", "centi", "deci",
      "kibi",
    ] {
    try_bind_name(globals, units_prefixes_mod, name)
  }
  for name in ["CG", "Wigner3j", "Wigner6j", "Wigner9j"] {
    try_bind_name(globals, quantum_cg_mod, name)
  }
  try_bind_name(globals, quantum_mod, "TensorProduct")
  try_bind_name(globals, quantum_dagger_mod, "Dagger")
  for
    name in [
      "HilbertSpace", "ComplexSpace", "L2", "FockSpace", "TensorProductHilbertSpace",
      "DirectSumHilbertSpace", "TensorPowerHilbertSpace",
    ] {
    try_bind_name(globals, quantum_hilbert_mod, name)
  }
  for
    name in [
      "matrix_dagger", "matrix_tensor_product", "matrix_to_zero", "flatten_scalar",
    ] {
    try_bind_name(globals, quantum_matrixutils_mod, name)
  }
  for name in ["Pauli", "evaluate_pauli_product", "delta", "epsilon"] {
    try_bind_name(globals, paulialgebra_mod, name)
  }
  try_bind_name(globals, optics_medium_mod, "Medium")
  for
    name in [
      "jones_vector", "stokes_vector", "jones_2_stokes", "linear_polarizer", "phase_retarder",
      "half_wave_retarder", "quarter_wave_retarder", "transmissive_filter", "reflective_filter",
      "polarizing_beam_splitter",
    ] {
    try_bind_name(globals, optics_polarization_mod, name)
  }
  globals.set("RouthHurwitz", control_routh.obj())
  for
    name in [
      "a", "b", "b0", "b1", "b2", "b3", "b4", "c", "cp", "alpha", "beta", "gamma",
      "gammap", "theta", "phi", "r", "x", "z", "m", "mu", "m1", "m1p", "m2", "m2p",
      "n", "epsilon", "omega", "nu", "j", "j1", "j2", "j3", "j12", "j13", "j23",
      "j24", "j34", "sigma", "tau", "Z",
    ] {
    let symbol = objenum_to_obj(
      sympy_call_must("sympy.Symbol", [OracleArg::Str(name)]),
    )
    globals.set(name, symbol)
  }
  let q_nc = objenum_to_obj(
    sympy_call_must("sympy.Symbol", [OracleArg::Str("q")], kwargs={
      "commutative": OracleArg::Bool(false),
    }),
  )
  globals.set("q", q_nc)
  for name in ["Aop", "Bop", "Cop", "Dop"] {
    let sym = objenum_to_obj(
      sympy_call_must("sympy.Symbol", [OracleArg::Str(name)], kwargs={
        "commutative": OracleArg::Bool(false),
      }),
    )
    globals.set(name, sym)
  }
  for
    pair in [
      ("sigma1", 1, "sigma"),
      ("sigma2", 2, "sigma"),
      ("sigma3", 3, "sigma"),
      ("tau1", 1, "tau"),
      ("tau2", 2, "tau"),
      ("tau3", 3, "tau"),
    ] {
    let obj = objenum_to_obj(
      sympy_call_must("sympy.physics.paulialgebra.Pauli", [
        OracleArg::Int(pair.1),
        OracleArg::PyObj(
          objenum_to_obj(
            sympy_call_must("sympy.Symbol", [OracleArg::Str(pair.2)]),
          ),
        ),
      ]),
    )
    globals.set(pair.0, obj)
  }
  try_bind_name(globals, constants_mod, "hbar")
  globals
}

///|
fn matrix_flatten_to_strings(matrix_obj : @py.PyObject) -> Array[String] raise {
  let tolist = resolve_method_callable(matrix_obj, "tolist")
  let out : Array[String] = Array::new()
  match py_call_noargs(tolist) {
    PyList(rows) => {
      let row_count = rows.len()
      for i in 0..<row_count {
        match rows.get(i) {
          Some(PyList(cols)) => {
            let col_count = cols.len()
            for j in 0..<col_count {
              match cols.get(j) {
                Some(item) => out.push(py_str_obj(objenum_to_obj(item)))
                None => ()
              }
            }
          }
          Some(PyTuple(cols)) => {
            let col_count = cols.len().to_int()
            for j in 0..<col_count {
              match cols.get(j) {
                Some(item) => out.push(py_str_obj(objenum_to_obj(item)))
                None => ()
              }
            }
          }
          Some(item) => out.push(py_str_obj(objenum_to_obj(item)))
          None => ()
        }
      }
    }
    other =>
      for item in py_list_to_pyobjects(other) {
        out.push(py_str_obj(item))
      }
  }
  out
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let locals = physics_globals()
  let kwargs : Map[String, OracleArg] = {
    "locals": OracleArg::PyObj(locals.obj()),
  }
  let lhs_obj = objenum_to_obj(
    sympy_call_must("sympy.sympify", [OracleArg::Str(lhs)], kwargs~),
  )
  let rhs_obj = objenum_to_obj(
    sympy_call_must("sympy.sympify", [OracleArg::Str(rhs)], kwargs~),
  )
  let lhs_expanded = objenum_to_obj(
    sympy_call_must("sympy.expand_func", [OracleArg::PyObj(lhs_obj)]),
  )
  let rhs_expanded = objenum_to_obj(
    sympy_call_must("sympy.expand_func", [OracleArg::PyObj(rhs_obj)]),
  )
  match
    @sympy.sympy_call("sympy.Eq", [
      OracleArg::PyObj(lhs_expanded),
      OracleArg::PyObj(rhs_expanded),
    ]) {
    Some(eq_obj) => {
      let simp = sympy_call_must("sympy.simplify", [
        OracleArg::PyObj(objenum_to_obj(eq_obj)),
      ])
      let txt = py_str_obj(objenum_to_obj(simp))
      if txt == "True" {
        return true
      }
      if txt == "False" {
        return false
      }
    }
    None => ()
  }
  let lhs_srepr = sympy_call_must("sympy.srepr", [
    OracleArg::PyObj(lhs_expanded),
  ])
  let rhs_srepr = sympy_call_must("sympy.srepr", [
    OracleArg::PyObj(rhs_expanded),
  ])
  py_str_obj(objenum_to_obj(lhs_srepr)) == py_str_obj(objenum_to_obj(rhs_srepr))
}

///|
fn physics_sympify(expr : String) -> @py.PyObject raise {
  let locals = physics_globals()
  let kwargs : Map[String, OracleArg] = {
    "locals": OracleArg::PyObj(locals.obj()),
  }
  objenum_to_obj(
    sympy_call_must("sympy.sympify", [OracleArg::Str(expr)], kwargs~),
  )
}

///|
pub fn msigma(index : Int) -> Array[String] raise {
  let obj = sympy_call_must("sympy.physics.matrices.msigma", [
    OracleArg::Int(index),
  ])
  matrix_flatten_to_strings(objenum_to_obj(obj))
}

///|
pub fn mgamma(index : Int, lower? : Bool = false) -> Array[String] raise {
  let obj = sympy_call_must("sympy.physics.matrices.mgamma", [
    OracleArg::Int(index),
    OracleArg::Bool(lower),
  ])
  matrix_flatten_to_strings(objenum_to_obj(obj))
}

///|
pub fn pat_matrix(
  m : @symcore.Expr,
  dx : @symcore.Expr,
  dy : @symcore.Expr,
  dz : @symcore.Expr,
) -> Array[String] raise {
  let obj = sympy_call_must("sympy.physics.matrices.pat_matrix", [
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(dx)),
    OracleArg::PyObj(expr_to_sympy(dy)),
    OracleArg::PyObj(expr_to_sympy(dz)),
  ])
  matrix_flatten_to_strings(objenum_to_obj(obj))
}

///|
pub fn minkowski_tensor() -> Array[String] raise {
  let mod = match @py.pyimport("sympy.physics.matrices") {
    Some(value) => value
    None => fail("sympy-missing:physics.matrices")
  }
  match mod.get_attr("minkowski_tensor", print_err=false) {
    Some(obj) => matrix_flatten_to_strings(objenum_to_obj(obj))
    None => fail("sympy-missing:minkowski_tensor")
  }
}

///|
pub fn mdft(n : Int) -> Array[String] raise {
  let dft = sympy_call_must("sympy.matrices.expressions.fourier.DFT", [
    OracleArg::Int(n),
  ])
  let as_explicit = resolve_method_callable(objenum_to_obj(dft), "as_explicit")
  matrix_flatten_to_strings(objenum_to_obj(py_call_noargs(as_explicit)))
}

///|
pub fn psi_n(
  n : @symcore.Expr,
  x : @symcore.Expr,
  m : @symcore.Expr,
  omega : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.qho_1d.psi_n", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(x)),
        OracleArg::PyObj(expr_to_sympy(m)),
        OracleArg::PyObj(expr_to_sympy(omega)),
      ]),
    ),
  )
}

///|
pub fn e_n(n : @symcore.Expr, omega : @symcore.Expr) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.qho_1d.E_n", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(omega)),
      ]),
    ),
  )
}

///|
pub fn coherent_state(n : @symcore.Expr, alpha : @symcore.Expr) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.qho_1d.coherent_state", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(alpha)),
      ]),
    ),
  )
}

///|
pub fn r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  nu : @symcore.Expr,
  r : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.sho.R_nl", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(l)),
        OracleArg::PyObj(expr_to_sympy(nu)),
        OracleArg::PyObj(expr_to_sympy(r)),
      ]),
    ),
  )
}

///|
pub fn e_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  hw : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.sho.E_nl", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(l)),
        OracleArg::PyObj(expr_to_sympy(hw)),
      ]),
    ),
  )
}

///|
pub fn hydrogen_r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  r : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.hydrogen.R_nl", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(l)),
        OracleArg::PyObj(expr_to_sympy(r)),
        OracleArg::PyObj(expr_to_sympy(z)),
      ]),
    ),
  )
}

///|
pub fn hydrogen_y_lm(
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> String raise {
  let obj = sympy_call_must("sympy.Ynm", [
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(theta)),
    OracleArg::PyObj(expr_to_sympy(phi)),
  ])
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.expand_func", [
        OracleArg::PyObj(objenum_to_obj(obj)),
      ]),
    ),
  )
}

///|
pub fn hydrogen_z_lm(
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> String raise {
  let obj = sympy_call_must("sympy.Znm", [
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(theta)),
    OracleArg::PyObj(expr_to_sympy(phi)),
  ])
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.expand_func", [
        OracleArg::PyObj(objenum_to_obj(obj)),
      ]),
    ),
  )
}

///|
pub fn hydrogen_psi_nlm(
  n : @symcore.Expr,
  l : @symcore.Expr,
  m : @symcore.Expr,
  r : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.hydrogen.Psi_nlm", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(l)),
        OracleArg::PyObj(expr_to_sympy(m)),
        OracleArg::PyObj(expr_to_sympy(r)),
        OracleArg::PyObj(expr_to_sympy(phi)),
        OracleArg::PyObj(expr_to_sympy(theta)),
        OracleArg::PyObj(expr_to_sympy(z)),
      ]),
    ),
  )
}

///|
pub fn hydrogen_e_nl(
  n : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.hydrogen.E_nl", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(z)),
      ]),
    ),
  )
}

///|
pub fn hydrogen_e_nl_dirac(
  n : @symcore.Expr,
  l : @symcore.Expr,
  spin_up? : Bool = true,
  z? : @symcore.Expr = @symcore.int(1),
  c~ : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.hydrogen.E_nl_dirac", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(l)),
        OracleArg::Bool(spin_up),
        OracleArg::PyObj(expr_to_sympy(z)),
        OracleArg::PyObj(expr_to_sympy(c)),
      ]),
    ),
  )
}

///|
pub fn wigner_3j(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  m_1 : @symcore.Expr,
  m_2 : @symcore.Expr,
  m_3 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.wigner_3j", [
        OracleArg::PyObj(expr_to_sympy(j_1)),
        OracleArg::PyObj(expr_to_sympy(j_2)),
        OracleArg::PyObj(expr_to_sympy(j_3)),
        OracleArg::PyObj(expr_to_sympy(m_1)),
        OracleArg::PyObj(expr_to_sympy(m_2)),
        OracleArg::PyObj(expr_to_sympy(m_3)),
      ]),
    ),
  )
}

///|
pub fn clebsch_gordan(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  m_1 : @symcore.Expr,
  m_2 : @symcore.Expr,
  m_3 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.clebsch_gordan", [
        OracleArg::PyObj(expr_to_sympy(j_1)),
        OracleArg::PyObj(expr_to_sympy(j_2)),
        OracleArg::PyObj(expr_to_sympy(j_3)),
        OracleArg::PyObj(expr_to_sympy(m_1)),
        OracleArg::PyObj(expr_to_sympy(m_2)),
        OracleArg::PyObj(expr_to_sympy(m_3)),
      ]),
    ),
  )
}

///|
pub fn gaunt(
  l_1 : @symcore.Expr,
  l_2 : @symcore.Expr,
  l_3 : @symcore.Expr,
  m_1 : @symcore.Expr,
  m_2 : @symcore.Expr,
  m_3 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.gaunt", [
        OracleArg::PyObj(expr_to_sympy(l_1)),
        OracleArg::PyObj(expr_to_sympy(l_2)),
        OracleArg::PyObj(expr_to_sympy(l_3)),
        OracleArg::PyObj(expr_to_sympy(m_1)),
        OracleArg::PyObj(expr_to_sympy(m_2)),
        OracleArg::PyObj(expr_to_sympy(m_3)),
      ]),
    ),
  )
}

///|
pub fn wigner_6j(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  j_4 : @symcore.Expr,
  j_5 : @symcore.Expr,
  j_6 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.wigner_6j", [
        OracleArg::PyObj(expr_to_sympy(j_1)),
        OracleArg::PyObj(expr_to_sympy(j_2)),
        OracleArg::PyObj(expr_to_sympy(j_3)),
        OracleArg::PyObj(expr_to_sympy(j_4)),
        OracleArg::PyObj(expr_to_sympy(j_5)),
        OracleArg::PyObj(expr_to_sympy(j_6)),
      ]),
    ),
  )
}

///|
pub fn racah(
  aa : @symcore.Expr,
  bb : @symcore.Expr,
  cc : @symcore.Expr,
  dd : @symcore.Expr,
  ee : @symcore.Expr,
  ff : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.racah", [
        OracleArg::PyObj(expr_to_sympy(aa)),
        OracleArg::PyObj(expr_to_sympy(bb)),
        OracleArg::PyObj(expr_to_sympy(cc)),
        OracleArg::PyObj(expr_to_sympy(dd)),
        OracleArg::PyObj(expr_to_sympy(ee)),
        OracleArg::PyObj(expr_to_sympy(ff)),
      ]),
    ),
  )
}

///|
pub fn wigner_9j(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  j_4 : @symcore.Expr,
  j_5 : @symcore.Expr,
  j_6 : @symcore.Expr,
  j_7 : @symcore.Expr,
  j_8 : @symcore.Expr,
  j_9 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.wigner_9j", [
        OracleArg::PyObj(expr_to_sympy(j_1)),
        OracleArg::PyObj(expr_to_sympy(j_2)),
        OracleArg::PyObj(expr_to_sympy(j_3)),
        OracleArg::PyObj(expr_to_sympy(j_4)),
        OracleArg::PyObj(expr_to_sympy(j_5)),
        OracleArg::PyObj(expr_to_sympy(j_6)),
        OracleArg::PyObj(expr_to_sympy(j_7)),
        OracleArg::PyObj(expr_to_sympy(j_8)),
        OracleArg::PyObj(expr_to_sympy(j_9)),
      ]),
    ),
  )
}

///|
pub fn real_gaunt(
  l_1 : @symcore.Expr,
  l_2 : @symcore.Expr,
  l_3 : @symcore.Expr,
  mu_1 : @symcore.Expr,
  mu_2 : @symcore.Expr,
  mu_3 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.wigner.real_gaunt", [
        OracleArg::PyObj(expr_to_sympy(l_1)),
        OracleArg::PyObj(expr_to_sympy(l_2)),
        OracleArg::PyObj(expr_to_sympy(l_3)),
        OracleArg::PyObj(expr_to_sympy(mu_1)),
        OracleArg::PyObj(expr_to_sympy(mu_2)),
        OracleArg::PyObj(expr_to_sympy(mu_3)),
      ]),
    ),
  )
}

///|
pub fn dot_rot_grad_ynm(
  j : @symcore.Expr,
  p : @symcore.Expr,
  l : @symcore.Expr,
  m : @symcore.Expr,
  theta : @symcore.Expr,
  phi : @symcore.Expr,
) -> String raise {
  let obj = sympy_call_must("sympy.physics.wigner.dot_rot_grad_Ynm", [
    OracleArg::PyObj(expr_to_sympy(j)),
    OracleArg::PyObj(expr_to_sympy(p)),
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(theta)),
    OracleArg::PyObj(expr_to_sympy(phi)),
  ])
  let doit = resolve_method_callable(objenum_to_obj(obj), "doit")
  py_str_obj(objenum_to_obj(py_call_noargs(doit)))
}

///|
pub fn wigner_d_small(
  j_tot : @symcore.Expr,
  beta : @symcore.Expr,
) -> Array[String] raise {
  let obj = sympy_call_must("sympy.physics.wigner.wigner_d_small", [
    OracleArg::PyObj(expr_to_sympy(j_tot)),
    OracleArg::PyObj(expr_to_sympy(beta)),
  ])
  matrix_flatten_to_strings(objenum_to_obj(obj))
}

///|
pub fn wigner_d(
  j_tot : @symcore.Expr,
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> Array[String] raise {
  let obj = sympy_call_must("sympy.physics.wigner.wigner_d", [
    OracleArg::PyObj(expr_to_sympy(j_tot)),
    OracleArg::PyObj(expr_to_sympy(alpha)),
    OracleArg::PyObj(expr_to_sympy(beta)),
    OracleArg::PyObj(expr_to_sympy(gamma)),
  ])
  matrix_flatten_to_strings(objenum_to_obj(obj))
}

///|
pub fn wavefunction(n : @symcore.Expr, x : @symcore.Expr) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.pring.wavefunction", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(x)),
      ]),
    ),
  )
}

///|
pub fn energy(
  n : @symcore.Expr,
  m : @symcore.Expr,
  r : @symcore.Expr,
) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.pring.energy", [
        OracleArg::PyObj(expr_to_sympy(n)),
        OracleArg::PyObj(expr_to_sympy(m)),
        OracleArg::PyObj(expr_to_sympy(r)),
      ]),
    ),
  )
}

///|
fn quantum_cg_obj(name : String, args : Array[OracleArg]) -> @py.PyObject raise {
  objenum_to_obj(sympy_call_must("sympy.physics.quantum.cg.\{name}", args))
}

///|
pub fn quantum_wigner3j_expr(
  j1 : @symcore.Expr,
  m1 : @symcore.Expr,
  j2 : @symcore.Expr,
  m2 : @symcore.Expr,
  j3 : @symcore.Expr,
  m3 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    quantum_cg_obj("Wigner3j", [
      OracleArg::PyObj(expr_to_sympy(j1)),
      OracleArg::PyObj(expr_to_sympy(m1)),
      OracleArg::PyObj(expr_to_sympy(j2)),
      OracleArg::PyObj(expr_to_sympy(m2)),
      OracleArg::PyObj(expr_to_sympy(j3)),
      OracleArg::PyObj(expr_to_sympy(m3)),
    ]),
  )
}

///|
pub fn quantum_wigner3j_doit(
  j1 : @symcore.Expr,
  m1 : @symcore.Expr,
  j2 : @symcore.Expr,
  m2 : @symcore.Expr,
  j3 : @symcore.Expr,
  m3 : @symcore.Expr,
) -> String raise {
  let obj = quantum_cg_obj("Wigner3j", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(m1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(m2)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(m3)),
  ])
  let doit = resolve_method_callable(obj, "doit")
  py_str_obj(objenum_to_obj(py_call_noargs(doit)))
}

///|
pub fn quantum_cg_expr(
  j1 : @symcore.Expr,
  m1 : @symcore.Expr,
  j2 : @symcore.Expr,
  m2 : @symcore.Expr,
  j3 : @symcore.Expr,
  m3 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    quantum_cg_obj("CG", [
      OracleArg::PyObj(expr_to_sympy(j1)),
      OracleArg::PyObj(expr_to_sympy(m1)),
      OracleArg::PyObj(expr_to_sympy(j2)),
      OracleArg::PyObj(expr_to_sympy(m2)),
      OracleArg::PyObj(expr_to_sympy(j3)),
      OracleArg::PyObj(expr_to_sympy(m3)),
    ]),
  )
}

///|
pub fn quantum_cg_doit(
  j1 : @symcore.Expr,
  m1 : @symcore.Expr,
  j2 : @symcore.Expr,
  m2 : @symcore.Expr,
  j3 : @symcore.Expr,
  m3 : @symcore.Expr,
) -> String raise {
  let obj = quantum_cg_obj("CG", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(m1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(m2)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(m3)),
  ])
  let doit = resolve_method_callable(obj, "doit")
  py_str_obj(objenum_to_obj(py_call_noargs(doit)))
}

///|
pub fn quantum_wigner6j_expr(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
  j12 : @symcore.Expr,
  j3 : @symcore.Expr,
  j : @symcore.Expr,
  j23 : @symcore.Expr,
) -> String raise {
  py_str_obj(
    quantum_cg_obj("Wigner6j", [
      OracleArg::PyObj(expr_to_sympy(j1)),
      OracleArg::PyObj(expr_to_sympy(j2)),
      OracleArg::PyObj(expr_to_sympy(j12)),
      OracleArg::PyObj(expr_to_sympy(j3)),
      OracleArg::PyObj(expr_to_sympy(j)),
      OracleArg::PyObj(expr_to_sympy(j23)),
    ]),
  )
}

///|
pub fn quantum_wigner6j_doit(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
  j12 : @symcore.Expr,
  j3 : @symcore.Expr,
  j : @symcore.Expr,
  j23 : @symcore.Expr,
) -> String raise {
  let obj = quantum_cg_obj("Wigner6j", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(j12)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(j)),
    OracleArg::PyObj(expr_to_sympy(j23)),
  ])
  let doit = resolve_method_callable(obj, "doit")
  py_str_obj(objenum_to_obj(py_call_noargs(doit)))
}

///|
pub fn quantum_wigner9j_expr(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
  j12 : @symcore.Expr,
  j3 : @symcore.Expr,
  j4 : @symcore.Expr,
  j34 : @symcore.Expr,
  j13 : @symcore.Expr,
  j24 : @symcore.Expr,
  j : @symcore.Expr,
) -> String raise {
  py_str_obj(
    quantum_cg_obj("Wigner9j", [
      OracleArg::PyObj(expr_to_sympy(j1)),
      OracleArg::PyObj(expr_to_sympy(j2)),
      OracleArg::PyObj(expr_to_sympy(j12)),
      OracleArg::PyObj(expr_to_sympy(j3)),
      OracleArg::PyObj(expr_to_sympy(j4)),
      OracleArg::PyObj(expr_to_sympy(j34)),
      OracleArg::PyObj(expr_to_sympy(j13)),
      OracleArg::PyObj(expr_to_sympy(j24)),
      OracleArg::PyObj(expr_to_sympy(j)),
    ]),
  )
}

///|
pub fn quantum_wigner9j_doit(
  j1 : @symcore.Expr,
  j2 : @symcore.Expr,
  j12 : @symcore.Expr,
  j3 : @symcore.Expr,
  j4 : @symcore.Expr,
  j34 : @symcore.Expr,
  j13 : @symcore.Expr,
  j24 : @symcore.Expr,
  j : @symcore.Expr,
) -> String raise {
  let obj = quantum_cg_obj("Wigner9j", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(j12)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(j4)),
    OracleArg::PyObj(expr_to_sympy(j34)),
    OracleArg::PyObj(expr_to_sympy(j13)),
    OracleArg::PyObj(expr_to_sympy(j24)),
    OracleArg::PyObj(expr_to_sympy(j)),
  ])
  let doit = resolve_method_callable(obj, "doit")
  py_str_obj(objenum_to_obj(py_call_noargs(doit)))
}

///|
pub fn quantum_cg_simp(expr : String) -> String raise {
  let obj = physics_sympify(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.quantum.cg.cg_simp", [
        OracleArg::PyObj(obj),
      ]),
    ),
  )
}

///|
pub fn paulialgebra_delta(i : Int, j : Int) -> Int raise {
  let out = sympy_call_must("sympy.physics.paulialgebra.delta", [
    OracleArg::Int(i),
    OracleArg::Int(j),
  ])
  @strconv.parse_int(py_str_obj(objenum_to_obj(out))) catch {
    _ => fail("parse-int")
  }
}

///|
pub fn paulialgebra_epsilon(i : Int, j : Int, k : Int) -> Int raise {
  let out = sympy_call_must("sympy.physics.paulialgebra.epsilon", [
    OracleArg::Int(i),
    OracleArg::Int(j),
    OracleArg::Int(k),
  ])
  @strconv.parse_int(py_str_obj(objenum_to_obj(out))) catch {
    _ => fail("parse-int")
  }
}

///|
pub fn paulialgebra_evaluate(expr : String) -> String raise {
  let obj = physics_sympify(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.physics.paulialgebra.evaluate_pauli_product", [
        OracleArg::PyObj(obj),
      ]),
    ),
  )
}

///|
pub fn physics_srepr(expr : String) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.srepr", [OracleArg::PyObj(physics_sympify(expr))]),
    ),
  )
}

///|
pub fn physics_eval_str(expr : String) -> String raise {
  py_str_obj(physics_sympify(expr))
}

///|
pub fn physics_expr_str(expr : @symcore.Expr) -> String raise {
  py_str_obj(expr_to_sympy(expr))
}

///|
pub fn physics_eval_matrix(expr : String) -> Array[String] raise {
  matrix_flatten_to_strings(physics_sympify(expr))
}

///|
pub fn optics_polarization_matrix(
  name : String,
  args : Array[@symcore.Expr],
) -> Array[String] raise {
  let rendered_args : Array[String] = Array::new()
  for arg in args {
    rendered_args.push(
      "sympify(" + python_string_literal(@symprint.to_string(arg)) + ")",
    )
  }
  let txt = python_subprocess_stdout(
    [
      "from sympy import sympify\n",
      "from sympy.physics.optics.polarization import ",
      name,
      "\n",
      "obj = ",
      name,
      "(",
      rendered_args.join(", "),
      ")\n",
      "print(chr(31).join(str(c) for row in obj.tolist() for c in row))",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
fn python_string_literal(value : String) -> String {
  let escaped = value
    .replace(old="\\", new="\\\\")
    .replace(old="'", new="\\'")
    .replace(old="\n", new="\\n")
  "'\{escaped}'"
}

///|
fn python_subprocess_stdout(script : String) -> String raise {
  let subprocess_mod = match @py.pyimport("subprocess") {
    Some(mod) => mod
    None => fail("python-missing:subprocess")
  }
  let check_output = resolve_method_callable(
    subprocess_mod.obj(),
    "check_output",
  )
  let out = objenum_to_obj(
    py_call(
      check_output,
      [
        OracleArg::StrList(["/Users/caimeo/miniconda3/bin/python", "-c", script]),
      ],
      kwargs={ "text": OracleArg::Bool(true) },
    ),
  )
  py_str_obj(out).trim().to_string()
}

///|
fn control_routh_script(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
  command : String,
) -> String raise {
  let poly_txt = @symprint.to_string(polynomial)
  let var_txt = @symprint.to_string(variable)
  [
    "import sys\n",
    "sys.path.insert(0, '/Users/caimeo/code/learning/sym-workspace/sympy')\n",
    "from sympy import Symbol, sympify\n",
    "from sympy.physics.control.routh_table import RouthHurwitz\n",
    "var = Symbol(",
    python_string_literal(var_txt),
    ")\n",
    "poly = sympify(",
    python_string_literal(poly_txt),
    ", locals={",
    python_string_literal(var_txt),
    ": var})\n",
    "obj = RouthHurwitz(poly, var)\n",
    command,
  ].join("")
}

///|
pub fn control_routh_table_matrix(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> Array[String] raise {
  let txt = python_subprocess_stdout(
    control_routh_script(
      polynomial, variable, "print(chr(31).join(str(c) for row in obj.tolist() for c in row))",
    ),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
pub fn control_routh_zero_col_infos(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> String raise {
  python_subprocess_stdout(
    control_routh_script(polynomial, variable, "print(obj.zero_col_infos)"),
  )
}

///|
pub fn control_routh_zero_row_case(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> String raise {
  python_subprocess_stdout(
    control_routh_script(polynomial, variable, "print(obj.zero_row_case)"),
  )
}

///|
pub fn control_routh_auxiliary_expr(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
  index : Int,
) -> String raise {
  python_subprocess_stdout(
    control_routh_script(
      polynomial,
      variable,
      "print(obj.auxiliary_polynomials[\{index}].as_expr())",
    ),
  )
}

///|
pub fn control_expr_equivalent(lhs : @symcore.Expr, rhs : String) -> Bool raise {
  let lhs_txt = @symprint.to_string(lhs)
  let txt = python_subprocess_stdout(
    [
      "import sys\n",
      "sys.path.insert(0, '/Users/caimeo/code/learning/sym-workspace/sympy')\n",
      "from sympy import Symbol, simplify, sympify\n",
      "names = ['z', 'b0', 'b1', 'b2', 'b3', 'b4']\n",
      "locals_map = {name: Symbol(name) for name in names}\n",
      "lhs = sympify(",
      python_string_literal(lhs_txt),
      ", locals=locals_map)\n",
      "rhs = sympify(",
      python_string_literal(rhs),
      ", locals=locals_map)\n",
      "print(simplify(lhs - rhs) == 0)\n",
    ].join(""),
  )
  txt == "True"
}

///|
pub fn paulialgebra_evaluate_srepr(expr : String) -> String raise {
  let obj = physics_sympify(expr)
  let res = objenum_to_obj(
    sympy_call_must("sympy.physics.paulialgebra.evaluate_pauli_product", [
      OracleArg::PyObj(obj),
    ]),
  )
  py_str_obj(
    objenum_to_obj(sympy_call_must("sympy.srepr", [OracleArg::PyObj(res)])),
  )
}

///|
pub fn optics_medium_property(
  property : String,
  name : String,
  permittivity? : @symcore.Expr? = None,
  permeability? : @symcore.Expr? = None,
  n? : @symcore.Expr? = None,
) -> String raise {
  let args : Array[String] = ["'\{name}'"]
  match permittivity {
    Some(value) => args.push("permittivity=\{@symprint.to_string(value)}")
    None => ()
  }
  match permeability {
    Some(value) => args.push("permeability=\{@symprint.to_string(value)}")
    None => ()
  }
  match n {
    Some(value) => args.push("n=\{@symprint.to_string(value)}")
    None => ()
  }
  let rendered_args = args.join(", ")
  physics_eval_str("Medium(\{rendered_args}).\{property}")
}
