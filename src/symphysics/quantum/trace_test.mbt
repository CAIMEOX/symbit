///|
test "physics.quantum.trace: scalar, symbolic, and matrix trace" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")
  let c_op = @symcore.symbol("C")
  let d_op = @symcore.symbol("D")

  try! quantum_test_assert_string_equal(
    @symprint.to_string(tr(a + b)),
    "a + b",
    "tr scalar add",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(tr(@symcore.raw_mul([a, a_op])))),
    try! @sympy_physics.quantum_eval_str("a*Tr(A)"),
    "tr scalar factor",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(tr(@symcore.raw_mul([a_op, b_op]), indices=[2]))),
    try! @sympy_physics.quantum_eval_str("Tr(A*B, (2,))"),
    "tr explicit tuple",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(tr_permute(tr(@symcore.raw_mul([a_op, b_op, c_op, d_op])), 2)),
    ),
    try! @sympy_physics.quantum_eval_str("Tr(C*D*A*B)"),
    "tr permute",
  )

  let mat = @symphysics.explicit_matrix_from_ints([[1, 2], [3, 4]])
  try! quantum_test_assert_string_equal(
    @symprint.to_string(matrix_trace(mat)),
    "5",
    "trace matrix",
  )
}
