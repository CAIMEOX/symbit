///|
test "physics.quantum.transforms: parity" {
  let k1 = ket([@symcore.symbol("k1")]).as_expr()
  let k2 = ket([@symcore.symbol("k2")]).as_expr()
  let b1 = bra([@symcore.symbol("k1")]).as_expr()
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = operator([@symcore.symbol("B")]).as_expr()

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(try! quantum_canonical_mul(@symcore.raw_mul([b1, k1])))),
    try! @sympy_physics.quantum_eval_str("Bra(k1)*Ket(k1)"),
    "bra*ket parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(try! quantum_canonical_mul(@symcore.raw_mul([k1, b1])))),
    try! @sympy_physics.quantum_eval_str("Ket(k1)*Bra(k1)"),
    "ket*bra parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(try! quantum_canonical_mul(@symcore.raw_mul([
      @symcore.raw_function("TensorProduct", [a, b]),
      @symcore.raw_function("TensorProduct", [k1, k2]),
    ])))),
    try! @sympy_physics.quantum_eval_str("TensorProduct(Operator(A), Operator(B))*TensorProduct(Ket(k1), Ket(k2))"),
    "tensor product parity",
  )
}
