///|
fn quantum_gate_sequence_summary(gates : Array[@symcore.Expr]) -> String {
  if gates.is_empty() {
    return "1"
  }
  let parts : Array[String] = []
  for gate in gates {
    match gate_from_expr(gate) {
      Some(parsed) => parts.push(parsed.to_string())
      None => parts.push(@symprint.to_string(gate))
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

  guard (try! is_scalar_matrix([x0, x0], 1, true)) else {
    fail("X*X should be identity")
  }
  guard (try! is_scalar_matrix([x0, y0, z0], 1, false)) else {
    fail("X*Y*Z should be scalar")
  }
  guard !(try! is_scalar_matrix([x0, y0], 1, false)) else {
    fail("X*Y should not be scalar")
  }

  let rules = try! generate_gate_rules([x0, y0, z0])
  let summaries = quantum_gate_rule_summaries(rules)
  guard summaries.length() == 12 else { fail("generate_gate_rules size") }
  guard summaries.contains("X(0)*Y(0)*Z(0) == 1") else {
    fail("generate_gate_rules original identity")
  }
  guard summaries.contains("1 == X(0)*Z(0)*Y(0)") else {
    fail("generate_gate_rules reversed identity")
  }

  let ids = try! generate_equivalent_ids([x0, y0, z0])
  let id_summaries = ids.map(expr => {
    quantum_gate_sequence_summary(circuit_factors(expr))
  })
  guard id_summaries.length() == 6 else { fail("generate_equivalent_ids size") }
  guard id_summaries.contains("X(0)*Y(0)*Z(0)") else {
    fail("generate_equivalent_ids contains original")
  }
}

///|
test "physics.quantum.identitysearch: GateIdentity and searches" {
  let x0 = x_gate(0).as_expr()
  let y0 = y_gate(0).as_expr()
  let z0 = z_gate(0).as_expr()
  let identity = try! build_gate_identity([x0, y0, z0])

  try! quantum_test_assert_string_equal(
    quantum_gate_sequence_summary(identity.sequence_exprs()),
    "X(0)*Y(0)*Z(0)",
    "GateIdentity circuit",
  )
  guard is_degenerate([identity], [y0, z0, x0]) else {
    fail("permutation should be degenerate")
  }
  guard !(try! is_reducible([x0, y0, z0], 1, 1, 3)) else {
    fail("YZ should not be reducible")
  }
  guard (try! is_reducible([x0, y0, y0], 1, 1, 3)) else {
    fail("YY should be reducible")
  }

  let bfs = try! bfs_identity_search([x0, y0, z0], 1, max_depth=3)
  let bfs_summaries = quantum_gate_identity_summaries(bfs)
  guard !bfs_summaries.is_empty() else { fail("bfs should find identities") }
  guard bfs_summaries.contains("X(0)*Y(0)*Z(0)") else {
    fail("bfs contains XYZ")
  }

  let found = match (try! random_identity_search([x0], 2, 1, seed=7)) {
    Some(sequence) => sequence
    None => fail("random_identity_search should find X*X")
  }
  try! quantum_test_assert_array_equal(
    quantum_gate_sequence_strings(found),
    ["X(0)", "X(0)"],
    "random_identity_search deterministic",
  )
}
