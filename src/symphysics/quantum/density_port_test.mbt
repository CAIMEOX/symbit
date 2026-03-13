///|
test "physics.quantum.density: parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)
  let zero = @symcore.int(0)
  let k0 = ket([zero]).as_expr()
  let k1 = ket([one]).as_expr()
  let rho = density([(k0, half), (k1, half)])
  let rho_txt = @symprint.to_string(rho.as_expr())

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(rho.states())),
    try! @sympy_physics.quantum_density_states_str(rho_txt),
    "density states parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(rho.probs())),
    try! @sympy_physics.quantum_density_probs_str(rho_txt),
    "density probs parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(try! rho.get_state(1)),
    ),
    try! @sympy_physics.quantum_density_get_state_str(rho_txt, 1),
    "density get_state parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(try! rho.get_prob(0)),
    ),
    try! @sympy_physics.quantum_density_get_prob_str(rho_txt, 0),
    "density get_prob parity",
  )

  let a = operator([@symcore.symbol("A")]).as_expr()
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(rho.apply_op(a).as_expr()),
    ),
    try! @sympy_physics.quantum_density_apply_op_str(rho_txt, "Operator(A)"),
    "density apply_op parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(rho.doit())),
    try! @sympy_physics.quantum_doit_str(rho_txt),
    "density doit parity",
  )
}

///|
test "physics.quantum.density: matrix entropy fidelity parity" {
  let half = quantum_test_frac(1, 2)
  let up = jz_ket(half, half).as_expr()
  let down = jz_ket(half, @symcore.int(-1) * half).as_expr()
  let mixed = density([(up, half), (down, half)])
  let pure_up = density([(up, @symcore.int(1))])
  let pure_down = density([(down, @symcore.int(1))])

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(mixed.as_expr(), spin_j=half),
    try! @sympy_physics.physics_eval_matrix(
      "represent(Density((JzKet(Rational(1, 2), Rational(1, 2)), Rational(1, 2)), (JzKet(Rational(1, 2), Rational(-1, 2)), Rational(1, 2))))",
    ),
    2,
    2,
    "density represent parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(try! entropy(mixed.as_expr(), spin_j=half)),
    ),
    try! @sympy_physics.quantum_entropy_str(
      "Density((JzKet(Rational(1, 2), Rational(1, 2)), Rational(1, 2)), (JzKet(Rational(1, 2), Rational(-1, 2)), Rational(1, 2)))",
    ),
    "density entropy parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        try! fidelity(pure_up.as_expr(), pure_down.as_expr(), spin_j=half),
      ),
    ),
    try! @sympy_physics.quantum_fidelity_str(
      "Density((JzKet(Rational(1, 2), Rational(1, 2)), 1))", "Density((JzKet(Rational(1, 2), Rational(-1, 2)), 1))",
    ),
    "density fidelity parity",
  )
}
