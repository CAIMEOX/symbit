///|
test "physics.quantum.operatorset: parity subset" {
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("operators_to_state(XOp())"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(operators_to_state(x_op()).unwrap_or(@symcore.int(0))),
    ),
    "operators_to_state(XOp()) parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("operators_to_state(PxOp())"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        operators_to_state(px_op()).unwrap_or(@symcore.int(0)),
      ),
    ),
    "operators_to_state(PxOp()) parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "JxKet(Rational(1, 2), Rational(1, 2))",
    ),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        operators_to_state_many([j2(), jx()]).unwrap_or(@symcore.int(0)),
      ),
    ),
    "operators_to_state_many([J2, Jx]) parity",
  )
}
