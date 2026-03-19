///|
test "physics.quantum.kind: parity" {
  quantum_test_assert_string_equal(
    quantum_kind(
      @symcore.raw_mul([
        bra([@symcore.symbol("k")]).as_expr(),
        ket([@symcore.symbol("k")]).as_expr(),
      ]),
    ).to_string(),
    @sympy_physics.quantum_kind_str("Bra(k)*Ket(k)"),
    "inner product kind parity",
  )
  quantum_test_assert_string_equal(
    quantum_kind(operator([@symcore.symbol("A")]).as_expr()).to_string(),
    @sympy_physics.quantum_kind_str("Operator(A)"),
    "operator kind parity",
  )
  quantum_test_assert_string_equal(
    quantum_kind(
      @symcore.raw_function("TensorProduct", [
        ket([@symcore.symbol("k1")]).as_expr(),
        ket([@symcore.symbol("k2")]).as_expr(),
      ]),
    ).to_string(),
    @sympy_physics.quantum_kind_str("TensorProduct(Ket(k1), Ket(k2))"),
    "tensorproduct kind parity",
  )
}
