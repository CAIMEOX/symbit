///|
test "physics.quantum.grover: matrix parity" {
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(superposition_basis(2), nqubits=2),
    quantum_grover_superposition_matrix(2),
    4,
    1,
    "superposition_basis parity",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(oracle_gate(2, [2]), nqubits=2),
    quantum_grover_oracle_matrix(2, [2]),
    4,
    4,
    "oracle gate matrix parity",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(w_gate(2), nqubits=2),
    quantum_grover_w_matrix(2),
    4,
    4,
    "W gate matrix parity",
  )
}

///|
test "physics.quantum.grover: state parity" {
  quantum_test_assert_matrix_expr_equal(
    qubit_to_matrix(
      qapply(@symcore.raw_mul([oracle_gate(2, [2]), qubit("10").as_expr()])),
      nqubits=2,
    ),
    quantum_grover_oracle_state_matrix(2, [2], 2),
    4,
    1,
    "oracle apply parity",
  )

  quantum_test_assert_matrix_expr_equal(
    qubit_to_matrix(
      qapply(@symcore.raw_mul([w_gate(2), qubit("10").as_expr()])),
      nqubits=2,
    ),
    quantum_grover_w_state_matrix(2, 2),
    4,
    1,
    "W gate apply parity",
  )

  quantum_test_assert_matrix_expr_equal(
    qubit_to_matrix(apply_grover([2], 2, iterations=1), nqubits=2),
    quantum_grover_apply_matrix(2, [2], 1),
    4,
    1,
    "apply_grover parity",
  )
}
