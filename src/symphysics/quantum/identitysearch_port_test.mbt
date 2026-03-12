///|
test "physics.quantum.identitysearch: parity" {
  let gates = ["XGate(0)", "YGate(0)", "ZGate(0)"]
  let x0 = x_gate(0).as_expr()
  let y0 = y_gate(0).as_expr()
  let z0 = z_gate(0).as_expr()
  try! quantum_test_assert_array_equal(
    (try! generate_equivalent_ids([x0, y0, z0])).map(expr =>
      quantum_gate_sequence_summary(circuit_factors(expr))
    ),
    try! @sympy_physics.quantum_identitysearch_equivalent_ids(gates),
    "generate_equivalent_ids parity",
  )
  try! quantum_test_assert_array_equal(
    quantum_gate_identity_summaries(
      try! bfs_identity_search([x0, y0, z0], 1, max_depth=3),
    ),
    try! @sympy_physics.quantum_identitysearch_bfs_summary(gates, 1, 3, false),
    "bfs_identity_search parity",
  )
}
