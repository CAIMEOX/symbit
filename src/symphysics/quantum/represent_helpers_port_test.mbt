///|
test "physics.quantum.represent helpers: parity" {
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_get_basis_str("XKet()"),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(get_basis(x_ket()).unwrap()),
    ),
    "get_basis state parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_get_basis_str("XOp()"),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(get_basis(x_op()).unwrap()),
    ),
    "get_basis operator parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_get_basis_str("XKet()", basis=Some("PxOp()")),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(get_basis(x_ket(), basis=Some(px_op())).unwrap()),
    ),
    "get_basis explicit basis parity",
  )

  let enumerated = enumerate_states(
    x_ket(position=@symcore.symbol("foo")),
    start_index=1,
    count=3,
  )
  let enumerated_text = @sympy_physics.quantum_eval_str(
    "[" + enumerated.map(@symprint.to_string).join(", ") + "]",
  )
  quantum_test_assert_string_equal(
    enumerated_text,
    @sympy_physics.quantum_enumerate_states_str("XKet(foo)", 1, 3),
    "enumerate_states parity",
  )

  quantum_test_assert_expr_equal(
    rep_innerproduct(x_ket()),
    @sympy_physics.quantum_rep_innerproduct_str("XKet()"),
    "rep_innerproduct parity",
  )
  quantum_test_assert_expr_equal(
    rep_expectation(x_op()),
    @sympy_physics.quantum_rep_expectation_str("XOp()"),
    "rep_expectation parity",
  )
}
