///|
test "physics.quantum.density: local semantics" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)
  let zero = @symcore.int(0)
  let k0 = ket([zero]).as_expr()
  let k1 = ket([one]).as_expr()
  let rho = density([(k0, half), (k1, half)])

  guard @symprint.to_string(rho.states()) == "Tuple(Ket(0), Ket(1))" else {
    fail("density states")
  }
  guard @symprint.to_string(rho.probs()) == "Tuple(1/2, 1/2)" else {
    fail("density probs")
  }
  quantum_test_assert_expr_equal(
    rho.get_state(1),
    "Ket(1)",
    "density get_state",
  )
  quantum_test_assert_expr_equal(
    rho.get_prob(0),
    "Rational(1, 2)",
    "density get_prob",
  )

  let a = operator([@symcore.symbol("A")]).as_expr()
  quantum_test_assert_expr_equal(
    rho.apply_op(a).as_expr(),
    "Density(Tuple(Operator(A)*Ket(0), Rational(1, 2)), Tuple(Operator(A)*Ket(1), Rational(1, 2)))",
    "density apply_op",
  )
  quantum_test_assert_expr_equal(
    rho.doit(),
    "Rational(1, 2)*OuterProduct(Ket(0), Bra(0)) + Rational(1, 2)*OuterProduct(Ket(1), Bra(1))",
    "density doit",
  )

  let plus = @symcore.raw_add([k0, k1])
  quantum_test_assert_expr_equal(
    density([(plus, half)]).doit(),
    "Rational(1, 2)*(OuterProduct(Ket(0), Bra(0)) + OuterProduct(Ket(0), Bra(1)) + OuterProduct(Ket(1), Bra(0)) + OuterProduct(Ket(1), Bra(1)))",
    "density superposition expansion",
  )
}

///|
test "physics.quantum.density: matrix entropy and fidelity" {
  let half = quantum_test_frac(1, 2)
  let up = jz_ket(half, half).as_expr()
  let down = jz_ket(half, @symcore.int(-1) * half).as_expr()
  let mixed = density([(up, half), (down, half)])
  let pure_up = density([(up, @symcore.int(1))])
  let pure_down = density([(down, @symcore.int(1))])

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(mixed.as_expr(), spin_j=half),
    ["1/2", "0", "0", "1/2"],
    2,
    2,
    "density represent matrix",
  )
  quantum_test_assert_expr_equal(
    entropy(mixed.as_expr(), spin_j=half),
    "log(2)/2",
    "density entropy",
  )
  quantum_test_assert_expr_equal(
    entropy(pure_up.as_expr(), spin_j=half),
    "0",
    "pure density entropy",
  )
  quantum_test_assert_expr_equal(
    fidelity(pure_up.as_expr(), pure_up.as_expr(), spin_j=half),
    "1",
    "density fidelity self",
  )
  quantum_test_assert_expr_equal(
    fidelity(pure_up.as_expr(), pure_down.as_expr(), spin_j=half),
    "0",
    "density fidelity orthogonal",
  )
  quantum_test_assert_expr_equal(
    fidelity(pure_up.as_expr(), mixed.as_expr(), spin_j=half),
    "sqrt(2)/2",
    "density fidelity pure-vs-mixed",
  )

  let q0 = qubit("0").as_expr()
  let q1 = qubit("1").as_expr()
  let plus = quantum_test_frac(1, 2) *
    @symcore.raw_function("sqrt", [@symcore.int(2)]) *
    (q0 + q1)
  let rho_left = density([(plus, half), (q0, half)])
  let rho_right = density([(plus, half), (q1, half)])
  quantum_test_assert_expr_equal(
    entropy(rho_left.as_expr(), nqubits=1),
    "-(sqrt(2)/4 + Rational(1, 2))*log(sqrt(2)/4 + Rational(1, 2)) - (Rational(1, 2) - sqrt(2)/4)*log(Rational(1, 2) - sqrt(2)/4)",
    "density general 2x2 entropy",
  )
  quantum_test_assert_expr_equal(
    fidelity(rho_left.as_expr(), rho_right.as_expr(), nqubits=1),
    "sqrt(3)/2",
    "density general 2x2 fidelity",
  )
  let fidelity_lr = fidelity(rho_left.as_expr(), rho_right.as_expr(), nqubits=1)
  let fidelity_rl = fidelity(rho_right.as_expr(), rho_left.as_expr(), nqubits=1)
  guard fidelity_lr == fidelity_rl else { fail("density fidelity symmetry") }
}

///|
test "physics.quantum.density: tensor-product trace semantics" {
  let half = quantum_test_frac(1, 2)
  let tp = tensor_product([
    jz_ket(half, half).as_expr(),
    jz_ket(half, @symcore.int(-1) * half).as_expr(),
  ]).as_expr()
  let rho = density([(tp, @symcore.int(1))])

  quantum_test_assert_expr_equal(
    rho.doit(),
    "TensorProduct(OuterProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzBra(Rational(1, 2), Rational(1, 2))), OuterProduct(JzKet(Rational(1, 2), Rational(-1, 2)), JzBra(Rational(1, 2), Rational(-1, 2))))",
    "density tensor-product doit",
  )
  quantum_test_assert_expr_equal(
    rho.trace(),
    "1",
    "density tensor-product trace",
  )
  quantum_test_assert_expr_equal(
    rho.trace(indices=[1]),
    "OuterProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzBra(Rational(1, 2), Rational(1, 2)))",
    "density tensor-product partial trace",
  )
}
