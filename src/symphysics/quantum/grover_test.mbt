///|
test "physics.quantum.grover: local superposition and gate matrices" {
  quantum_test_assert_matrix_equal(
    represent_matrix(superposition_basis(2), nqubits=2),
    ["4**(-1/2)", "4**(-1/2)", "4**(-1/2)", "4**(-1/2)"],
    4,
    1,
    "superposition_basis matrix",
  )

  quantum_test_assert_matrix_equal(
    represent_matrix(oracle_gate(2, [2]), nqubits=2),
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "-1", "0", "0", "0", "0",
      "1",
    ],
    4,
    4,
    "oracle gate matrix",
  )

  quantum_test_assert_matrix_equal(
    represent_matrix(w_gate(2), nqubits=2),
    [
      "-1/2", "1/2", "1/2", "1/2", "1/2", "-1/2", "1/2", "1/2", "1/2", "1/2", "-1/2",
      "1/2", "1/2", "1/2", "1/2", "-1/2",
    ],
    4,
    4,
    "W gate matrix",
  )
}

///|
test "physics.quantum.grover: local qapply and iteration" {
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([oracle_gate(2, [2]), qubit("10").as_expr()])),
    "-Qubit(1, 0)",
    "oracle marked apply",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([oracle_gate(2, [2]), qubit("11").as_expr()])),
    "Qubit(1, 1)",
    "oracle unmarked apply",
  )
  let w_matrix = qubit_to_matrix(
    qapply(@symcore.raw_mul([w_gate(2), qubit("10").as_expr()])),
    nqubits=2,
  )
  let w_flat = matrix_flat_strings(w_matrix)
  guard w_flat == ["1/2", "1/2", "-1/2", "1/2"] else {
    fail("W gate apply: \{w_flat}")
  }

  quantum_test_assert_matrix_expr_equal(
    qubit_to_matrix(apply_grover([2], 2, iterations=1), nqubits=2),
    ["0", "0", "1", "0"],
    4,
    1,
    "apply_grover single marked target",
  )
}
