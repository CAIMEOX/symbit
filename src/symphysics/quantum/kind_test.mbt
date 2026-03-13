///|
test "physics.quantum.kind: local kinds" {
  let x = @symcore.symbol("x")
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = bra([@symcore.symbol("k")]).as_expr()
  let k = ket([@symcore.symbol("k")]).as_expr()

  guard quantum_kind(k) == QuantumKind::QKet else { fail("ket kind") }
  guard quantum_kind(b) == QuantumKind::QBra else { fail("bra kind") }
  guard quantum_kind(@symcore.raw_mul([b, k])) == QuantumKind::QNumber else {
    fail("inner product kind")
  }
  guard quantum_kind(@symcore.raw_mul([x, k])) == QuantumKind::QKet else {
    fail("scalar ket kind")
  }
  guard quantum_kind(a) == QuantumKind::QOperator else { fail("operator kind") }
  guard quantum_kind(@symcore.raw_mul([k, b])) == QuantumKind::QOperator else {
    fail("outer product kind")
  }
  guard quantum_kind(@symcore.raw_mul([a, k])) == QuantumKind::QUndefined else {
    fail("operator*ket kind")
  }
  guard quantum_kind(dagger(k)) == QuantumKind::QBra else {
    fail("dagger kind")
  }
  guard quantum_kind(
      commutator(a, operator([@symcore.symbol("B")]).as_expr(), evaluate=false),
    ) ==
    QuantumKind::QOperator else {
    fail("commutator kind")
  }
  guard quantum_kind(@symcore.raw_function("TensorProduct", [k, k])) ==
    QuantumKind::QKet else {
    fail("tensorproduct ket kind")
  }
}
