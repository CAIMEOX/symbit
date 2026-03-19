///|
fn circuit_oracle_ints(lines : Array[String]) -> Array[Int] {
  let out : Array[Int] = []
  for line in lines {
    let value = @strconv.parse_int(line) catch { _ => panic() }
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
) -> Unit {
  ignore(context)
  guard lhs.length() == rhs.length() else { panic() }
  for idx in 0..<lhs.length() {
    guard lhs[idx] == rhs[idx] else { panic() }
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
  guard kmp_table(circuit_factors(pattern)) ==
    circuit_oracle_ints(
      @sympy_physics.quantum_circuitutils_kmp_table(
        @symprint.to_string(pattern),
      ),
    ) else {
    fail("kmp_table parity")
  }

  let circuit = @symcore.raw_mul([
    x_gate(0).as_expr(),
    z_gate(0).as_expr(),
    y_gate(0).as_expr(),
    hadamard_gate(0).as_expr(),
    z_gate(0).as_expr(),
    y_gate(0).as_expr(),
  ])
  let subcircuit = @symcore.raw_mul([z_gate(0).as_expr(), y_gate(0).as_expr()])
  guard find_subcircuit(circuit, subcircuit, start=2) ==
    @strconv.parse_int(
      @sympy_physics.quantum_circuitutils_find_subcircuit(
        @symprint.to_string(circuit),
        @symprint.to_string(subcircuit),
        start=2,
      ),
    ) else {
    fail("find_subcircuit parity")
  }

  let replacement = @symcore.raw_mul([
    hadamard_gate(0).as_expr(),
    z_gate(0).as_expr(),
  ])
  let local_replace = @symprint.to_string(
    @symcore.raw_mul(
      replace_subcircuit(circuit, subcircuit, replace=Some(replacement)),
    ),
  )
  guard @sympy_physics.physics_srepr(local_replace) ==
    @sympy_physics.quantum_circuitutils_replace_subcircuit(
      @symprint.to_string(circuit),
      @symprint.to_string(subcircuit),
      replace=Some(@symprint.to_string(replacement)),
    ) else {
    fail("replace_subcircuit parity")
  }
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
  let oracle_summary = @sympy_physics.quantum_circuitutils_convert_to_symbolic(
    @symprint.to_string(circuit),
  )
  guard !oracle_summary.is_empty() else {
    fail("missing symbolic oracle summary")
  }
  guard @sympy_physics.physics_srepr(
      @symprint.to_string(@symcore.raw_mul(symbolic.circuit)),
    ) ==
    oracle_summary[0] else {
    fail("convert_to_symbolic_indices circuit parity")
  }
  circuit_assert_string_list_equal(
    circuit_map_strings(symbolic.qubit_map),
    circuit_tail(oracle_summary),
    "convert_to_symbolic_indices map parity",
  )

  let local_real = convert_to_real_indices(
    @symcore.raw_mul(symbolic.circuit),
    symbolic.qubit_map,
  )
  guard @sympy_physics.physics_srepr(
      @symprint.to_string(@symcore.raw_mul(local_real)),
    ) ==
    @sympy_physics.quantum_circuitutils_convert_to_real(
      @symprint.to_string(@symcore.raw_mul(symbolic.circuit)),
      "{i0: 2, i1: 5}",
    ) else {
    fail("convert_to_real_indices parity")
  }
}
