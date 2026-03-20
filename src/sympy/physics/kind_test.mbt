///|
test "physics.quantum.kind: local kinds" {
  let x = @symcore.symbol("x")
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = bra([@symcore.symbol("k")]).as_expr()
  let k = ket([@symcore.symbol("k")]).as_expr()

  assert_true(quantum_kind(k) == QuantumKind::QKet)
  assert_true(quantum_kind(b) == QuantumKind::QBra)
  assert_true(quantum_kind(@symcore.raw_mul([b, k])) == QuantumKind::QNumber)
  assert_true(quantum_kind(@symcore.raw_mul([x, k])) == QuantumKind::QKet)
  assert_true(quantum_kind(a) == QuantumKind::QOperator)
  assert_true(quantum_kind(@symcore.raw_mul([k, b])) == QuantumKind::QOperator)
  assert_true(quantum_kind(@symcore.raw_mul([a, k])) == QuantumKind::QUndefined)
  assert_true(quantum_kind(dagger(k)) == QuantumKind::QBra)
  assert_true(
    quantum_kind(
          commutator(a, operator([@symcore.symbol("B")]).as_expr(), evaluate=false),
        ) ==
        QuantumKind::QOperator
  )
  assert_true(
    quantum_kind(@symcore.raw_function("TensorProduct", [k, k])) ==
        QuantumKind::QKet
  )
}
