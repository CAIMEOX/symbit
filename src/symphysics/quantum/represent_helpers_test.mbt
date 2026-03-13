///|
test "physics.quantum.represent helpers: basis discovery and symbolic fallbacks" {
  let xket = x_ket()
  let xop = x_op()

  try! quantum_test_assert_expr_equal(
    get_basis(xket).unwrap(),
    "XKet(x)",
    "get_basis default state",
  )
  try! quantum_test_assert_expr_equal(
    get_basis(xop).unwrap(),
    "XKet(x)",
    "get_basis operator to state",
  )
  try! quantum_test_assert_expr_equal(
    get_basis(xket, basis=Some(px_op())).unwrap(),
    "PxKet(px)",
    "get_basis explicit operator basis",
  )

  let states = try! enumerate_states(
    x_ket(position=@symcore.symbol("foo")),
    start_index=1,
    count=3,
  )
  guard states.length() == 3 else { fail("enumerate_states length") }
  try! quantum_test_assert_expr_equal(
    states[0],
    "XKet(foo_1)",
    "enumerate_states[0]",
  )
  try! quantum_test_assert_expr_equal(
    states[1],
    "XKet(foo_2)",
    "enumerate_states[1]",
  )
  try! quantum_test_assert_expr_equal(
    states[2],
    "XKet(foo_3)",
    "enumerate_states[2]",
  )

  try! quantum_test_assert_expr_equal(
    try! rep_innerproduct(x_ket()),
    "DiracDelta(x - x_1)",
    "rep_innerproduct cartesian",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      match represent(ket([@symcore.symbol("k")]).as_expr()) {
        MatrixScalarValue::Scalar(value) => value
        MatrixScalarValue::Matrix(_) =>
          fail("expected scalar symbolic represent")
      },
    ),
    "InnerProduct(Bra(psi_1), Ket(k))",
    "represent generic ket fallback",
  )
}
