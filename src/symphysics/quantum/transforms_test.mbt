///|
test "physics.quantum.transforms: local canonicalization" {
  let k1 = ket([@symcore.symbol("k1")]).as_expr()
  let k2 = ket([@symcore.symbol("k2")]).as_expr()
  let b1 = bra([@symcore.symbol("k1")]).as_expr()
  let b2 = bra([@symcore.symbol("k2")]).as_expr()
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = operator([@symcore.symbol("B")]).as_expr()

  try! quantum_test_assert_expr_equal(
    try! quantum_canonical_mul(@symcore.raw_mul([b1, k1])),
    "InnerProduct(Bra(k1), Ket(k1))",
    "bra*ket",
  )
  try! quantum_test_assert_expr_equal(
    try! quantum_canonical_mul(@symcore.raw_mul([k1, b1])),
    "OuterProduct(Ket(k1), Bra(k1))",
    "ket*bra",
  )
  try! quantum_test_assert_expr_equal(
    try! quantum_canonical_mul(@symcore.raw_mul([outer_product(k1, b1), k2])),
    "InnerProduct(Bra(k1), Ket(k2))*Ket(k1)",
    "outer product times ket",
  )
  try! quantum_test_assert_expr_equal(
    try! quantum_canonical_mul(@symcore.raw_mul([
      @symcore.raw_function("TensorProduct", [a, b]),
      @symcore.raw_function("TensorProduct", [k1, k2]),
    ])),
    "TensorProduct(Operator(A)*Ket(k1), Operator(B)*Ket(k2))",
    "tensor product action",
  )
  let bad : Result[@symcore.Expr, @symphysics.PhysicsError] = try? quantum_canonical_mul(@symcore.raw_mul([k1, k2]))
  guard bad is Err(_) else { fail("ket*ket should fail") }
  ignore(b2)
}
