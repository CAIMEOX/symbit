///|
test "physics.quantum.qasm: helper parity" {
  quantum_test_assert_string_equal(
    fixcommand("Def"),
    @sympy_physics.quantum_qasm_fixcommand("Def"),
    "fixcommand parity",
  )
  quantum_test_assert_string_equal(
    stripquotes("\"S\""),
    @sympy_physics.quantum_qasm_stripquotes("\"S\""),
    "stripquotes parity",
  )
  quantum_test_assert_string_equal(
    trim("something #comment").trim().to_string(),
    @sympy_physics.quantum_qasm_trim("something #comment"),
    "trim parity",
  )
  quantum_test_assert_string_equal(
    get_index("q0", ["q0", "q1"]).to_string(),
    @sympy_physics.quantum_qasm_index("q0", ["q0", "q1"]),
    "get_index parity",
  )
  quantum_test_assert_array_equal(
    get_indices(["q0", "q1"], ["q0", "q1"]).map(v => v.to_string()),
    @sympy_physics.quantum_qasm_indices(["q0", "q1"], ["q0", "q1"]),
    "get_indices parity",
  )
}

///|
test "physics.quantum.qasm: circuit parity" {
  let example = "qubit q0\nqubit q1\nh q0\ncnot q0,q1"
  let example_lines = ["qubit q0", "qubit q1", "h q0", "cnot q0,q1"]
  let parser = read_qasm(example)
  quantum_test_assert_expr_equal(
    parser.get_circuit(),
    @sympy_physics.quantum_qasm_circuit(example_lines),
    "example circuit parity",
  )
  quantum_test_assert_array_equal(
    parser.get_labels(),
    @sympy_physics.quantum_qasm_labels(example_lines),
    "example labels parity",
  )
}
