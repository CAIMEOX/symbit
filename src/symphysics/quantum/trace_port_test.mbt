///|
test "physics.quantum.trace: parity" {
  let a = @symcore.symbol("a")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")
  let c_op = @symcore.symbol("C")
  let d_op = @symcore.symbol("D")

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(tr(@symcore.raw_mul([a, a_op])))),
    try! @sympy_physics.quantum_eval_str("Tr(a*A)"),
    "trace scalar parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(tr(@symcore.raw_mul([a_op, b_op]), indices=[2]))),
    try! @sympy_physics.quantum_eval_str("Tr(A*B, (2,))"),
    "trace tuple parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(tr_permute(tr(@symcore.raw_mul([a_op, b_op, c_op, d_op])), 2)),
    ),
    try! @sympy_physics.quantum_trace_permute_str("Tr(A*B*C*D)", 2),
    "trace permute parity",
  )
}
