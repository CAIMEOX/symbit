///|
test "physics.quantum.represent helpers: basis discovery and symbolic fallbacks" {
  let xket = x_ket()
  let xop = x_op()

  quantum_test_assert_expr_equal(
    get_basis(xket).unwrap(),
    "XKet(x)",
    "get_basis default state",
  )
  quantum_test_assert_expr_equal(
    get_basis(xop).unwrap(),
    "XKet(x)",
    "get_basis operator to state",
  )
  quantum_test_assert_expr_equal(
    get_basis(xket, basis=Some(px_op())).unwrap(),
    "PxKet(px)",
    "get_basis explicit operator basis",
  )

  let states = enumerate_states(
    x_ket(position=Symbol("foo")),
    start_index=1,
    count=3,
  )
  assert_eq(states.length(), 3)
  quantum_test_assert_expr_equal(
    states[0],
    "XKet(foo_1)",
    "enumerate_states[0]",
  )
  quantum_test_assert_expr_equal(
    states[1],
    "XKet(foo_2)",
    "enumerate_states[1]",
  )
  quantum_test_assert_expr_equal(
    states[2],
    "XKet(foo_3)",
    "enumerate_states[2]",
  )

  quantum_test_assert_expr_equal(
    rep_innerproduct(x_ket()),
    "DiracDelta(x - x_1)",
    "rep_innerproduct cartesian",
  )
  quantum_test_assert_string_equal(
    @symprint.pretty_string(
      match represent(ket([Symbol("k")]).as_expr()) {
        Scalar(value) => value
        Matrix(_) => fail("expected scalar symbolic represent")
      },
    ),
    "InnerProduct(Bra(psi_1), Ket(k))",
    "represent generic ket fallback",
  )
}
