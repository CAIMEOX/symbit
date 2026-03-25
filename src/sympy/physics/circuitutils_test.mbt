///|
fn circuit_factor_strings(items : Array[@symcore.Expr]) -> Array[String] {
  items.map(@symprint.to_string)
}

///|
fn circuit_map_strings(mapping : Map[String, Int]) -> Array[String] {
  let keys : Array[String] = []
  for key in mapping.keys() {
    keys.push(key)
  }
  keys.sort()
  let out : Array[String] = []
  for key in keys {
    match mapping.get(key) {
      Some(value) => out.push("\{key}=\{value.to_string()}")
      None => ()
    }
  }
  out
}

///|
test "physics.quantum.circuitutils: search and replace" {
  let pattern = @symcore.raw_mul([
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    x_gate(0).as_expr(),
  ])
  assert_eq(kmp_table(circuit_factors(pattern)), [-1, 0, 0, 1, 2])

  let circuit = @symcore.raw_mul([
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    y_gate(0).as_expr(),
    hadamard_gate(0).as_expr(),
    z_gate(0).as_expr(),
    y_gate(0).as_expr(),
  ])
  let subcircuit = @symcore.raw_mul([z_gate(0).as_expr(), y_gate(0).as_expr()])
  assert_eq(find_subcircuit(circuit, subcircuit), 1)
  assert_eq(find_subcircuit(circuit, subcircuit, start=2), 4)

  let removed = replace_subcircuit(circuit, subcircuit)
  assert_eq(circuit_factor_strings(removed), [
    "XGate(0)", "HadamardGate(0)", "ZGate(0)", "YGate(0)",
  ])

  let replacement = @symcore.raw_mul([
    hadamard_gate(0).as_expr(),
    z_gate(0).as_expr(),
  ])
  let replaced = replace_subcircuit(
    circuit,
    subcircuit,
    replace=Some(replacement),
  )
  assert_eq(circuit_factor_strings(replaced), [
    "XGate(0)", "HadamardGate(0)", "ZGate(0)", "HadamardGate(0)", "ZGate(0)", "YGate(0)",
  ])
}

///|
test "physics.quantum.circuitutils: symbolic indices and random helpers" {
  let circuit = @symcore.raw_mul([
    x_gate(2).as_expr(),
    y_gate(5).as_expr(),
    hadamard_gate(2).as_expr(),
    cgate([5], x_gate(2).as_expr()),
  ])
  let symbolic = convert_to_symbolic_indices(circuit)
  assert_eq(circuit_factor_strings(symbolic.circuit), [
    "XGate(i0)", "YGate(i1)", "HadamardGate(i0)", "CGate((i1,), XGate(i0))",
  ])
  assert_eq(circuit_map_strings(symbolic.qubit_map), ["i0=2", "i1=5"])
  assert_eq(symbolic.next_index, 2)

  let roundtrip = convert_to_real_indices(
    @symcore.raw_mul(symbolic.circuit),
    symbolic.qubit_map,
  )
  assert_eq(
    circuit_factor_strings(roundtrip),
    circuit_factor_strings(circuit_factors(circuit)),
  )

  let identities = [
    gate_identity([
      @symcore.raw_mul([hadamard_gate(0).as_expr(), hadamard_gate(0).as_expr()]),
    ]),
  ]
  let reduced = random_reduce(
    @symcore.raw_mul([
      z_gate(0).as_expr(),
      hadamard_gate(0).as_expr(),
      hadamard_gate(0).as_expr(),
      x_gate(1).as_expr(),
    ]),
    identities,
    seed=[0],
  )
  assert_eq(circuit_factor_strings(reduced), ["ZGate(0)", "XGate(1)"])

  let inserted = random_insert(
    @symcore.raw_mul([x_gate(0).as_expr(), z_gate(0).as_expr()]),
    [@symcore.raw_mul([hadamard_gate(1).as_expr(), y_gate(1).as_expr()])],
    seed=[1, 0],
  )
  assert_eq(circuit_factor_strings(inserted), [
    "XGate(0)", "HadamardGate(1)", "YGate(1)", "ZGate(0)",
  ])
}
