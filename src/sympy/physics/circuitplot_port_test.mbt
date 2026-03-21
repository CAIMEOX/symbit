///|
test "physics.quantum.circuitplot: utility parity" {
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(mz(0))),
    quantum_eval_str("Mz(0)"),
    "Mz parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(mx(1))),
    quantum_eval_str("Mx(1)"),
    "Mx parity",
  )
}

///|
test "physics.quantum.circuitplot: summary parity" {
  let cnot = circuit_plot(cnot_gate(1, 0).as_expr(), 2, labels=labeller(2))
  quantum_test_assert_string_equal(
    circuitplot_summary(cnot),
    quantum_circuitplot_summary("CNotGate(1, 0)", 2, labels=labeller(2)),
    "cnot summary parity",
  )

  let ex1_expr = @symcore.raw_mul([
    cnot_gate(1, 0).as_expr(),
    hadamard_gate(1).as_expr(),
  ])
  quantum_test_assert_string_equal(
    circuitplot_summary(circuit_plot(ex1_expr, 2, labels=labeller(2))),
    quantum_circuitplot_summary(
      "CNotGate(1, 0)*HadamardGate(1)",
      2,
      labels=labeller(2),
    ),
    "ex1 summary parity",
  )

  let ex4_expr = @symcore.raw_mul([
    swap_gate(0, 2).as_expr(),
    hadamard_gate(0).as_expr(),
    cgate([0], phase_gate(1).as_expr()),
    hadamard_gate(1).as_expr(),
    cgate([0], t_gate(2).as_expr()),
    cgate([1], phase_gate(2).as_expr()),
    hadamard_gate(2).as_expr(),
  ])
  quantum_test_assert_string_equal(
    circuitplot_summary(
      circuit_plot(ex4_expr, 3, labels=labeller(3, symbol="j")),
    ),
    quantum_circuitplot_summary(
      "SwapGate(0, 2)*HadamardGate(0)*CGate((0,), PhaseGate(1))*HadamardGate(1)*CGate((0,), TGate(2))*CGate((1,), PhaseGate(2))*HadamardGate(2)",
      3,
      labels=labeller(3, symbol="j"),
    ),
    "ex4 summary parity",
  )

  let measured_expr = @symcore.raw_mul([mz(0), hadamard_gate(0).as_expr()])
  quantum_test_assert_string_equal(
    circuitplot_summary(circuit_plot(measured_expr, 1, labels=labeller(1))),
    quantum_circuitplot_summary("Mz(0)*HadamardGate(0)", 1, labels=labeller(1)),
    "measurement summary parity",
  )
}
