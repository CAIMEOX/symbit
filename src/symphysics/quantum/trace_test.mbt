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
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(tr(@symcore.raw_mul([a, a_op]))),
    ),
    try! @sympy_physics.quantum_eval_str("a*Tr(A)"),
    "tr scalar factor",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(tr(@symcore.raw_mul([a_op, b_op]), indices=[2])),
    ),
    try! @sympy_physics.quantum_eval_str("Tr(A*B, (2,))"),
    "tr explicit tuple",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        tr_permute(tr(@symcore.raw_mul([a_op, b_op, c_op, d_op])), 2),
      ),
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

  let tp = tensor_product([
    outer_product(
      (try! qubit("0")).as_expr(),
      (try! qubit("0")).dual().as_expr(),
    ),
    outer_product(
      (try! qubit("1")).as_expr(),
      (try! qubit("1")).dual().as_expr(),
    ),
  ]).as_expr()
  try! quantum_test_assert_expr_equal(
    tr_doit(tr(tp)),
    "1",
    "trace tensor product factorization",
  )
  try! quantum_test_assert_expr_equal(
    tr_doit(tr(tp, indices=[1])),
    "OuterProduct(Qubit(0), QubitBra(0))",
    "trace tensor product partial factorization",
  )

  let half = quantum_test_frac(1, 2)
  let rho = density([
    (jz_ket(half, half).as_expr(), half),
    (jz_ket(half, @symcore.int(-1) * half).as_expr(), half),
  ]).as_expr()
  try! quantum_test_assert_expr_equal(
    tr_doit(tr(rho)),
    "1",
    "trace density doit",
  )

  let rho_tp = density([
    (
      tensor_product([(try! qubit("0")).as_expr(), (try! qubit("1")).as_expr()]).as_expr(),
      @symcore.int(1),
    ),
  ]).as_expr()
  try! quantum_test_assert_expr_equal(
    tr_doit(tr(rho_tp, indices=[1])),
    "OuterProduct(Qubit(0), QubitBra(0))",
    "trace density partial doit",
  )
}
