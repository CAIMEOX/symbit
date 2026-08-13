///|
/// Request-scoped recipe helpers for the direct SymPy physics APIs.

///|
priv struct PhysicsRecipe {
  builder : @recipe.Builder
  expressions : @exprcodec.Encoder
  sympy : @recipe.ValueRef
}

///|
fn PhysicsRecipe::new() -> PhysicsRecipe raise {
  let builder = @recipe.Builder::new()
  {
    builder,
    expressions: @exprcodec.Encoder::new(builder),
    sympy: builder.import_module("sympy"),
  }
}

///|
fn PhysicsRecipe::required_call(
  self : PhysicsRecipe,
  callable : @recipe.ValueRef,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  message? : String = "sympy-call-none",
) -> @recipe.ValueRef raise {
  self.builder.require_non_none(
    self.builder.call(callable, args, kwargs~),
    message~,
  )
}

///|
fn PhysicsRecipe::module_call(
  self : PhysicsRecipe,
  module_name : String,
  function_name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let module_value = self.builder.import_module(module_name)
  let callable = self.builder.getattr(module_value, function_name)
  self.required_call(
    callable,
    args,
    kwargs~,
    message="sympy-call-none:\{module_name}.\{function_name}",
  )
}

///|
fn PhysicsRecipe::sympy_call(
  self : PhysicsRecipe,
  function_name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(self.sympy, function_name)
  self.required_call(
    callable,
    args,
    kwargs~,
    message="sympy-call-none:sympy.\{function_name}",
  )
}

///|
fn PhysicsRecipe::expr_args(
  self : PhysicsRecipe,
  values : Array[@symcore.Expr],
) -> Array[@recipe.RecipeArg] raise {
  let result : Array[@recipe.RecipeArg] = []
  for value in values {
    result.push(Ref(self.expressions.encode(value)))
  }
  result
}

///|
fn PhysicsRecipe::module_expr_call(
  self : PhysicsRecipe,
  module_name : String,
  function_name : String,
  values : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  self.module_call(module_name, function_name, self.expr_args(values))
}

///|
fn request_string_array(
  builder : @recipe.Builder,
  value : @recipe.ValueRef,
) -> Array[String] raise {
  match builder.request(value, List(Str)) {
    Array(items) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(text) => result.push(text)
          other =>
            fail("expected string array item, received " + other.stringify())
        }
      }
      result
    }
    other => fail("expected string array, received " + other.stringify())
  }
}

///|
fn PhysicsRecipe::matrix_strings(
  self : PhysicsRecipe,
  matrix : @recipe.ValueRef,
) -> Array[String] raise {
  let scope = self.builder.sympy_scope()
  let flatten = self.builder.eval(
    scope, "lambda matrix: [str(item) for row in matrix.tolist() for item in (row if isinstance(row, (list, tuple)) else [row])]",
  )
  let flattened = self.required_call(flatten, [Ref(matrix)])
  request_string_array(self.builder, flattened)
}

///|
fn physics_scope_prelude() -> String {
  [
    "def __symbit_populate_physics_scope(scope):\n", "    import importlib\n", "    bindings = [\n",
    "        ('sympy', ('Abs', 'KroneckerDelta', 'I', 'Sum', 'TensorProduct', 'Tuple', 'Ynm', 'Ynm_c', 'Znm', 'assoc_laguerre', 'assoc_legendre', 'conjugate', 'cos', 'exp', 'factorial', 'factorial2', 'hermite', 'Matrix', 'Interval', 'pi', 'sin', 'sqrt', 'eye', 'zeros', 'oo')),\n",
    "        ('sympy.physics.units', ('meter', 'second', 'kilogram', 'ampere', 'watt', 'm', 's', 'kg', 'A', 'W', 'speed_of_light', 'u0', 'e0')),\n",
    "        ('sympy.physics.units.prefixes', ('Prefix', 'PREFIXES', 'BIN_PREFIXES', 'kilo', 'mega', 'milli', 'centi', 'deci', 'kibi')),\n",
    "        ('sympy.physics.quantum.cg', ('CG', 'Wigner3j', 'Wigner6j', 'Wigner9j')),\n",
    "        ('sympy.physics.quantum.qexpr', ('QExpr',)),\n", "        ('sympy.physics.quantum', ('TensorProduct',)),\n",
    "        ('sympy.physics.quantum.dagger', ('Dagger',)),\n", "        ('sympy.physics.quantum.operator', ('Operator', 'HermitianOperator', 'UnitaryOperator', 'IdentityOperator', 'OuterProduct', 'DifferentialOperator')),\n",
    "        ('sympy.physics.quantum.state', ('Ket', 'Bra', 'TimeDepKet', 'TimeDepBra', 'OrthogonalKet', 'OrthogonalBra', 'Wavefunction')),\n",
    "        ('sympy.physics.quantum.boson', ('BosonOp', 'BosonFockKet', 'BosonFockBra', 'BosonCoherentKet', 'BosonCoherentBra')),\n",
    "        ('sympy.physics.quantum.fermion', ('FermionOp', 'FermionFockKet', 'FermionFockBra')),\n",
    "        ('sympy.physics.quantum.qubit', ('Qubit', 'QubitBra', 'IntQubit', 'IntQubitBra', 'measure_all', 'measure_partial', 'measure_all_oneshot', 'measure_partial_oneshot')),\n",
    "        ('sympy.physics.quantum.gate', ('Gate', 'CGate', 'UGate', 'IdentityGate', 'HadamardGate', 'XGate', 'YGate', 'ZGate', 'TGate', 'PhaseGate', 'SwapGate', 'CNotGate', 'CNOT', 'SWAP', 'H', 'X', 'Y', 'Z', 'T', 'S', 'CPHASE', 'gate_simp', 'gate_sort')),\n",
    "        ('sympy.physics.quantum.spin', ('Jplus', 'Jminus', 'Jx', 'Jy', 'Jz', 'J2', 'JxKet', 'JxBra', 'JyKet', 'JyBra', 'JzKet', 'JzBra', 'Rotation', 'WignerD')),\n",
    "        ('sympy.physics.quantum.pauli', ('SigmaX', 'SigmaY', 'SigmaZ', 'SigmaMinus', 'SigmaPlus', 'SigmaZKet', 'SigmaZBra', 'qsimplify_pauli')),\n",
    "        ('sympy.physics.quantum.qft', ('QFT', 'IQFT', 'RkGate', 'Rk')),\n",
    "        ('sympy.physics.quantum.density', ('Density', 'entropy', 'fidelity')),\n",
    "        ('sympy.physics.quantum.commutator', ('Commutator',)),\n", "        ('sympy.physics.quantum.anticommutator', ('AntiCommutator',)),\n",
    "        ('sympy.physics.quantum.innerproduct', ('InnerProduct',)),\n", "        ('sympy.physics.quantum.qapply', ('qapply',)),\n",
    "        ('sympy.physics.quantum.represent', ('represent',)),\n", "        ('sympy.physics.quantum.hilbert', ('HilbertSpace', 'ComplexSpace', 'L2', 'FockSpace', 'TensorProductHilbertSpace', 'DirectSumHilbertSpace', 'TensorPowerHilbertSpace')),\n",
    "        ('sympy.physics.quantum.matrixutils', ('matrix_dagger', 'matrix_tensor_product', 'matrix_to_zero', 'flatten_scalar')),\n",
    "        ('sympy.physics.quantum.matrixcache', ('matrix_cache',)),\n", "        ('sympy.physics.quantum.circuitutils', ('kmp_table', 'find_subcircuit', 'replace_subcircuit', 'convert_to_symbolic_indices', 'convert_to_real_indices', 'random_reduce', 'random_insert')),\n",
    "        ('sympy.physics.quantum.grover', ('OracleGate', 'WGate', 'superposition_basis', 'grover_iteration', 'apply_grover')),\n",
    "        ('sympy.physics.paulialgebra', ('Pauli', 'evaluate_pauli_product', 'delta', 'epsilon')),\n",
    "        ('sympy.physics.optics.medium', ('Medium',)),\n", "        ('sympy.physics.optics.utils', ('refraction_angle', 'deviation', 'fresnel_coefficients', 'brewster_angle', 'critical_angle', 'lens_makers_formula', 'mirror_formula', 'lens_formula', 'hyperfocal_distance', 'transverse_magnification')),\n",
    "        ('sympy.physics.optics.gaussopt', ('RayTransferMatrix', 'FreeSpace', 'FlatRefraction', 'CurvedRefraction', 'FlatMirror', 'CurvedMirror', 'ThinLens', 'GeometricRay', 'BeamParameter', 'waist2rayleigh', 'rayleigh2waist', 'geometric_conj_ab', 'geometric_conj_af', 'geometric_conj_bf', 'gaussian_conj', 'conjugate_gauss_beams')),\n",
    "        ('sympy.physics.optics.polarization', ('jones_vector', 'stokes_vector', 'jones_2_stokes', 'linear_polarizer', 'phase_retarder', 'half_wave_retarder', 'quarter_wave_retarder', 'transmissive_filter', 'reflective_filter', 'mueller_matrix', 'polarizing_beam_splitter')),\n",
    "    ]\n", "    sympy_mod = importlib.import_module('sympy')\n", "    scope['sympy'] = sympy_mod\n",
    "    for module_name, names in bindings:\n", "        module = importlib.import_module(module_name)\n",
    "        for name in names:\n", "            if hasattr(module, name):\n", "                scope[name] = getattr(module, name)\n",
    "    scope['RouthHurwitz'] = getattr(importlib.import_module('sympy.physics.control.routh_table'), 'RouthHurwitz')\n",
    "    for name in ('a', 'b', 'b0', 'b1', 'b2', 'b3', 'b4', 'c', 'cp', 'alpha', 'beta', 'gamma', 'gammap', 'theta', 'phi', 'r', 'x', 'z', 'm', 'mu', 'm1', 'm1p', 'm2', 'm2p', 'n', 'epsilon', 'omega', 'nu', 'j', 'j1', 'j2', 'j3', 'j12', 'j13', 'j23', 'j24', 'j34', 'sigma', 'tau', 'Z'):\n",
    "        scope[name] = sympy_mod.Symbol(name)\n", "    for name in ('q', 'Aop', 'Bop', 'Cop', 'Dop'):\n",
    "        scope[name] = sympy_mod.Symbol(name, commutative=False)\n", "    pauli_mod = importlib.import_module('sympy.physics.paulialgebra')\n",
    "    for binding, index, label in (('sigma1', 1, 'sigma'), ('sigma2', 2, 'sigma'), ('sigma3', 3, 'sigma'), ('tau1', 1, 'tau'), ('tau2', 2, 'tau'), ('tau3', 3, 'tau')):\n",
    "        scope[binding] = pauli_mod.Pauli(index, sympy_mod.Symbol(label))\n",
    "    constants_mod = importlib.import_module('sympy.physics.quantum.constants')\n",
    "    if hasattr(constants_mod, 'hbar'):\n", "        scope['hbar'] = constants_mod.hbar\n",
    "__symbit_populate_physics_scope(globals())\n", "del __symbit_populate_physics_scope\n",
  ].join("")
}

///|
fn PhysicsRecipe::physics_scope(self : PhysicsRecipe) -> @recipe.ValueRef raise {
  let builtins = self.builder.import_module("builtins")
  let scope = self.builder.dict([(Str("__builtins__"), Ref(builtins))])
  self.builder.exec(scope, physics_scope_prelude())
}

///|
fn PhysicsRecipe::physics_sympify(
  self : PhysicsRecipe,
  expression : String,
) -> @recipe.ValueRef raise {
  let scope = self.physics_scope()
  self.sympy_call("sympify", [Str(expression)], kwargs={ "locals": Ref(scope) })
}

///|
fn physics_module_expr_str(
  module_name : String,
  function_name : String,
  values : Array[@symcore.Expr],
) -> String raise {
  let recipe = PhysicsRecipe::new()
  recipe.builder.request_str(
    recipe.module_expr_call(module_name, function_name, values),
  )
}

///|
fn physics_source_eval_str(expression : String) -> String raise {
  let recipe = PhysicsRecipe::new()
  recipe.builder.request_str(recipe.physics_sympify(expression))
}

///|
fn physics_source_srepr(expression : String) -> String raise {
  let recipe = PhysicsRecipe::new()
  recipe.builder.request_srepr(recipe.physics_sympify(expression))
}

///|
fn physics_source_matrix(expression : String) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  recipe.matrix_strings(recipe.physics_sympify(expression))
}

///|
fn physics_source_pauli(expression : String, srepr : Bool) -> String raise {
  let recipe = PhysicsRecipe::new()
  let value = recipe.physics_sympify(expression)
  let result = recipe.module_call(
    "sympy.physics.paulialgebra",
    "evaluate_pauli_product",
    [Ref(value)],
  )
  if srepr {
    recipe.builder.request_srepr(result)
  } else {
    recipe.builder.request_str(result)
  }
}

///|
fn physics_source_expr_equal(lhs : String, rhs : String) -> Bool raise {
  let recipe = PhysicsRecipe::new()
  let scope = recipe.physics_scope()
  let lhs_value = recipe.sympy_call("sympify", [Str(lhs)], kwargs={
    "locals": Ref(scope),
  })
  let rhs_value = recipe.sympy_call("sympify", [Str(rhs)], kwargs={
    "locals": Ref(scope),
  })
  let comparison_scope = recipe.builder.sympy_scope()
  let comparator = recipe.builder.eval(
    comparison_scope, "lambda lhs, rhs: (lambda a, b: (lambda verdict: True if verdict == 'True' else False if verdict == 'False' else sympy.srepr(a) == sympy.srepr(b))(str(sympy.simplify(sympy.Eq(a, b)))))(sympy.expand_func(lhs), sympy.expand_func(rhs))",
  )
  let result = recipe.required_call(comparator, [Ref(lhs_value), Ref(rhs_value)])
  recipe.builder.request_bool(result)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  physics_source_expr_equal(lhs, rhs)
}

///|
fn physics_int_call(
  module_name : String,
  function_name : String,
  values : Array[Int],
) -> Int raise {
  let recipe = PhysicsRecipe::new()
  let args : Array[@recipe.RecipeArg] = []
  for value in values {
    args.push(DecimalInt(Show::to_string(value)))
  }
  let result = recipe.module_call(module_name, function_name, args)
  @string.parse_int(recipe.builder.request_int(result)) catch {
    _ => fail("parse-int")
  }
}

///|
fn optics_polarization_matrix_recipe(
  name : String,
  args : Array[@symcore.Expr],
) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  let module_value = recipe.builder.import_module(
    "sympy.physics.optics.polarization",
  )
  let callable = recipe.builder.getattr(module_value, name)
  let matrix = recipe.required_call(callable, recipe.expr_args(args))
  recipe.matrix_strings(matrix)
}

///|
fn optics_medium_property_recipe(
  property : String,
  name : String,
  permittivity : @symcore.Expr?,
  permeability : @symcore.Expr?,
  n : @symcore.Expr?,
) -> String raise {
  let recipe = PhysicsRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  match permittivity {
    Some(value) =>
      kwargs["permittivity"] = Ref(recipe.expressions.encode(value))
    None => ()
  }
  match permeability {
    Some(value) =>
      kwargs["permeability"] = Ref(recipe.expressions.encode(value))
    None => ()
  }
  match n {
    Some(value) => kwargs["n"] = Ref(recipe.expressions.encode(value))
    None => ()
  }
  let medium = recipe.module_call(
    "sympy.physics.optics.medium",
    "Medium",
    [Str(name)],
    kwargs~,
  )
  recipe.builder.request_str(recipe.builder.getattr(medium, property))
}

///|
pub fn msigma(index : Int) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  let matrix = recipe.module_call("sympy.physics.matrices", "msigma", [
    DecimalInt(Show::to_string(index)),
  ])
  recipe.matrix_strings(matrix)
}

///|
pub fn mgamma(index : Int, lower? : Bool = false) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  let matrix = recipe.module_call("sympy.physics.matrices", "mgamma", [
    DecimalInt(Show::to_string(index)),
    Bool(lower),
  ])
  recipe.matrix_strings(matrix)
}

///|
pub fn pat_matrix(
  m : @symcore.Expr,
  dx : @symcore.Expr,
  dy : @symcore.Expr,
  dz : @symcore.Expr,
) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  recipe.matrix_strings(
    recipe.module_expr_call("sympy.physics.matrices", "pat_matrix", [
      m, dx, dy, dz,
    ]),
  )
}

///|
pub fn minkowski_tensor() -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  let module_value = recipe.builder.import_module("sympy.physics.matrices")
  let matrix = recipe.builder.getattr(module_value, "minkowski_tensor")
  recipe.matrix_strings(matrix)
}

///|
pub fn mdft(n : Int) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  let dft = recipe.module_call("sympy.matrices.expressions.fourier", "DFT", [
    DecimalInt(Show::to_string(n)),
  ])
  let explicit = recipe.required_call(
    recipe.builder.getattr(dft, "as_explicit"),
    [],
  )
  recipe.matrix_strings(explicit)
}

///|
pub fn psi_n(
  n : @symcore.Expr,
  x : @symcore.Expr,
  m : @symcore.Expr,
  omega : @symcore.Expr,
) -> String raise {
  physics_module_expr_str("sympy.physics.qho_1d", "psi_n", [n, x, m, omega])
}

///|
pub fn e_n(n : @symcore.Expr, omega : @symcore.Expr) -> String raise {
  physics_module_expr_str("sympy.physics.qho_1d", "E_n", [n, omega])
}

///|
pub fn coherent_state(n : @symcore.Expr, alpha : @symcore.Expr) -> String raise {
  physics_module_expr_str("sympy.physics.qho_1d", "coherent_state", [n, alpha])
}

///|
pub fn r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  nu : @symcore.Expr,
  r : @symcore.Expr,
) -> String raise {
  physics_module_expr_str("sympy.physics.sho", "R_nl", [n, l, nu, r])
}

///|
pub fn e_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  hw : @symcore.Expr,
) -> String raise {
  physics_module_expr_str("sympy.physics.sho", "E_nl", [n, l, hw])
}

///|
pub fn hydrogen_r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  r : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  physics_module_expr_str("sympy.physics.hydrogen", "R_nl", [n, l, r, z])
}

///|
fn expanded_harmonic(
  function_name : String,
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> String raise {
  let recipe = PhysicsRecipe::new()
  let harmonic = recipe.sympy_call(
    function_name,
    recipe.expr_args([l, m, theta, phi]),
  )
  let expanded = recipe.sympy_call("expand_func", [Ref(harmonic)])
  recipe.builder.request_str(expanded)
}

///|
pub fn hydrogen_y_lm(
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> String raise {
  expanded_harmonic("Ynm", l, m, phi, theta)
}

///|
pub fn hydrogen_z_lm(
  l : @symcore.Expr,
  m : @symcore.Expr,
  phi : @symcore.Expr,
  theta : @symcore.Expr,
) -> String raise {
  expanded_harmonic("Znm", l, m, phi, theta)
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
  physics_module_expr_str("sympy.physics.hydrogen", "Psi_nlm", [
    n, l, m, r, phi, theta, z,
  ])
}

///|
pub fn hydrogen_e_nl(
  n : @symcore.Expr,
  z? : @symcore.Expr = @symcore.int(1),
) -> String raise {
  physics_module_expr_str("sympy.physics.hydrogen", "E_nl", [n, z])
}

///|
pub fn hydrogen_e_nl_dirac(
  n : @symcore.Expr,
  l : @symcore.Expr,
  spin_up? : Bool = true,
  z? : @symcore.Expr = @symcore.int(1),
  c~ : @symcore.Expr,
) -> String raise {
  let recipe = PhysicsRecipe::new()
  let result = recipe.module_call("sympy.physics.hydrogen", "E_nl_dirac", [
    Ref(recipe.expressions.encode(n)),
    Ref(recipe.expressions.encode(l)),
    Bool(spin_up),
    Ref(recipe.expressions.encode(z)),
    Ref(recipe.expressions.encode(c)),
  ])
  recipe.builder.request_str(result)
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
  physics_module_expr_str("sympy.physics.wigner", "wigner_3j", [
    j_1, j_2, j_3, m_1, m_2, m_3,
  ])
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
  physics_module_expr_str("sympy.physics.wigner", "clebsch_gordan", [
    j_1, j_2, j_3, m_1, m_2, m_3,
  ])
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
  physics_module_expr_str("sympy.physics.wigner", "gaunt", [
    l_1, l_2, l_3, m_1, m_2, m_3,
  ])
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
  physics_module_expr_str("sympy.physics.wigner", "wigner_6j", [
    j_1, j_2, j_3, j_4, j_5, j_6,
  ])
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
  physics_module_expr_str("sympy.physics.wigner", "racah", [
    aa, bb, cc, dd, ee, ff,
  ])
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
  physics_module_expr_str("sympy.physics.wigner", "wigner_9j", [
    j_1, j_2, j_3, j_4, j_5, j_6, j_7, j_8, j_9,
  ])
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
  physics_module_expr_str("sympy.physics.wigner", "real_gaunt", [
    l_1, l_2, l_3, mu_1, mu_2, mu_3,
  ])
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
  let recipe = PhysicsRecipe::new()
  let value = recipe.module_expr_call(
    "sympy.physics.wigner",
    "dot_rot_grad_Ynm",
    [j, p, l, m, theta, phi],
  )
  let result = recipe.required_call(recipe.builder.getattr(value, "doit"), [])
  recipe.builder.request_str(result)
}

///|
pub fn wigner_d_small(
  j_tot : @symcore.Expr,
  beta : @symcore.Expr,
) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  recipe.matrix_strings(
    recipe.module_expr_call("sympy.physics.wigner", "wigner_d_small", [
      j_tot, beta,
    ]),
  )
}

///|
pub fn wigner_d(
  j_tot : @symcore.Expr,
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> Array[String] raise {
  let recipe = PhysicsRecipe::new()
  recipe.matrix_strings(
    recipe.module_expr_call("sympy.physics.wigner", "wigner_d", [
      j_tot, alpha, beta, gamma,
    ]),
  )
}

///|
pub fn wavefunction(n : @symcore.Expr, x : @symcore.Expr) -> String raise {
  physics_module_expr_str("sympy.physics.pring", "wavefunction", [n, x])
}

///|
pub fn energy(
  n : @symcore.Expr,
  m : @symcore.Expr,
  r : @symcore.Expr,
) -> String raise {
  physics_module_expr_str("sympy.physics.pring", "energy", [n, m, r])
}

///|
fn quantum_cg_render(
  name : String,
  values : Array[@symcore.Expr],
  doit : Bool,
) -> String raise {
  let recipe = PhysicsRecipe::new()
  let value = recipe.module_expr_call("sympy.physics.quantum.cg", name, values)
  let result = if doit {
    recipe.required_call(recipe.builder.getattr(value, "doit"), [])
  } else {
    value
  }
  recipe.builder.request_str(result)
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
  quantum_cg_render("Wigner3j", [j1, m1, j2, m2, j3, m3], false)
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
  quantum_cg_render("Wigner3j", [j1, m1, j2, m2, j3, m3], true)
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
  quantum_cg_render("CG", [j1, m1, j2, m2, j3, m3], false)
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
  quantum_cg_render("CG", [j1, m1, j2, m2, j3, m3], true)
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
  quantum_cg_render("Wigner6j", [j1, j2, j12, j3, j, j23], false)
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
  quantum_cg_render("Wigner6j", [j1, j2, j12, j3, j, j23], true)
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
  quantum_cg_render("Wigner9j", [j1, j2, j12, j3, j4, j34, j13, j24, j], false)
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
  quantum_cg_render("Wigner9j", [j1, j2, j12, j3, j4, j34, j13, j24, j], true)
}

///|
pub fn quantum_cg_simp(expr : String) -> String raise {
  let recipe = PhysicsRecipe::new()
  let result = recipe.module_call("sympy.physics.quantum.cg", "cg_simp", [
    Ref(recipe.physics_sympify(expr)),
  ])
  recipe.builder.request_str(result)
}
