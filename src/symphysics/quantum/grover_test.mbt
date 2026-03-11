///|
test "physics.quantum.grover: local superposition and gate matrices" {
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(try! superposition_basis(2), nqubits=2),
    ["4**(-1/2)", "4**(-1/2)", "4**(-1/2)", "4**(-1/2)"],
    4,
    1,
    "superposition_basis matrix",
  )

  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(try! oracle_gate(2, [2]), nqubits=2),
    ["1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "-1", "0", "0", "0", "0", "1"],
    4,
    4,
    "oracle gate matrix",
  )

  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(try! w_gate(2), nqubits=2),
    [
      "-1/2",
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "-1/2",
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "-1/2",
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "-1/2",
    ],
    4,
    4,
    "W gate matrix",
  )
}

///|
test "physics.quantum.grover: local qapply and iteration" {
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([try! oracle_gate(2, [2]), (try! qubit("10")).as_expr()])),
    "-Qubit(1, 0)",
    "oracle marked apply",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([try! oracle_gate(2, [2]), (try! qubit("11")).as_expr()])),
    "Qubit(1, 1)",
    "oracle unmarked apply",
  )
  let w_matrix = try! qubit_to_matrix(
    qapply(@symcore.raw_mul([try! w_gate(2), (try! qubit("10")).as_expr()])),
    nqubits=2,
  )
  let w_flat = try! matrix_flat_strings(w_matrix)
  guard w_flat == ["1/2", "1/2", "-1/2", "1/2"] else {
    fail("W gate apply: \{w_flat}")
  }

  try! quantum_test_assert_matrix_expr_equal(
    try! qubit_to_matrix(try! apply_grover([2], 2, iterations=1), nqubits=2),
    ["0", "0", "1", "0"],
    4,
    1,
    "apply_grover single marked target",
  )
}
