///|
test "physics.quantum.qft: local constructors and dagger" {
  try! quantum_test_assert_expr_equal(rk_gate(0, 1), "ZGate(0)", "rk to z")
  try! quantum_test_assert_expr_equal(rk_gate(0, 2), "PhaseGate(0)", "rk to phase")
  try! quantum_test_assert_expr_equal(rk_gate(0, 3), "TGate(0)", "rk to t")
  try! quantum_test_assert_expr_equal(
    dagger(rk_gate(0, 4)),
    "RkGate(0, -4)",
    "dagger rk",
  )

  let forward = try! qft(0, 2)
  try! quantum_test_assert_expr_equal(forward.as_expr(), "QFT(0, 2)", "qft constructor")
  try! quantum_test_assert_expr_equal(
    forward.inverse().as_expr(),
    "IQFT(0, 2)",
    "qft inverse constructor",
  )
  try! quantum_test_assert_expr_equal(dagger(forward.as_expr()), "IQFT(0, 2)", "dagger qft")
}

///|
test "physics.quantum.qft: local apply, decompose, and represent" {
  let forward = try! qft(0, 2)
  let state = (try! qubit("01")).as_expr()
  let direct = qapply(@symcore.raw_mul([forward.as_expr(), state]))
  try! quantum_test_assert_matrix_expr_equal(
    qubit_to_matrix(direct, nqubits=2),
    [
      "4**(-1/2)",
      "exp((2*I*pi*4**-1))*4**(-1/2)",
      "exp((2*I*pi*4**-1))**2*4**(-1/2)",
      "exp((2*I*pi*4**-1))**3*4**(-1/2)",
    ],
    4,
    1,
    "qft direct action",
  )
  let forward_matrix = try! represent_matrix(forward.as_expr(), nqubits=2)
  let decomposed_matrix = try! represent_matrix(qft_decompose(forward), nqubits=2)
  try! quantum_test_assert_matrix_expr_equal(
    decomposed_matrix,
    try! matrix_flat_strings(forward_matrix),
    4,
    4,
    "qft decomposition matrix",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(rk_gate(0, 4), nqubits=1),
    ["1", "0", "0", "exp(I*pi/8)"],
    2,
    2,
    "rk represent matrix",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(forward.as_expr(), nqubits=2),
    [
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "1/2",
      "I/2",
      "-1/2",
      "-I/2",
      "1/2",
      "-1/2",
      "1/2",
      "-1/2",
      "1/2",
      "-I/2",
      "-1/2",
      "I/2",
    ],
    4,
    4,
    "qft represent matrix",
  )
}
