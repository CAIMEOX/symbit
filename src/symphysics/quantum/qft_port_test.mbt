///|
test "physics.quantum.qft: parity" {
  let forward = try! qft(0, 2)
  let state = (try! qubit("01")).as_expr()

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(qft_decompose(forward))),
    try! @sympy_physics.quantum_eval_str("QFT(0, 2).decompose()"),
    "qft decompose parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(@symprint.to_string(@symcore.raw_mul([forward.as_expr(), state]))),
    try! @sympy_physics.quantum_qapply_str("QFT(0, 2)*Qubit(0, 1)"),
    "qft qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(@symprint.to_string(@symcore.raw_mul([rk_gate(0, 4), (try! qubit("1")).as_expr()]))),
    try! @sympy_physics.quantum_qapply_str("RkGate(0, 4)*Qubit(1)"),
    "rk qapply parity",
  )
}

///|
test "physics.quantum.qft: represent and dagger parity" {
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix((try! qft(0, 2)).as_expr(), nqubits=2),
    try! @sympy_physics.physics_eval_matrix("represent(QFT(0, 2), nqubits=2)"),
    4,
    4,
    "qft represent parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(rk_gate(0, 4), nqubits=1),
    try! @sympy_physics.physics_eval_matrix("represent(RkGate(0, 4), nqubits=1)"),
    2,
    2,
    "rk represent parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger((try! qft(0, 2)).as_expr()))),
    try! @sympy_physics.quantum_eval_str("IQFT(0, 2)"),
    "dagger qft parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger(rk_gate(0, 4)))),
    try! @sympy_physics.quantum_eval_str("RkGate(0, -4)"),
    "dagger rk parity",
  )
}
