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
  try! quantum_test_assert_expr_equal(
    try! rho.get_state(1),
    "Ket(1)",
    "density get_state",
  )
  try! quantum_test_assert_expr_equal(
    try! rho.get_prob(0),
    "Rational(1, 2)",
    "density get_prob",
  )

  let a = operator([@symcore.symbol("A")]).as_expr()
  try! quantum_test_assert_expr_equal(
    rho.apply_op(a).as_expr(),
    "Density(Tuple(Operator(A)*Ket(0), Rational(1, 2)), Tuple(Operator(A)*Ket(1), Rational(1, 2)))",
    "density apply_op",
  )
  try! quantum_test_assert_expr_equal(
    rho.doit(),
    "Rational(1, 2)*OuterProduct(Ket(0), Bra(0)) + Rational(1, 2)*OuterProduct(Ket(1), Bra(1))",
    "density doit",
  )

  let plus = @symcore.raw_add([k0, k1])
  try! quantum_test_assert_expr_equal(
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

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(mixed.as_expr(), spin_j=half),
    ["1/2", "0", "0", "1/2"],
    2,
    2,
    "density represent matrix",
  )
  try! quantum_test_assert_expr_equal(
    try! entropy(mixed.as_expr(), spin_j=half),
    "log(2)/2",
    "density entropy",
  )
  try! quantum_test_assert_expr_equal(
    try! entropy(pure_up.as_expr(), spin_j=half),
    "0",
    "pure density entropy",
  )
  try! quantum_test_assert_expr_equal(
    try! fidelity(pure_up.as_expr(), pure_up.as_expr(), spin_j=half),
    "1",
    "density fidelity self",
  )
  try! quantum_test_assert_expr_equal(
    try! fidelity(pure_up.as_expr(), pure_down.as_expr(), spin_j=half),
    "0",
    "density fidelity orthogonal",
  )
}

///|
test "physics.quantum.density: tensor-product trace semantics" {
  let half = quantum_test_frac(1, 2)
  let tp = tensor_product([
    jz_ket(half, half).as_expr(),
    jz_ket(half, @symcore.int(-1) * half).as_expr(),
  ]).as_expr()
  let rho = density([(tp, @symcore.int(1))])

  try! quantum_test_assert_expr_equal(
    rho.doit(),
    "TensorProduct(OuterProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzBra(Rational(1, 2), Rational(1, 2))), OuterProduct(JzKet(Rational(1, 2), Rational(-1, 2)), JzBra(Rational(1, 2), Rational(-1, 2))))",
    "density tensor-product doit",
  )
  try! quantum_test_assert_expr_equal(
    rho.trace(),
    "1",
    "density tensor-product trace",
  )
}
