///|
test "physics.quantum.density: parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)
  let zero = @symcore.int(0)
  let k0 = ket([zero]).as_expr()
  let k1 = ket([one]).as_expr()
  let rho = density([(k0, half), (k1, half)])
  let rho_txt = @symprint.to_string(rho.as_expr())

  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.states())),
    quantum_density_states_str(rho_txt),
    "density states parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.probs())),
    quantum_density_probs_str(rho_txt),
    "density probs parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.get_state(1))),
    quantum_density_get_state_str(rho_txt, 1),
    "density get_state parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.get_prob(0))),
    quantum_density_get_prob_str(rho_txt, 0),
    "density get_prob parity",
  )

  let a = operator([@symcore.Expr::Symbol("A")]).as_expr()
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.apply_op(a).as_expr())),
    quantum_density_apply_op_str(rho_txt, "Operator(A)"),
    "density apply_op parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.doit())),
    quantum_doit_str(rho_txt),
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

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(mixed.as_expr(), spin_j=half),
    physics_eval_matrix(
      "represent(Density((JzKet(Rational(1, 2), Rational(1, 2)), Rational(1, 2)), (JzKet(Rational(1, 2), Rational(-1, 2)), Rational(1, 2))))",
    ),
    2,
    2,
    "density represent parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(entropy(mixed.as_expr(), spin_j=half))),
    quantum_entropy_str(
      "Density((JzKet(Rational(1, 2), Rational(1, 2)), Rational(1, 2)), (JzKet(Rational(1, 2), Rational(-1, 2)), Rational(1, 2)))",
    ),
    "density entropy parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        fidelity(pure_up.as_expr(), pure_down.as_expr(), spin_j=half),
      ),
    ),
    quantum_fidelity_str(
      "Density((JzKet(Rational(1, 2), Rational(1, 2)), 1))", "Density((JzKet(Rational(1, 2), Rational(-1, 2)), 1))",
    ),
    "density fidelity parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        fidelity(pure_up.as_expr(), mixed.as_expr(), spin_j=half),
      ),
    ),
    quantum_fidelity_str(
      "Density((JzKet(Rational(1, 2), Rational(1, 2)), 1))", "Density((JzKet(Rational(1, 2), Rational(1, 2)), Rational(1, 2)), (JzKet(Rational(1, 2), Rational(-1, 2)), Rational(1, 2)))",
    ),
    "density pure-vs-mixed fidelity parity",
  )

  let q0 = qubit("0").as_expr()
  let q1 = qubit("1").as_expr()
  let plus = quantum_test_frac(1, 2) *
    @symcore.raw_function("sqrt", [@symcore.int(2)]) *
    (q0 + q1)
  let rho_left = density([(plus, half), (q0, half)])
  let rho_right = density([(plus, half), (q1, half)])
  let rho_left_txt = "Density((sqrt(2)*(Qubit(0) + Qubit(1))/2, Rational(1, 2)), (Qubit(0), Rational(1, 2)))"
  let rho_right_txt = "Density((sqrt(2)*(Qubit(0) + Qubit(1))/2, Rational(1, 2)), (Qubit(1), Rational(1, 2)))"
  quantum_test_assert_expr_equal(
    entropy(rho_left.as_expr(), nqubits=1),
    quantum_entropy_str(rho_left_txt),
    "density general 2x2 entropy parity",
  )
  quantum_test_assert_expr_equal(
    fidelity(rho_left.as_expr(), rho_right.as_expr(), nqubits=1),
    quantum_fidelity_str(rho_left_txt, rho_right_txt),
    "density general 2x2 fidelity parity",
  )
}

///|
test "physics.quantum.density: tensor-product trace parity" {
  let half = quantum_test_frac(1, 2)
  let tp = @symquant.tensor_product([
    jz_ket(half, half).as_expr(),
    jz_ket(half, @symcore.int(-1) * half).as_expr(),
  ]).as_expr()
  let rho = density([(tp, @symcore.int(1))])
  let rho_txt = @symprint.to_string(rho.as_expr())

  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.doit())),
    quantum_doit_str(rho_txt),
    "density tensor-product doit parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.trace())),
    quantum_eval_str("Tr(\{rho_txt}).doit()"),
    "density tensor-product trace parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(rho.trace(indices=[1]))),
    quantum_doit_str("Tr(\{rho_txt}, [1])"),
    "density tensor-product partial trace parity",
  )
}
