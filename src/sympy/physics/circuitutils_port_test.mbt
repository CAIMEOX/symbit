///|
fn circuit_oracle_ints(lines : Array[String]) -> Array[Int] raise {
  let out : Array[Int] = []
  for line in lines {
    let value = @string.parse_int(line)
    out.push(value)
  }
  out
}

///|
fn circuit_tail(lines : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for idx in 1..<lines.length() {
    out.push(lines[idx])
  }
  out
}

///|
fn circuit_assert_string_list_equal(
  lhs : Array[String],
  rhs : Array[String],
  context : String,
) -> Unit raise {
  ignore(context)
  assert_eq(lhs.length(), rhs.length())
  for idx in 0..<lhs.length() {
    assert_eq(lhs[idx], rhs[idx])
  }
}

///|
test "physics.quantum.circuitutils: search parity" {
  let pattern = @symcore.raw_mul([
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    x_gate(0).as_expr(),
  ])
  assert_eq(
    kmp_table(circuit_factors(pattern)),
    circuit_oracle_ints(
      quantum_circuitutils_kmp_table(@symprint.pretty_string(pattern)),
    ),
  )

  let circuit = @symcore.raw_mul([
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    y_gate(0).as_expr(),
    hadamard_gate(0).as_expr(),
    z_gate(0).as_expr(),
    y_gate(0).as_expr(),
  ])
  let subcircuit = @symcore.raw_mul([z_gate(0).as_expr(), y_gate(0).as_expr()])
  assert_eq(
    find_subcircuit(circuit, subcircuit, start=2),
    @string.parse_int(
      quantum_circuitutils_find_subcircuit(
        @symprint.pretty_string(circuit),
        @symprint.pretty_string(subcircuit),
        start=2,
      ),
    ),
  )

  let replacement = @symcore.raw_mul([
    hadamard_gate(0).as_expr(),
    z_gate(0).as_expr(),
  ])
  let local_replace = @symprint.pretty_string(
    @symcore.raw_mul(
      replace_subcircuit(circuit, subcircuit, replace=Some(replacement)),
    ),
  )
  assert_eq(
    physics_srepr(local_replace),
    quantum_circuitutils_replace_subcircuit(
      @symprint.pretty_string(circuit),
      @symprint.pretty_string(subcircuit),
      replace=Some(@symprint.pretty_string(replacement)),
    ),
  )
}

///|
test "physics.quantum.circuitutils: symbolic index parity" {
  let circuit = @symcore.raw_mul([
    x_gate(2).as_expr(),
    y_gate(5).as_expr(),
    hadamard_gate(2).as_expr(),
    cgate([5], x_gate(2).as_expr()),
  ])
  let symbolic = convert_to_symbolic_indices(circuit)
  let oracle_summary = quantum_circuitutils_convert_to_symbolic(
    @symprint.pretty_string(circuit),
  )
  assert_true(!oracle_summary.is_empty())
  assert_eq(
    physics_srepr(@symprint.pretty_string(@symcore.raw_mul(symbolic.circuit))),
    oracle_summary[0],
  )
  circuit_assert_string_list_equal(
    circuit_map_strings(symbolic.qubit_map),
    circuit_tail(oracle_summary),
    "convert_to_symbolic_indices map parity",
  )

  let local_real = convert_to_real_indices(
    @symcore.raw_mul(symbolic.circuit),
    symbolic.qubit_map,
  )
  assert_eq(
    physics_srepr(@symprint.pretty_string(@symcore.raw_mul(local_real))),
    quantum_circuitutils_convert_to_real(
      @symprint.pretty_string(@symcore.raw_mul(symbolic.circuit)),
      "{i0: 2, i1: 5}",
    ),
  )
}
