///|
test "physics.quantum.kind: parity" {
  quantum_test_assert_string_equal(
    Show::to_string(
      quantum_kind(
        @symcore.raw_mul([
          bra([Symbol("k")]).as_expr(),
          ket([Symbol("k")]).as_expr(),
        ]),
      ),
    ),
    quantum_kind_str("Bra(k)*Ket(k)"),
    "inner product kind parity",
  )
  quantum_test_assert_string_equal(
    Show::to_string(quantum_kind(operator([Symbol("A")]).as_expr())),
    quantum_kind_str("Operator(A)"),
    "operator kind parity",
  )
  quantum_test_assert_string_equal(
    Show::to_string(
      quantum_kind(
        @symcore.raw_function("TensorProduct", [
          ket([Symbol("k1")]).as_expr(),
          ket([Symbol("k2")]).as_expr(),
        ]),
      ),
    ),
    quantum_kind_str("TensorProduct(Ket(k1), Ket(k2))"),
    "tensorproduct kind parity",
  )
}
