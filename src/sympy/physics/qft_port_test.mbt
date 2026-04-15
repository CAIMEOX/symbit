///|
test "physics.quantum.qft: parity" {
  let forward = qft(0, 2)
  let state = qubit("01").as_expr()

  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(qft_decompose(forward))),
    quantum_eval_str("QFT(0, 2).decompose()"),
    "qft decompose parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      @symprint.pretty_string(@symcore.raw_mul([forward.as_expr(), state])),
    ),
    quantum_qapply_str("QFT(0, 2)*Qubit(0, 1)"),
    "qft qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      @symprint.pretty_string(
        @symcore.raw_mul([rk_gate(0, 4), qubit("1").as_expr()]),
      ),
    ),
    quantum_qapply_str("RkGate(0, 4)*Qubit(1)"),
    "rk qapply parity",
  )
}

///|
test "physics.quantum.qft: represent and dagger parity" {
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(qft(0, 2).as_expr(), nqubits=2),
    physics_eval_matrix("represent(QFT(0, 2), nqubits=2)"),
    4,
    4,
    "qft represent parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(rk_gate(0, 4), nqubits=1),
    physics_eval_matrix("represent(RkGate(0, 4), nqubits=1)"),
    2,
    2,
    "rk represent parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(dagger(qft(0, 2).as_expr()))),
    quantum_eval_str("IQFT(0, 2)"),
    "dagger qft parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.pretty_string(dagger(rk_gate(0, 4)))),
    quantum_eval_str("RkGate(0, -4)"),
    "dagger rk parity",
  )
}
