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
fn ensure_repo_sympy_path() -> Unit raise {
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  let exec_fn = resolve_method_callable(builtins.obj(), "exec")
  let script = [
    "from pathlib import Path\n", "import sys\n", "_cwd = Path.cwd().resolve()\n",
    "_seen = set()\n", "_added = False\n", "for _base in [_cwd, *_cwd.parents]:\n",
    "    for _candidate in (_base / 'sympy', _base.parent / 'sympy'):\n", "        if _candidate in _seen:\n",
    "            continue\n", "        _seen.add(_candidate)\n", "        if (_candidate / 'sympy').is_dir():\n",
    "            _path = str(_candidate)\n", "            if _path not in sys.path:\n",
    "                sys.path.insert(0, _path)\n", "            _added = True\n",
    "            break\n", "    if _added:\n", "        break\n",
  ].join("")
  ignore(
    exec_fn.invoke(
      args=@sympy.py_pack_args([
        OracleArg::Str(script),
        OracleArg::PyObj(globals.obj()),
        OracleArg::PyObj(globals.obj()),
      ]),
      kwargs=@sympy.py_pack_kwargs({}),
      print_err=true,
    ),
  )
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
fn control_routh_ctor() -> @py.PyCallable raise {
  ensure_repo_sympy_path()
  let control_mod = match @py.pyimport("sympy.physics.control.routh_table") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.control.routh_table")
  }
  match control_mod.get_attr("RouthHurwitz", print_err=false) {
    Some(PyCallable(callable)) => callable
    Some(other) =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("sympy-oracle-callable")
      }
    None => fail("sympy-oracle-missing:RouthHurwitz")
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
  let quantum_qexpr_mod = match @py.pyimport("sympy.physics.quantum.qexpr") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.qexpr")
  }
  let quantum_operator_mod = match
    @py.pyimport("sympy.physics.quantum.operator") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.operator")
  }
  let quantum_state_mod = match @py.pyimport("sympy.physics.quantum.state") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.state")
  }
  let quantum_boson_mod = match @py.pyimport("sympy.physics.quantum.boson") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.boson")
  }
  let quantum_fermion_mod = match
    @py.pyimport("sympy.physics.quantum.fermion") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.fermion")
  }
  let quantum_qubit_mod = match @py.pyimport("sympy.physics.quantum.qubit") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.qubit")
  }
  let quantum_gate_mod = match @py.pyimport("sympy.physics.quantum.gate") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.gate")
  }
  let quantum_spin_mod = match @py.pyimport("sympy.physics.quantum.spin") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.spin")
  }
  let quantum_pauli_mod = match @py.pyimport("sympy.physics.quantum.pauli") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.pauli")
  }
  let quantum_represent_mod = match
    @py.pyimport("sympy.physics.quantum.represent") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.represent")
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
  let quantum_matrixcache_mod = match
    @py.pyimport("sympy.physics.quantum.matrixcache") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.matrixcache")
  }
  let quantum_circuitutils_mod = match
    @py.pyimport("sympy.physics.quantum.circuitutils") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.circuitutils")
  }
  let quantum_grover_mod = match @py.pyimport("sympy.physics.quantum.grover") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.grover")
  }
  let quantum_qft_mod = match @py.pyimport("sympy.physics.quantum.qft") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.qft")
  }
  let quantum_density_mod = match
    @py.pyimport("sympy.physics.quantum.density") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.density")
  }
  let quantum_commutator_mod = match
    @py.pyimport("sympy.physics.quantum.commutator") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.commutator")
  }
  let quantum_anticommutator_mod = match
    @py.pyimport("sympy.physics.quantum.anticommutator") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.anticommutator")
  }
  let quantum_innerproduct_mod = match
    @py.pyimport("sympy.physics.quantum.innerproduct") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.innerproduct")
  }
  let quantum_qapply_mod = match @py.pyimport("sympy.physics.quantum.qapply") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.quantum.qapply")
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
  let optics_utils_mod = match @py.pyimport("sympy.physics.optics.utils") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.optics.utils")
  }
  let optics_gaussopt_mod = match
    @py.pyimport("sympy.physics.optics.gaussopt") {
    Some(v) => v
    None => fail("python-missing:sympy.physics.optics.gaussopt")
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
  try_bind_name(globals, quantum_qexpr_mod, "QExpr")
  try_bind_name(globals, quantum_mod, "TensorProduct")
  try_bind_name(globals, quantum_dagger_mod, "Dagger")
  for
    name in [
      "Operator", "HermitianOperator", "UnitaryOperator", "IdentityOperator", "OuterProduct",
      "DifferentialOperator",
    ] {
    try_bind_name(globals, quantum_operator_mod, name)
  }
  for
    name in [
      "Ket", "Bra", "TimeDepKet", "TimeDepBra", "OrthogonalKet", "OrthogonalBra",
      "Wavefunction",
    ] {
    try_bind_name(globals, quantum_state_mod, name)
  }
  for
    name in [
      "BosonOp", "BosonFockKet", "BosonFockBra", "BosonCoherentKet", "BosonCoherentBra",
    ] {
    try_bind_name(globals, quantum_boson_mod, name)
  }
  for name in ["FermionOp", "FermionFockKet", "FermionFockBra"] {
    try_bind_name(globals, quantum_fermion_mod, name)
  }
  for
    name in [
      "Qubit", "QubitBra", "IntQubit", "IntQubitBra", "measure_all", "measure_partial",
      "measure_all_oneshot", "measure_partial_oneshot",
    ] {
    try_bind_name(globals, quantum_qubit_mod, name)
  }
  for
    name in [
      "Gate", "CGate", "UGate", "IdentityGate", "HadamardGate", "XGate", "YGate",
      "ZGate", "TGate", "PhaseGate", "SwapGate", "CNotGate", "CNOT", "SWAP", "H",
      "X", "Y", "Z", "T", "S", "CPHASE", "gate_simp", "gate_sort",
    ] {
    try_bind_name(globals, quantum_gate_mod, name)
  }
  for
    name in [
      "Jplus", "Jminus", "Jx", "Jy", "Jz", "J2", "JxKet", "JxBra", "JyKet", "JyBra",
      "JzKet", "JzBra", "Rotation", "WignerD",
    ] {
    try_bind_name(globals, quantum_spin_mod, name)
  }
  for
    name in [
      "SigmaX", "SigmaY", "SigmaZ", "SigmaMinus", "SigmaPlus", "SigmaZKet", "SigmaZBra",
      "qsimplify_pauli",
    ] {
    try_bind_name(globals, quantum_pauli_mod, name)
  }
  for name in ["QFT", "IQFT", "RkGate", "Rk"] {
    try_bind_name(globals, quantum_qft_mod, name)
  }
  for name in ["Density", "entropy", "fidelity"] {
    try_bind_name(globals, quantum_density_mod, name)
  }
  try_bind_name(globals, quantum_commutator_mod, "Commutator")
  try_bind_name(globals, quantum_anticommutator_mod, "AntiCommutator")
  try_bind_name(globals, quantum_innerproduct_mod, "InnerProduct")
  try_bind_name(globals, quantum_qapply_mod, "qapply")
  for name in ["represent"] {
    try_bind_name(globals, quantum_represent_mod, name)
  }
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
  try_bind_name(globals, quantum_matrixcache_mod, "matrix_cache")
  for
    name in [
      "kmp_table", "find_subcircuit", "replace_subcircuit", "convert_to_symbolic_indices",
      "convert_to_real_indices", "random_reduce", "random_insert",
    ] {
    try_bind_name(globals, quantum_circuitutils_mod, name)
  }
  for
    name in [
      "OracleGate", "WGate", "superposition_basis", "grover_iteration", "apply_grover",
    ] {
    try_bind_name(globals, quantum_grover_mod, name)
  }
  for name in ["Pauli", "evaluate_pauli_product", "delta", "epsilon"] {
    try_bind_name(globals, paulialgebra_mod, name)
  }
  try_bind_name(globals, optics_medium_mod, "Medium")
  for
    name in [
      "refraction_angle", "deviation", "fresnel_coefficients", "brewster_angle",
      "critical_angle", "lens_makers_formula", "mirror_formula", "lens_formula",
      "hyperfocal_distance", "transverse_magnification",
    ] {
    try_bind_name(globals, optics_utils_mod, name)
  }
  for
    name in [
      "RayTransferMatrix", "FreeSpace", "FlatRefraction", "CurvedRefraction", "FlatMirror",
      "CurvedMirror", "ThinLens", "GeometricRay", "BeamParameter", "waist2rayleigh",
      "rayleigh2waist", "geometric_conj_ab", "geometric_conj_af", "geometric_conj_bf",
      "gaussian_conj", "conjugate_gauss_beams",
    ] {
    try_bind_name(globals, optics_gaussopt_mod, name)
  }
  for
    name in [
      "jones_vector", "stokes_vector", "jones_2_stokes", "linear_polarizer", "phase_retarder",
      "half_wave_retarder", "quarter_wave_retarder", "transmissive_filter", "reflective_filter",
      "mueller_matrix", "polarizing_beam_splitter",
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
fn quantum_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.quantum import *\n",
    "from sympy.physics.quantum.qexpr import QExpr\n", "from sympy.physics.quantum.identitysearch import generate_gate_rules, generate_equivalent_ids, GateIdentity, bfs_identity_search, random_identity_search, is_scalar_sparse_matrix, is_scalar_nonsparse_matrix, is_degenerate, is_reducible\n",
    "from sympy.physics.quantum.state import Ket, Bra, TimeDepKet, TimeDepBra, OrthogonalKet, OrthogonalBra, Wavefunction\n",
    "from sympy.physics.quantum.operator import Operator, HermitianOperator, UnitaryOperator, IdentityOperator, OuterProduct, DifferentialOperator\n",
    "from sympy.physics.quantum.boson import BosonOp, BosonFockKet, BosonFockBra, BosonCoherentKet, BosonCoherentBra\n",
    "from sympy.physics.quantum.fermion import FermionOp, FermionFockKet, FermionFockBra\n",
    "from sympy.physics.quantum.cartesian import XOp, YOp, ZOp, PxOp, XKet, XBra, PxKet, PxBra, PositionKet3D, PositionBra3D\n",
    "from sympy.physics.quantum.operatorset import operators_to_state, state_to_operators\n",
    "from sympy.physics.quantum.piab import PIABHamiltonian, PIABKet, PIABBra, m, L\n",
    "from sympy.physics.quantum.qubit import Qubit, QubitBra, IntQubit, IntQubitBra, measure_all, measure_partial, measure_all_oneshot, measure_partial_oneshot\n",
    "from sympy.physics.quantum.sho1d import RaisingOp, LoweringOp, NumberOp, Hamiltonian, SHOKet, SHOBra\n",
    "from sympy.physics.quantum.gate import IdentityGate, HadamardGate, XGate, YGate, ZGate, PhaseGate, TGate, SwapGate, CNotGate, CNOT, SWAP, H, X, Y, Z, T, S, UGate, CGate, CPHASE, gate_simp, gate_sort\n",
    "from sympy.physics.quantum.spin import Jplus, Jminus, Jx, Jy, Jz, J2, JxKet, JxBra, JyKet, JyBra, JzKet, JzBra, JxKetCoupled, JxBraCoupled, JyKetCoupled, JyBraCoupled, JzKetCoupled, JzBraCoupled, couple, uncouple, Rotation, WignerD\n",
    "from sympy.physics.quantum.pauli import SigmaX, SigmaY, SigmaZ, SigmaMinus, SigmaPlus, SigmaZKet, SigmaZBra, qsimplify_pauli\n",
    "from sympy.physics.quantum.qft import QFT, IQFT, RkGate, Rk\n", "from sympy.physics.quantum.shor import ratioize, getr\n",
    "from sympy.physics.quantum.qasm import Qasm, flip_index, trim, get_index, get_indices, fixcommand, stripquotes\n",
    "from sympy.physics.quantum.circuitplot import CircuitPlot, render_label, labeller, Mz, Mx, CreateOneQubitGate, CreateCGate\n",
    "from sympy.physics.quantum.density import Density, entropy, fidelity\n", "from sympy.physics.quantum.matrixcache import matrix_cache\n",
    "from sympy.physics.quantum.circuitutils import kmp_table, find_subcircuit, replace_subcircuit, convert_to_symbolic_indices, convert_to_real_indices, random_reduce, random_insert\n",
    "from sympy.physics.quantum.grover import OracleGate, WGate, superposition_basis, grover_iteration, apply_grover\n",
    "from sympy.physics.quantum.represent import represent, rep_innerproduct, rep_expectation, get_basis, enumerate_states, integrate_result\n",
    "from sympy.physics.quantum.trace import Tr\n", "from sympy.physics.quantum.commutator import Commutator\n",
    "from sympy.physics.quantum.anticommutator import AntiCommutator\n", "a, b, c, d, f, n, u, v, x, y, z = symbols('a b c d f n u v x y z', commutative=True)\n",
    "alpha, beta, gamma, theta, phi = symbols('alpha beta gamma theta phi', commutative=True)\n",
    "A, B, C, D, X, Y, Z = symbols('A B C D X Y Z', commutative=False)\n", "wf = Function('wf')\n",
    "def grover_oracle_from_marks(nqubits, marks):\n", "    return OracleGate(nqubits, lambda qubits: any(qubits == IntQubit(idx, nqubits=nqubits) for idx in marks))\n",
  ].join("")
}

///|
pub fn quantum_eval_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()))\n",
    ].join(""),
  )
}

///|
pub fn quantum_srepr_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(srepr(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_doit_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).doit())\n",
    ].join(""),
  )
}

///|
pub fn quantum_decompose_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).decompose())\n",
    ].join(""),
  )
}

///|
pub fn quantum_qapply_str(
  expr : String,
  dagger? : Bool = false,
  ip_doit? : Bool = true,
  sum_doit? : Bool = false,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(qapply(sympify(",
      python_string_literal(expr),
      ", locals=locals()), dagger=",
      if dagger {
        "True"
      } else {
        "False"
      },
      ", ip_doit=",
      if ip_doit {
        "True"
      } else {
        "False"
      },
      ", sum_doit=",
      if sum_doit {
        "True"
      } else {
        "False"
      },
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qapply_srepr(
  expr : String,
  dagger? : Bool = false,
  ip_doit? : Bool = true,
  sum_doit? : Bool = false,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(srepr(qapply(sympify(",
      python_string_literal(expr),
      ", locals=locals()), dagger=",
      if dagger {
        "True"
      } else {
        "False"
      },
      ", ip_doit=",
      if ip_doit {
        "True"
      } else {
        "False"
      },
      ", sum_doit=",
      if sum_doit {
        "True"
      } else {
        "False"
      },
      ")))\n",
    ].join(""),
  )
}

///|
fn python_int_tuple(items : Array[Int]) -> String {
  if items.length() == 1 {
    "(" + items[0].to_string() + ",)"
  } else {
    "(" + items.map(item => item.to_string()).join(", ") + ")"
  }
}

///|
fn python_string_list_literal(items : Array[String]) -> String {
  "[" + items.map(python_string_literal).join(", ") + "]"
}

///|
pub fn quantum_measure_all_oneshot_str(
  expr : String,
  sample : Double,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "import random\n",
      "_old_random = random.random\n",
      "random.random = lambda: ",
      sample.to_string(),
      "\n",
      "try:\n",
      "    print(measure_all_oneshot(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
      "finally:\n",
      "    random.random = _old_random\n",
    ].join(""),
  )
}

///|
pub fn quantum_measure_partial_oneshot_str(
  expr : String,
  bits : Array[Int],
  sample : Double,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "import random\n",
      "_old_random = random.random\n",
      "random.random = lambda: ",
      sample.to_string(),
      "\n",
      "try:\n",
      "    print(measure_partial_oneshot(sympify(",
      python_string_literal(expr),
      ", locals=locals()), ",
      python_int_tuple(bits),
      "))\n",
      "finally:\n",
      "    random.random = _old_random\n",
    ].join(""),
  )
}

///|
pub fn quantum_hadamard_normalized_qapply(
  normalize : Bool,
  expr : String,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "from sympy.physics.quantum.gate import normalized\n",
      "_old = True\n",
      "normalized(",
      if normalize {
        "True"
      } else {
        "False"
      },
      ")\n",
      "try:\n",
      "    print(qapply(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
      "finally:\n",
      "    normalized(True)\n",
    ].join(""),
  )
}

///|
pub fn quantum_shor_ratioize(items : Array[Int], n : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(ratioize(",
      python_int_tuple(items),
      ", ",
      n.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_shor_getr(x : Int, y : Int, n : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(getr(",
      x.to_string(),
      ", ",
      y.to_string(),
      ", ",
      n.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_fixcommand(command : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(fixcommand(",
      python_string_literal(command),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_stripquotes(text : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(stripquotes(",
      python_string_literal(text),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_trim(text : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(trim(",
      python_string_literal(text),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_index(
  target : String,
  labels : Array[String],
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(get_index(",
      python_string_literal(target),
      ", ",
      python_string_list_literal(labels),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_indices(
  targets : Array[String],
  labels : Array[String],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(chr(31).join(str(v) for v in get_indices(",
      python_string_list_literal(targets),
      ", ",
      python_string_list_literal(labels),
      ")))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
pub fn quantum_render_label(
  label : String,
  init? : String? = None,
) -> String raise {
  let init_code = match init {
    Some(value) =>
      "{" +
      python_string_literal(label) +
      ": " +
      python_string_literal(value) +
      "}"
    None => "{}"
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(render_label(",
      python_string_literal(label),
      ", ",
      init_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_labeller(n : Int, symbol? : String = "q") -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(chr(31).join(labeller(",
      n.to_string(),
      ", ",
      python_string_literal(symbol),
      ")))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
pub fn quantum_create_one_qubit_gate_str(
  name : String,
  target : Int,
  latexname? : String? = None,
) -> String raise {
  let latex_code = match latexname {
    Some(value) => ", " + python_string_literal(value)
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(CreateOneQubitGate(",
      python_string_literal(name),
      latex_code,
      ")(",
      target.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_create_cgate_str(
  name : String,
  controls : Array[Int],
  target : Int,
  latexname? : String? = None,
) -> String raise {
  let latex_code = match latexname {
    Some(value) => ", " + python_string_literal(value)
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(CreateCGate(",
      python_string_literal(name),
      latex_code,
      ")(",
      python_int_tuple(controls),
      ", ",
      target.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_circuitplot_summary(
  expr : String,
  nqubits : Int,
  labels? : Array[String] = [],
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "plot = CircuitPlot(sympify(",
      python_string_literal(expr),
      ", locals=locals()), ",
      nqubits.to_string(),
      ", labels=",
      python_string_list_literal(labels),
      ")\n",
      "_meas = plot._measurements()\n",
      "_mkeys = sorted(_meas)\n",
      "_ms = '-' if not _mkeys else ','.join(f'{k}:{_meas[k]}' for k in _mkeys)\n",
      "print('ngates=' + str(plot.ngates) + ';nqubits=' + str(plot.nqubits) + ';gate_count=' + str(len(plot._gates())) + ';measurements=' + _ms + ';labels=' + ','.join(plot.labels))\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_circuit(lines : Array[String]) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(Qasm(*",
      python_string_list_literal(lines),
      ").get_circuit())\n",
    ].join(""),
  )
}

///|
pub fn quantum_qasm_labels(lines : Array[String]) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(chr(31).join(Qasm(*",
      python_string_list_literal(lines),
      ").get_labels()))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
pub fn quantum_represent_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) => ", basis=" + value
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(represent(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_represent_matrix(
  expr : String,
  basis : String,
  ndim : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = represent(sympify(",
      python_string_literal(expr),
      ", locals=locals()), basis=sympify(",
      python_string_literal(basis),
      ", locals=locals()), ndim=",
      ndim.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    if isinstance(row, (list, tuple)):\n",
      "        for item in row:\n",
      "            print(item)\n",
      "    else:\n",
      "        print(row)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_get_basis_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) =>
      ", basis=sympify(" + python_string_literal(value) + ", locals=locals())"
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(get_basis(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_enumerate_states_str(
  expr : String,
  start_index : Int,
  count : Int,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "states = enumerate_states(sympify(",
      python_string_literal(expr),
      ", locals=locals()), ",
      start_index.to_string(),
      ", ",
      count.to_string(),
      ")\n",
      "print('[' + ', '.join(str(item) for item in states) + ']')\n",
    ].join(""),
  )
}

///|
pub fn quantum_rep_innerproduct_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) =>
      ", basis=sympify(" + python_string_literal(value) + ", locals=locals())"
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(rep_innerproduct(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_rep_expectation_str(
  expr : String,
  basis? : String? = None,
) -> String raise {
  let basis_code = match basis {
    Some(value) =>
      ", basis=sympify(" + python_string_literal(value) + ", locals=locals())"
    None => ""
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(rep_expectation(sympify(",
      python_string_literal(expr),
      ", locals=locals())",
      basis_code,
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_integrate_result_str(
  orig_expr : String,
  result_expr : String,
  basis? : String? = None,
  unities? : Array[Int] = [],
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "kwargs = {'unities': ",
      python_int_tuple(unities),
      "}\n",
      match basis {
        Some(value) =>
          "kwargs['basis'] = sympify(" +
          python_string_literal(value) +
          ", locals=locals())\n"
        None => ""
      },
      "print(integrate_result(sympify(",
      python_string_literal(orig_expr),
      ", locals=locals()), sympify(",
      python_string_literal(result_expr),
      ", locals=locals()), **kwargs))\n",
    ].join(""),
  )
}

///|
pub fn quantum_identitysearch_rules_summary(
  gates : Array[String],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_seq = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "_rules = generate_gate_rules(tuple(_seq))\n",
      "def _fmt_side(side):\n",
      "    return str(Mul(*side)) if len(side) else '1'\n",
      "print(chr(31).join(sorted(_fmt_side(l) + ' == ' + _fmt_side(r) for l, r in _rules)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_string)
  }
}

///|
pub fn quantum_identitysearch_equivalent_ids(
  gates : Array[String],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_seq = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "_ids = generate_equivalent_ids(tuple(_seq))\n",
      "print(chr(31).join(sorted(str(Mul(*item)) if isinstance(item, tuple) else str(item) for item in _ids)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_string)
  }
}

///|
pub fn quantum_identitysearch_bfs_summary(
  gates : Array[String],
  nqubits : Int,
  max_depth : Int,
  identity_only : Bool,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_gates = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "_ids = bfs_identity_search(_gates, ",
      nqubits.to_string(),
      ", max_depth=",
      max_depth.to_string(),
      ", identity_only=",
      if identity_only {
        "True"
      } else {
        "False"
      },
      ")\n",
      "print(chr(31).join(sorted(str(item.circuit) for item in _ids)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_string)
  }
}

///|
pub fn quantum_identitysearch_is_scalar(
  gates : Array[String],
  nqubits : Int,
  identity_only : Bool,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "_seq = [sympify(item, locals=locals()) for item in ",
      python_string_list_literal(gates),
      "]\n",
      "print(is_scalar_nonsparse_matrix(Mul(*_seq), ",
      nqubits.to_string(),
      ", ",
      if identity_only {
        "True"
      } else {
        "False"
      },
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_matrixcache_matrix(name : String) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = matrix_cache.get_matrix(",
      python_string_literal(name),
      ", 'sympy')\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_circuitutils_kmp_table(expr : String) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "word = sympify(",
      python_string_literal(expr),
      ", locals=locals())\n",
      "if isinstance(word, Mul):\n",
      "    word = word.args\n",
      "elif word == 1:\n",
      "    word = ()\n",
      "else:\n",
      "    word = (word,)\n",
      "print(chr(31).join(str(v) for v in kmp_table(word)))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
pub fn quantum_circuitutils_find_subcircuit(
  circuit : String,
  subcircuit : String,
  start? : Int = 0,
  end? : Int = 0,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(find_subcircuit(sympify(",
      python_string_literal(circuit),
      ", locals=locals()), sympify(",
      python_string_literal(subcircuit),
      ", locals=locals()), start=",
      start.to_string(),
      ", end=",
      end.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_circuitutils_replace_subcircuit(
  circuit : String,
  subcircuit : String,
  replace? : String? = None,
  pos? : Int = 0,
) -> String raise {
  let replace_code = match replace {
    Some(expr) =>
      "sympify(" + python_string_literal(expr) + ", locals=locals())"
    None => "None"
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "out = replace_subcircuit(sympify(",
      python_string_literal(circuit),
      ", locals=locals()), sympify(",
      python_string_literal(subcircuit),
      ", locals=locals()), replace=",
      replace_code,
      ", pos=",
      pos.to_string(),
      ")\n",
      "print(srepr(Mul(*out)))\n",
    ].join(""),
  )
}

///|
pub fn quantum_circuitutils_convert_to_symbolic(
  expr : String,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "seq = sympify(",
      python_string_literal(expr),
      ", locals=locals())\n",
      "out, mapping, _, _ = convert_to_symbolic_indices(seq)\n",
      "print(srepr(Mul(*out)))\n",
      "for key in sorted(mapping, key=str):\n",
      "    print(f\"{key}={mapping[key]}\")\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_circuitutils_convert_to_real(
  expr : String,
  mapping_code : String,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "out = convert_to_real_indices(sympify(",
      python_string_literal(expr),
      ", locals=locals()), sympify(",
      python_string_literal(mapping_code),
      ", locals=locals()))\n",
      "print(srepr(Mul(*out)))\n",
    ].join(""),
  )
}

///|
fn grover_marks_literal(marks : Array[Int]) -> String {
  "[" + marks.map(value => value.to_string()).join(", ") + "]"
}

///|
pub fn quantum_grover_superposition_matrix(
  nqubits : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = represent(superposition_basis(",
      nqubits.to_string(),
      "), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_grover_oracle_matrix(
  nqubits : Int,
  marks : Array[Int],
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "mat = represent(grover_oracle_from_marks(",
      nqubits.to_string(),
      ", ",
      grover_marks_literal(marks),
      "), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_grover_w_matrix(nqubits : Int) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "from sympy import Matrix\n",
      "cols = []\n",
      "for idx in range(2**",
      nqubits.to_string(),
      "):\n",
      "    state = IntQubit(idx, nqubits=",
      nqubits.to_string(),
      ")\n",
      "    cols.append(represent(qapply(WGate(",
      nqubits.to_string(),
      ")*state), nqubits=",
      nqubits.to_string(),
      "))\n",
      "mat = Matrix.hstack(*cols)\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_grover_oracle_state_matrix(
  nqubits : Int,
  marks : Array[Int],
  state : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "op = grover_oracle_from_marks(",
      nqubits.to_string(),
      ", ",
      grover_marks_literal(marks),
      ")\n",
      "state = IntQubit(",
      state.to_string(),
      ", nqubits=",
      nqubits.to_string(),
      ")\n",
      "mat = represent(qapply(op*state), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_grover_w_state_matrix(
  nqubits : Int,
  state : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "state = IntQubit(",
      state.to_string(),
      ", nqubits=",
      nqubits.to_string(),
      ")\n",
      "mat = represent(qapply(WGate(",
      nqubits.to_string(),
      ")*state), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_grover_apply_matrix(
  nqubits : Int,
  marks : Array[Int],
  iterations : Int,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "oracle = lambda qubits: any(qubits == IntQubit(idx, nqubits=",
      nqubits.to_string(),
      ") for idx in ",
      grover_marks_literal(marks),
      ")\n",
      "mat = represent(qapply(apply_grover(oracle, ",
      nqubits.to_string(),
      ", iterations=",
      iterations.to_string(),
      ")), nqubits=",
      nqubits.to_string(),
      ")\n",
      "for row in mat.tolist():\n",
      "    for item in row:\n",
      "        print(item)\n",
    ].join(""),
  )
  txt
  .split("\n")
  .map(StringView::to_string)
  .filter(line => line != "")
  .collect()
}

///|
pub fn quantum_kind_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).kind)\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_states_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).states())\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_probs_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).probs())\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_get_state_str(
  expr : String,
  index : Int,
) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).get_state(",
      index.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_get_prob_str(expr : String, index : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).get_prob(",
      index.to_string(),
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_density_apply_op_str(expr : String, op : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "obj = sympify(",
      python_string_literal(expr),
      ", locals=locals())\n",
      "print(obj.apply_op(sympify(",
      python_string_literal(op),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_entropy_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(entropy(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_fidelity_str(lhs : String, rhs : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(fidelity(sympify(",
      python_string_literal(lhs),
      ", locals=locals()), sympify(",
      python_string_literal(rhs),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn quantum_expand_commutator_str(expr : String) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).expand(commutator=True))\n",
    ].join(""),
  )
}

///|
pub fn quantum_normal_order_str(
  expr : String,
  ordered_form? : Bool = true,
  independent? : Bool = false,
) -> String raise {
  let fn_name = if ordered_form {
    "normal_ordered_form"
  } else {
    "normal_order"
  }
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "from sympy.physics.quantum.operatorordering import normal_order, normal_ordered_form\n",
      "print(",
      fn_name,
      "(sympify(",
      python_string_literal(expr),
      ", locals=locals()), independent=",
      if independent {
        "True"
      } else {
        "False"
      },
      "))\n",
    ].join(""),
  )
}

///|
pub fn quantum_trace_permute_str(expr : String, pos : Int) -> String raise {
  python_script_stdout(
    [
      quantum_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()).permute(",
      pos.to_string(),
      "))\n",
    ].join(""),
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
pub fn physics_expr_srepr(expr : @symcore.Expr) -> String raise {
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.srepr", [OracleArg::PyObj(expr_to_sympy(expr))]),
    ),
  )
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
  let txt = python_script_stdout(
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
fn python_script_stdout(script : String) -> String raise {
  ensure_repo_sympy_path()
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("__symbit_script__", @py.PyString::from(script).obj())
  let exec_fn = resolve_method_callable(builtins.obj(), "exec")
  let wrapped = [
    "import io\n", "import sys\n", "__symbit_stdout__ = io.StringIO()\n", "__symbit_prev_stdout__ = sys.stdout\n",
    "sys.stdout = __symbit_stdout__\n", "try:\n", "    exec(__symbit_script__, globals(), locals())\n",
    "finally:\n", "    sys.stdout = __symbit_prev_stdout__\n", "__symbit_out__ = __symbit_stdout__.getvalue()\n",
  ].join("")
  ignore(
    exec_fn.invoke(
      args=@sympy.py_pack_args([
        OracleArg::Str(wrapped),
        OracleArg::PyObj(globals.obj()),
        OracleArg::PyObj(globals.obj()),
      ]),
      kwargs=@sympy.py_pack_kwargs({}),
      print_err=true,
    ),
  )
  match globals.get("__symbit_out__") {
    Some(value) => py_str_obj(objenum_to_obj(value)).trim().to_string()
    None => ""
  }
}

///|
fn secondquant_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.secondquant import *\n",
    "from sympy.physics.quantum.operatorordering import normal_ordered_form\n", "a, b, c, d = symbols('a b c d', above_fermi=True)\n",
    "i, j, k, l, m, n = symbols('i j k l m n', below_fermi=True)\n", "p, q, r, s = symbols('p q r s')\n",
    "v = Symbol('v')\n", "T = Function('T')\n", "f = Function('f')\n", "g = Function('g')\n",
  ].join("")
}

///|
fn continuum_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.continuum_mechanics.beam import Beam\n",
    "from sympy.physics.continuum_mechanics.column import Column\n", "from sympy.physics.continuum_mechanics.cable import Cable\n",
    "from sympy.physics.continuum_mechanics.arch import Arch\n", "x = Symbol('x')\n",
    "y = Symbol('y')\n", "t = Symbol('t')\n", "E = Symbol('E')\n", "I = Symbol('I')\n",
    "A = Symbol('A')\n", "R1, R2 = symbols('R1 R2')\n",
  ].join("")
}

///|
pub fn continuum_exec_stdout(script : String) -> String raise {
  python_script_stdout(continuum_subprocess_prelude() + script)
}

///|
pub fn secondquant_eval_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_exec_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(eval(",
      python_string_literal(expr),
      ", globals(), locals()))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_apply_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(apply_operators(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_normal_order_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(normal_ordered_form(sympify(",
      python_string_literal(expr),
      ", locals=locals())))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_basis_str(expr : String) -> String raise {
  python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "print(sympify(",
      python_string_literal(expr),
      ", locals=locals()))\n",
    ].join(""),
  )
}

///|
pub fn secondquant_matrix_rows(
  op_expr : String,
  basis_expr : String,
) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      secondquant_subprocess_prelude(),
      "m = matrix_rep(sympify(",
      python_string_literal(op_expr),
      ", locals=locals()), sympify(",
      python_string_literal(basis_expr),
      ", locals=locals()))\n",
      "print(chr(31).join('[' + ', '.join(str(c) for c in row) + ']' for row in m.tolist()))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
fn control_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.control.lti import *\n",
    "a, b, c, d, s, p, g, k, tau, zeta, wn, T, z, x, y = symbols('a b c d s p g k tau zeta wn T z x y')\n",
  ].join("")
}

///|
pub fn control_exec_stdout(script : String) -> String raise {
  python_script_stdout(control_subprocess_prelude() + script)
}

///|
fn control_routh_script(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
  command : String,
) -> String {
  let poly_txt = @symprint.to_string(polynomial)
  let var_txt = @symprint.to_string(variable)
  [
    "import sys\n",
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
  let txt = python_script_stdout(
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
  python_script_stdout(
    control_routh_script(polynomial, variable, "print(obj.zero_col_infos)"),
  )
}

///|
pub fn control_routh_zero_row_case(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
) -> String raise {
  python_script_stdout(
    control_routh_script(polynomial, variable, "print(obj.zero_row_case)"),
  )
}

///|
pub fn control_routh_auxiliary_expr(
  polynomial : @symcore.Expr,
  variable : @symcore.Expr,
  index : Int,
) -> String raise {
  python_script_stdout(
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
  let txt = python_script_stdout(
    [
      "import sys\n",
      "from sympy import N, Symbol, simplify, sympify\n",
      "names = ['z', 'b0', 'b1', 'b2', 'b3', 'b4', 'f', 'u', 'v', 'N', 'c', 'x', 'y', 'n']\n",
      "locals_map = {name: Symbol(name) for name in names}\n",
      "lhs = sympify(",
      python_string_literal(lhs_txt),
      ", locals=locals_map)\n",
      "rhs = sympify(",
      python_string_literal(rhs),
      ", locals=locals_map)\n",
      "diff = simplify(lhs - rhs)\n",
      "if diff == 0:\n",
      "    print(True)\n",
      "elif lhs.free_symbols or rhs.free_symbols:\n",
      "    print(False)\n",
      "else:\n",
      "    try:\n",
      "        print(abs(complex(N(diff, 50))) < 1e-12)\n",
      "    except Exception:\n",
      "        print(False)\n",
    ].join(""),
  )
  txt == "True"
}

///|
pub fn physics_expr_equivalent(lhs : @symcore.Expr, rhs : String) -> Bool raise {
  let lhs_txt = @symprint.to_string(lhs)
  let txt = python_script_stdout(
    [
      "import sys\n",
      "from sympy import N, simplify, sympify\n",
      "lhs = sympify(",
      python_string_literal(lhs_txt),
      ")\n",
      "rhs = sympify(",
      python_string_literal(rhs),
      ")\n",
      "diff = simplify(lhs - rhs)\n",
      "if diff == 0:\n",
      "    print(True)\n",
      "elif lhs.free_symbols or rhs.free_symbols:\n",
      "    print(False)\n",
      "else:\n",
      "    try:\n",
      "        print(abs(complex(N(diff, 50))) < 1e-12)\n",
      "    except Exception:\n",
      "        print(False)\n",
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

///|
pub fn optics_utils_eval(expr : String) -> String raise {
  python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.utils import *\n", "from sympy.physics.optics.medium import Medium\n",
      "from sympy.physics.units import e0\n", "f, u, v, N, c, n = symbols('f u v N c n')\n",
      "print(", expr, ")\n",
    ].join(""),
  )
}

///|
pub fn optics_waves_eval(expr : String) -> String raise {
  python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.waves import TWave\n",
      "from sympy.physics.units import meter, second, speed_of_light\n", "A, A1, A2, phi, phi1, phi2, f, n = symbols('A A1 A2 phi phi1 phi2 f n')\n",
      "print(", expr, ")\n",
    ].join(""),
  )
}

///|
pub fn optics_gaussopt_eval(expr : String) -> String raise {
  python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.gaussopt import *\n", "d, f, h, angle, n1, n2, R, w, wavelen, z_r, a, b, s_in, z_r_in, l, w_i, w_o, z, w_0 = symbols('d f h angle n1 n2 R w wavelen z_r a b s_in z_r_in l w_i w_o z w_0')\n",
      "print(", expr, ")\n",
    ].join(""),
  )
}

///|
pub fn optics_gaussopt_matrix(expr : String) -> Array[String] raise {
  let txt = python_script_stdout(
    [
      "from sympy import *\n", "from sympy.physics.optics.gaussopt import *\n", "d, f, h, angle, n1, n2, R, w, wavelen, z_r, a, b, s_in, z_r_in, l, w_i, w_o, z, w_0 = symbols('d f h angle n1 n2 R w wavelen z_r a b s_in z_r_in l w_i w_o z w_0')\n",
      "obj = ", expr, "\n", "print(chr(31).join(str(c) for row in obj.tolist() for c in row))\n",
    ].join(""),
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(StringView::to_string)
  }
}

///|
fn vector_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.vector import *\n",
    "from sympy.physics.vector.fieldfunctions import *\n", "t = dynamicsymbols._t\n",
    "def _symbit_vector_summary(obj):\n", "    if isinstance(obj, (Vector, Dyadic)):\n",
    "        return vsprint(obj)\n", "    if isinstance(obj, list):\n", "        return '[' + ', '.join(_symbit_vector_summary(x) for x in obj) + ']'\n",
    "    if isinstance(obj, tuple):\n", "        items = ', '.join(_symbit_vector_summary(x) for x in obj)\n",
    "        if len(obj) == 1:\n", "            items += ','\n", "        return '(' + items + ')'\n",
    "    return str(obj)\n",
  ].join("")
}

///|
fn mechanics_subprocess_prelude() -> String {
  [
    "import sys\n", "from sympy import *\n", "from sympy.physics.vector import *\n",
    "from sympy.physics.vector.fieldfunctions import *\n", "from sympy.physics.mechanics import *\n",
    "from sympy.physics.mechanics.functions import *\n", "from sympy.physics.mechanics.loads import *\n",
    "t = dynamicsymbols._t\n", "def _symbit_mechanics_summary(obj):\n", "    if isinstance(obj, (Vector, Dyadic)):\n",
    "        return vsprint(obj)\n", "    if isinstance(obj, (Particle, RigidBody, Body, Inertia, Force, Torque)):\n",
    "        return repr(obj)\n", "    if isinstance(obj, list):\n", "        return '[' + ', '.join(_symbit_mechanics_summary(x) for x in obj) + ']'\n",
    "    if isinstance(obj, tuple):\n", "        items = ', '.join(_symbit_mechanics_summary(x) for x in obj)\n",
    "        if len(obj) == 1:\n", "            items += ','\n", "        return '(' + items + ')'\n",
    "    return str(obj)\n",
  ].join("")
}

///|
fn vector_python_result_script(
  expr : String,
  prefix : String,
  suffix : String,
) -> String {
  let pieces = expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_string())
    .filter(s => s != "")
  if pieces.is_empty() {
    return [vector_subprocess_prelude(), prefix, "None", suffix, "\n"].join("")
  }
  let body : Array[String] = [vector_subprocess_prelude()]
  for piece in pieces[:pieces.length() - 1] {
    body.push(piece.to_string())
    body.push("\n")
  }
  body.push(prefix)
  body.push(pieces[pieces.length() - 1].to_string())
  body.push(suffix)
  body.push("\n")
  body.join("")
}

///|
fn mechanics_python_result_script(
  expr : String,
  prefix : String,
  suffix : String,
) -> String {
  let pieces = expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_string())
    .filter(s => s != "")
  if pieces.is_empty() {
    return [mechanics_subprocess_prelude(), prefix, "None", suffix, "\n"].join(
      "",
    )
  }
  let body : Array[String] = [mechanics_subprocess_prelude()]
  for piece in pieces[:pieces.length() - 1] {
    body.push(piece.to_string())
    body.push("\n")
  }
  body.push(prefix)
  body.push(pieces[pieces.length() - 1].to_string())
  body.push(suffix)
  body.push("\n")
  body.join("")
}

///|
pub fn vector_eval(expr : String) -> String raise {
  python_script_stdout(vector_python_result_script(expr, "print(", ")"))
}

///|
pub fn vector_summary(expr : String) -> String raise {
  python_script_stdout(
    vector_python_result_script(expr, "print(_symbit_vector_summary(", "))"),
  )
}

///|
pub fn mechanics_eval(expr : String) -> String raise {
  python_script_stdout(mechanics_python_result_script(expr, "print(", ")"))
}

///|
pub fn mechanics_summary(expr : String) -> String raise {
  python_script_stdout(
    mechanics_python_result_script(
      expr, "print(_symbit_mechanics_summary(", "))",
    ),
  )
}

///|
pub fn mechanics_expr_equal(lhs_expr : String, rhs_expr : String) -> Bool raise {
  let combined = lhs_expr + ";" + rhs_expr
  let body : Array[String] = [
    mechanics_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
    python_string_literal(combined),
    ")):\n",
    "    _locals[_name] = Function(_name)\n",
    "lhs = sympify(",
    python_string_literal(lhs_expr),
    ", locals=_locals)\n",
    "rhs = sympify(",
    python_string_literal(rhs_expr),
    ", locals=_locals)\n",
    "ok = simplify(expand_func(lhs - rhs)) == 0\n",
    "print(ok)\n",
  ]
  python_script_stdout(body.join("")) == "True"
}

///|
pub fn vector_expr_equal(lhs_expr : String, rhs_expr : String) -> Bool raise {
  let pieces = rhs_expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_string())
    .filter(s => s != "")
  let body : Array[String] = [
    vector_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
  ]
  body.push(python_string_literal(lhs_expr))
  body.push(")):\n")
  body.push("    _locals[_name] = Function(_name)\n")
  body.push(
    "for _frame_name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\.[xyz]', ",
  )
  body.push(python_string_literal(lhs_expr))
  body.push(")):\n")
  body.push("    _locals[_frame_name] = ReferenceFrame(_frame_name)\n")
  body.push("lhs = sympify(")
  body.push(python_string_literal(lhs_expr))
  body.push(", locals=_locals)\n")
  if pieces.is_empty() {
    body.push("rhs = 0\n")
  } else {
    for piece in pieces[:pieces.length() - 1] {
      body.push(piece.to_string())
      body.push("\n")
    }
    body.push("rhs = ")
    body.push(pieces[pieces.length() - 1].to_string())
    body.push("\n")
  }
  body.push("delta = lhs - rhs\n")
  body.push("if isinstance(delta, (Vector, Dyadic)):\n")
  body.push("    ok = delta.simplify() == 0\n")
  body.push("else:\n")
  body.push("    ok = simplify(delta) == 0\n")
  body.push("print(ok)\n")
  python_script_stdout(body.join("")) == "True"
}

///|
pub fn vector_bool(expr : String) -> Bool raise {
  vector_eval(expr) == "True"
}

///|
pub fn vector_matrix_rows(expr : String) -> Array[String] raise {
  let txt = python_script_stdout(
    vector_python_result_script(expr, "m = ", "") +
    "print(chr(31).join('[' + ', '.join(str(c) for c in row) + ']' for row in m.tolist()))\n",
  )
  if txt == "" {
    []
  } else {
    txt.split("\u001f").to_array().map(s => s.to_string())
  }
}

///|
pub fn vector_matrix_equal(lhs_rows : String, rhs_expr : String) -> Bool raise {
  let pieces = rhs_expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_string())
    .filter(s => s != "")
  let body : Array[String] = [
    vector_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
  ]
  body.push(python_string_literal(lhs_rows))
  body.push(")):\n")
  body.push("    _locals[_name] = Function(_name)\n")
  body.push("lhs = Matrix(sympify(")
  body.push(python_string_literal(lhs_rows))
  body.push(", locals=_locals))\n")
  if pieces.is_empty() {
    body.push("rhs = Matrix([[0]])\n")
  } else {
    for piece in pieces[:pieces.length() - 1] {
      body.push(piece.to_string())
      body.push("\n")
    }
    body.push("rhs = ")
    body.push(pieces[pieces.length() - 1].to_string())
    body.push("\n")
  }
  body.push(
    "ok = lhs.shape == rhs.shape and all(simplify(lhs[i, j] - rhs[i, j]) == 0 for i in range(lhs.rows) for j in range(lhs.cols))\n",
  )
  body.push("print(ok)\n")
  python_script_stdout(body.join("")) == "True"
}

///|
pub fn mechanics_matrix_equal(
  lhs_rows : String,
  rhs_expr : String,
) -> Bool raise {
  let pieces = rhs_expr
    .split(";")
    .to_array()
    .map(s => s.trim().to_string())
    .filter(s => s != "")
  let body : Array[String] = [
    mechanics_subprocess_prelude(),
    "import re\n",
    "_locals = {'t': t}\n",
    "for _name in set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\\(t\\)', ",
  ]
  body.push(python_string_literal(lhs_rows))
  body.push(")):\n")
  body.push("    _locals[_name] = Function(_name)\n")
  body.push("lhs = Matrix(sympify(")
  body.push(python_string_literal(lhs_rows))
  body.push(", locals=_locals))\n")
  if pieces.is_empty() {
    body.push("rhs = Matrix([[0]])\n")
  } else {
    for piece in pieces[:pieces.length() - 1] {
      body.push(piece.to_string())
      body.push("\n")
    }
    body.push("rhs = ")
    body.push(pieces[pieces.length() - 1].to_string())
    body.push("\n")
  }
  body.push(
    "ok = lhs.shape == rhs.shape and all(simplify(lhs[i, j] - rhs[i, j]) == 0 for i in range(lhs.rows) for j in range(lhs.cols))\n",
  )
  body.push("print(ok)\n")
  python_script_stdout(body.join("")) == "True"
}
