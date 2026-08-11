///|
test "physics.quantum.kind: local kinds" {
  let x = @symcore.Expr::Symbol("x")
  let a = operator([Symbol("A")]).as_expr()
  let b = bra([Symbol("k")]).as_expr()
  let k = ket([Symbol("k")]).as_expr()

  assert_true(quantum_kind(k) == QKet)
  assert_true(quantum_kind(b) == QBra)
  assert_true(quantum_kind(@symcore.raw_mul([b, k])) == QNumber)
  assert_true(quantum_kind(@symcore.raw_mul([x, k])) == QKet)
  assert_true(quantum_kind(a) == QOperator)
  assert_true(quantum_kind(@symcore.raw_mul([k, b])) == QOperator)
  assert_true(quantum_kind(@symcore.raw_mul([a, k])) == QUndefined)
  assert_true(quantum_kind(dagger(k)) == QBra)
  assert_true(
    quantum_kind(
      commutator(a, operator([Symbol("B")]).as_expr(), evaluate=false),
    ) ==
    QOperator,
  )
  assert_true(
    quantum_kind(@symcore.raw_function("TensorProduct", [k, k])) == QKet,
  )
}
