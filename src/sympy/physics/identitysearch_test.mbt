///|
fn quantum_gate_sequence_summary(gates : Array[@symcore.Expr]) -> String {
  if gates.is_empty() {
    return "1"
  }
  let parts : Array[String] = []
  for gate in gates {
    match gate_from_expr(gate) {
      Some(parsed) => parts.push(parsed.to_string())
      None => parts.push(@symprint.pretty_string(gate))
    }
  }
  parts.join("*")
}

///|
fn quantum_gate_sequence_strings(gates : Array[@symcore.Expr]) -> Array[String] {
  gates.map(gate => quantum_gate_sequence_summary([gate]))
}

///|
fn quantum_gate_rule_summaries(rules : Array[GateRule]) -> Array[String] {
  let out = rules.map(rule => {
    quantum_gate_sequence_summary(rule.left) +
    " == " +
    quantum_gate_sequence_summary(rule.right)
  })
  out.sort()
  out
}

///|
fn quantum_gate_identity_summaries(ids : Array[GateIdentity]) -> Array[String] {
  let out = ids.map(id => {
    quantum_gate_sequence_summary(circuit_factors(id.circuit()))
  })
  out.sort()
  out
}

///|
test "physics.quantum.identitysearch: scalar detection and rule generation" {
  let x0 = x_gate(0).as_expr()
  let y0 = y_gate(0).as_expr()
  let z0 = z_gate(0).as_expr()

  assert_true(is_scalar_matrix([x0, x0], 1, true))
  assert_true(is_scalar_matrix([x0, y0, z0], 1, false))
  assert_true(!is_scalar_matrix([x0, y0], 1, false))

  let rules = generate_gate_rules([x0, y0, z0])
  let summaries = quantum_gate_rule_summaries(rules)
  assert_eq(summaries.length(), 12)
  assert_true(summaries.contains("X(0)*Y(0)*Z(0) == 1"))
  assert_true(summaries.contains("1 == X(0)*Z(0)*Y(0)"))

  let ids = generate_equivalent_ids([x0, y0, z0])
  let id_summaries = ids.map(expr => {
    quantum_gate_sequence_summary(circuit_factors(expr))
  })
  assert_eq(id_summaries.length(), 6)
  assert_true(id_summaries.contains("X(0)*Y(0)*Z(0)"))
}

///|
test "physics.quantum.identitysearch: GateIdentity and searches" {
  let x0 = x_gate(0).as_expr()
  let y0 = y_gate(0).as_expr()
  let z0 = z_gate(0).as_expr()
  let identity = build_gate_identity([x0, y0, z0])

  quantum_test_assert_string_equal(
    quantum_gate_sequence_summary(identity.sequence_exprs()),
    "X(0)*Y(0)*Z(0)",
    "GateIdentity circuit",
  )
  assert_true(is_degenerate([identity], [y0, z0, x0]))
  assert_true(!is_reducible([x0, y0, z0], 1, 1, 3))
  assert_true(is_reducible([x0, y0, y0], 1, 1, 3))

  let bfs = bfs_identity_search([x0, y0, z0], 1, max_depth=3)
  let bfs_summaries = quantum_gate_identity_summaries(bfs)
  assert_true(!bfs_summaries.is_empty())
  assert_true(bfs_summaries.contains("X(0)*Y(0)*Z(0)"))

  let found = match random_identity_search([x0], 2, 1, seed=7) {
    Some(sequence) => sequence
    None => fail("random_identity_search should find X*X")
  }
  quantum_test_assert_array_equal(
    quantum_gate_sequence_strings(found),
    ["X(0)", "X(0)"],
    "random_identity_search deterministic",
  )
}
