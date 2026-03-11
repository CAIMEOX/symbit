///|
test "physics.quantum.operatorset: local mappings" {
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string((operators_to_state(x_op())).unwrap_or(@symcore.int(0)))),
    try! @sympy_physics.quantum_eval_str("XKet(x)"),
    "XOp to XKet",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string((operators_to_state(px_op())).unwrap_or(@symcore.int(0)))),
    try! @sympy_physics.quantum_eval_str("PxKet(px)"),
    "PxOp to PxKet",
  )
  let ops = (state_to_operators(x_bra(position=@symcore.symbol("y")))).unwrap_or([])
  guard ops.length() == 1 else { fail("expected one operator") }
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(ops[0])),
    try! @sympy_physics.quantum_eval_str("XOp()"),
    "XBra to XOp",
  )

  let generic = (operators_to_state(operator([@symcore.symbol("A")]).as_expr())).unwrap_or(@symcore.int(0))
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(generic)),
    try! @sympy_physics.quantum_eval_str("Ket(psi)"),
    "generic Operator to Ket",
  )
}
