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
fn sympy_call_must(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
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
fn physics_globals() -> @py.PyDict raise {
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let sympy_mod = match @py.pyimport("sympy") {
    Some(v) => v
    None => fail("python-missing:sympy")
  }
  let quantum_cg_mod = match @py.pyimport("sympy.physics.quantum.cg") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.cg")
  }
  let constants_mod = match @py.pyimport("sympy.physics.quantum.constants") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.constants")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", sympy_mod.obj())
  for name in [
    "Abs",
    "KroneckerDelta",
    "I",
    "Sum",
    "Tuple",
    "Ynm",
    "Ynm_c",
    "Znm",
    "assoc_laguerre",
    "assoc_legendre",
    "conjugate",
    "cos",
    "exp",
    "factorial",
    "factorial2",
    "hermite",
    "pi",
    "sin",
    "sqrt",
  ] {
    try_bind_name(globals, sympy_mod, name)
  }
  for name in ["CG", "Wigner3j", "Wigner6j", "Wigner9j"] {
    try_bind_name(globals, quantum_cg_mod, name)
  }
  for name in [
    "a",
    "b",
    "c",
    "cp",
    "alpha",
    "beta",
    "gamma",
    "gammap",
    "theta",
    "phi",
    "r",
    "x",
    "m",
    "m1",
    "m1p",
    "m2",
    "m2p",
    "n",
    "omega",
    "nu",
    "j",
    "j1",
    "j2",
    "j3",
    "j12",
    "j13",
    "j23",
    "j24",
    "j34",
    "Z",
  ] {
    let symbol = objenum_to_obj(sympy_call_must("sympy.Symbol", [OracleArg::Str(name)]))
    globals.set(name, symbol)
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
    other => {
      for item in py_list_to_pyobjects(other) {
        out.push(py_str_obj(item))
      }
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
  let lhs_srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(lhs_expanded)])
  let rhs_srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(rhs_expanded)])
  py_str_obj(objenum_to_obj(lhs_srepr)) == py_str_obj(objenum_to_obj(rhs_srepr))
}

///|
fn physics_sympify(expr : String) -> @py.PyObject raise {
  let locals = physics_globals()
  let kwargs : Map[String, OracleArg] = {
    "locals": OracleArg::PyObj(locals.obj()),
  }
  objenum_to_obj(sympy_call_must("sympy.sympify", [OracleArg::Str(expr)], kwargs~))
}

///|
pub fn msigma(index : Int) -> Array[String] raise {
  let obj = sympy_call_must("sympy.physics.matrices.msigma", [OracleArg::Int(index)])
  matrix_flatten_to_strings(objenum_to_obj(obj))
}

///|
pub fn mgamma(index : Int, lower? : Bool = false) -> Array[String] raise {
  let obj = sympy_call_must(
    "sympy.physics.matrices.mgamma",
    [OracleArg::Int(index), OracleArg::Bool(lower)],
  )
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
  let dft = sympy_call_must("sympy.matrices.expressions.fourier.DFT", [OracleArg::Int(n)])
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.qho_1d.psi_n", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(x)),
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(omega)),
  ])))
}

///|
pub fn e_n(n : @symcore.Expr, omega : @symcore.Expr) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.qho_1d.E_n", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(omega)),
  ])))
}

///|
pub fn coherent_state(n : @symcore.Expr, alpha : @symcore.Expr) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.qho_1d.coherent_state", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(alpha)),
  ])))
}

///|
pub fn r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  nu : @symcore.Expr,
  r : @symcore.Expr,
) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.sho.R_nl", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(nu)),
    OracleArg::PyObj(expr_to_sympy(r)),
  ])))
}

///|
pub fn e_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  hw : @symcore.Expr,
) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.sho.E_nl", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(hw)),
  ])))
}

///|
pub fn hydrogen_r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  r : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.hydrogen.R_nl", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(r)),
    OracleArg::PyObj(expr_to_sympy(z)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.expand_func", [OracleArg::PyObj(objenum_to_obj(obj))])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.expand_func", [OracleArg::PyObj(objenum_to_obj(obj))])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.hydrogen.Psi_nlm", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(r)),
    OracleArg::PyObj(expr_to_sympy(phi)),
    OracleArg::PyObj(expr_to_sympy(theta)),
    OracleArg::PyObj(expr_to_sympy(z)),
  ])))
}

///|
pub fn hydrogen_e_nl(
  n : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.hydrogen.E_nl", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(z)),
  ])))
}

///|
pub fn hydrogen_e_nl_dirac(
  n : @symcore.Expr,
  l : @symcore.Expr,
  spin_up? : Bool = true,
  z? : @symcore.Expr = @symcore.int(1),
  c~ : @symcore.Expr,
) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.hydrogen.E_nl_dirac", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(l)),
    OracleArg::Bool(spin_up),
    OracleArg::PyObj(expr_to_sympy(z)),
    OracleArg::PyObj(expr_to_sympy(c)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.wigner_3j", [
    OracleArg::PyObj(expr_to_sympy(j_1)),
    OracleArg::PyObj(expr_to_sympy(j_2)),
    OracleArg::PyObj(expr_to_sympy(j_3)),
    OracleArg::PyObj(expr_to_sympy(m_1)),
    OracleArg::PyObj(expr_to_sympy(m_2)),
    OracleArg::PyObj(expr_to_sympy(m_3)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.clebsch_gordan", [
    OracleArg::PyObj(expr_to_sympy(j_1)),
    OracleArg::PyObj(expr_to_sympy(j_2)),
    OracleArg::PyObj(expr_to_sympy(j_3)),
    OracleArg::PyObj(expr_to_sympy(m_1)),
    OracleArg::PyObj(expr_to_sympy(m_2)),
    OracleArg::PyObj(expr_to_sympy(m_3)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.gaunt", [
    OracleArg::PyObj(expr_to_sympy(l_1)),
    OracleArg::PyObj(expr_to_sympy(l_2)),
    OracleArg::PyObj(expr_to_sympy(l_3)),
    OracleArg::PyObj(expr_to_sympy(m_1)),
    OracleArg::PyObj(expr_to_sympy(m_2)),
    OracleArg::PyObj(expr_to_sympy(m_3)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.wigner_6j", [
    OracleArg::PyObj(expr_to_sympy(j_1)),
    OracleArg::PyObj(expr_to_sympy(j_2)),
    OracleArg::PyObj(expr_to_sympy(j_3)),
    OracleArg::PyObj(expr_to_sympy(j_4)),
    OracleArg::PyObj(expr_to_sympy(j_5)),
    OracleArg::PyObj(expr_to_sympy(j_6)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.racah", [
    OracleArg::PyObj(expr_to_sympy(aa)),
    OracleArg::PyObj(expr_to_sympy(bb)),
    OracleArg::PyObj(expr_to_sympy(cc)),
    OracleArg::PyObj(expr_to_sympy(dd)),
    OracleArg::PyObj(expr_to_sympy(ee)),
    OracleArg::PyObj(expr_to_sympy(ff)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.wigner_9j", [
    OracleArg::PyObj(expr_to_sympy(j_1)),
    OracleArg::PyObj(expr_to_sympy(j_2)),
    OracleArg::PyObj(expr_to_sympy(j_3)),
    OracleArg::PyObj(expr_to_sympy(j_4)),
    OracleArg::PyObj(expr_to_sympy(j_5)),
    OracleArg::PyObj(expr_to_sympy(j_6)),
    OracleArg::PyObj(expr_to_sympy(j_7)),
    OracleArg::PyObj(expr_to_sympy(j_8)),
    OracleArg::PyObj(expr_to_sympy(j_9)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.wigner.real_gaunt", [
    OracleArg::PyObj(expr_to_sympy(l_1)),
    OracleArg::PyObj(expr_to_sympy(l_2)),
    OracleArg::PyObj(expr_to_sympy(l_3)),
    OracleArg::PyObj(expr_to_sympy(mu_1)),
    OracleArg::PyObj(expr_to_sympy(mu_2)),
    OracleArg::PyObj(expr_to_sympy(mu_3)),
  ])))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.pring.wavefunction", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(x)),
  ])))
}

///|
pub fn energy(
  n : @symcore.Expr,
  m : @symcore.Expr,
  r : @symcore.Expr,
) -> String raise {
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.pring.energy", [
    OracleArg::PyObj(expr_to_sympy(n)),
    OracleArg::PyObj(expr_to_sympy(m)),
    OracleArg::PyObj(expr_to_sympy(r)),
  ])))
}

///|
fn quantum_cg_obj(
  name : String,
  args : Array[OracleArg],
) -> @py.PyObject raise {
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
  py_str_obj(quantum_cg_obj("Wigner3j", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(m1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(m2)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(m3)),
  ]))
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
  py_str_obj(quantum_cg_obj("CG", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(m1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(m2)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(m3)),
  ]))
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
  py_str_obj(quantum_cg_obj("Wigner6j", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(j12)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(j)),
    OracleArg::PyObj(expr_to_sympy(j23)),
  ]))
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
  py_str_obj(quantum_cg_obj("Wigner9j", [
    OracleArg::PyObj(expr_to_sympy(j1)),
    OracleArg::PyObj(expr_to_sympy(j2)),
    OracleArg::PyObj(expr_to_sympy(j12)),
    OracleArg::PyObj(expr_to_sympy(j3)),
    OracleArg::PyObj(expr_to_sympy(j4)),
    OracleArg::PyObj(expr_to_sympy(j34)),
    OracleArg::PyObj(expr_to_sympy(j13)),
    OracleArg::PyObj(expr_to_sympy(j24)),
    OracleArg::PyObj(expr_to_sympy(j)),
  ]))
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
  py_str_obj(objenum_to_obj(sympy_call_must("sympy.physics.quantum.cg.cg_simp", [
    OracleArg::PyObj(obj),
  ])))
}
