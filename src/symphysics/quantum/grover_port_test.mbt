///|
test "physics.quantum.grover: matrix parity" {
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(try! superposition_basis(2), nqubits=2),
    try! @sympy_physics.quantum_grover_superposition_matrix(2),
    4,
    1,
    "superposition_basis parity",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(try! oracle_gate(2, [2]), nqubits=2),
    try! @sympy_physics.quantum_grover_oracle_matrix(2, [2]),
    4,
    4,
    "oracle gate matrix parity",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(try! w_gate(2), nqubits=2),
    try! @sympy_physics.quantum_grover_w_matrix(2),
    4,
    4,
    "W gate matrix parity",
  )
}

///|
test "physics.quantum.grover: state parity" {
  try! quantum_test_assert_matrix_expr_equal(
    try! qubit_to_matrix(
      qapply(
        @symcore.raw_mul([
          try! oracle_gate(2, [2]),
          (try! qubit("10")).as_expr(),
        ]),
      ),
      nqubits=2,
    ),
    try! @sympy_physics.quantum_grover_oracle_state_matrix(2, [2], 2),
    4,
    1,
    "oracle apply parity",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! qubit_to_matrix(
      qapply(@symcore.raw_mul([try! w_gate(2), (try! qubit("10")).as_expr()])),
      nqubits=2,
    ),
    try! @sympy_physics.quantum_grover_w_state_matrix(2, 2),
    4,
    1,
    "W gate apply parity",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! qubit_to_matrix(try! apply_grover([2], 2, iterations=1), nqubits=2),
    try! @sympy_physics.quantum_grover_apply_matrix(2, [2], 1),
    4,
    1,
    "apply_grover parity",
  )
}
