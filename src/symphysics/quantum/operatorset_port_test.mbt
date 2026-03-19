///|
test "physics.quantum.operatorset: parity subset" {
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str("operators_to_state(XOp())"),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(operators_to_state(x_op()).unwrap_or(@symcore.int(0))),
    ),
    "operators_to_state(XOp()) parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str("operators_to_state(PxOp())"),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        operators_to_state(px_op()).unwrap_or(@symcore.int(0)),
      ),
    ),
    "operators_to_state(PxOp()) parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str("JxKet(Rational(1, 2), Rational(1, 2))"),
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        operators_to_state_many([j2(), jx()]).unwrap_or(@symcore.int(0)),
      ),
    ),
    "operators_to_state_many([J2, Jx]) parity",
  )
}
