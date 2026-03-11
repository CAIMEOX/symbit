///|
test "physics.quantum.commutator: parity" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")
  let c_op = @symcore.symbol("C")

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(commutator(b_op, a_op))),
    try! @sympy_physics.quantum_eval_str("Commutator(B, A)"),
    "commutator canonical parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(commutator(@symcore.raw_mul([a, a_op]), @symcore.raw_mul([b, b_op]))),
    ),
    try! @sympy_physics.quantum_eval_str("Commutator(a*A, b*B)"),
    "commutator scalar factor parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(commutator_expand(commutator(@symcore.raw_mul([a_op, b_op]), c_op, evaluate=false))),
    ),
    try! @sympy_physics.quantum_expand_commutator_str("Commutator(A*B, C)"),
    "commutator expand parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(anticommutator(b_op, a_op)),
    ),
    try! @sympy_physics.quantum_eval_str("AntiCommutator(B, A)"),
    "anticommutator parity",
  )
}
