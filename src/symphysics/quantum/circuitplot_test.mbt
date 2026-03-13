///|
test "physics.quantum.circuitplot: labels and gate constructors" {
  inspect(render_label("q0"), content="$\\\\left|q0\\\\right\\\\rangle$")
  inspect(
    render_label("q0", inits={ "q0": "0" }),
    content="$\\\\left|q0\\\\right\\\\rangle=\\\\left|0\\\\right\\\\rangle$",
  )
  inspect(@symprint.to_string(mz(0)), content="Mz(0)")
  inspect(@symprint.to_string(mx(1)), content="Mx(1)")

  let q_gate = create_one_qubit_gate("Q")
  inspect(@symprint.to_string(q_gate(0)), content="Q(0)")

  let cq_gate = create_cgate("Q")
  inspect(@symprint.to_string(cq_gate([1], 0)), content="CGate(Tuple(1), Q(0))")

  guard labeller(2) == ["q_1", "q_0"] else { fail("labeller default") }
  guard labeller(3, symbol="j") == ["j_2", "j_1", "j_0"] else {
    fail("labeller custom symbol")
  }
}

///|
test "physics.quantum.circuitplot: layout metadata" {
  let cnot = circuit_plot(cnot_gate(1, 0).as_expr(), 2, labels=labeller(2))
  guard cnot.ngates == 2 else { fail("cnot ngates") }
  guard cnot.nqubits == 2 else { fail("cnot nqubits") }
  guard cnot.labels == ["q_1", "q_0"] else { fail("cnot labels") }
  guard cnot.gates.length() == 1 else { fail("cnot gate extraction") }
  inspect(
    circuitplot_summary(cnot),
    content="ngates=2;nqubits=2;gate_count=1;measurements=-;labels=q_1,q_0",
  )

  let ex1 = circuit_plot(
    @symcore.raw_mul([cnot_gate(1, 0).as_expr(), hadamard_gate(1).as_expr()]),
    2,
    labels=labeller(2),
  )
  inspect(
    circuitplot_summary(ex1),
    content="ngates=2;nqubits=2;gate_count=2;measurements=-;labels=q_1,q_0",
  )

  let ex4 = circuit_plot(
    @symcore.raw_mul([
      swap_gate(0, 2).as_expr(),
      hadamard_gate(0).as_expr(),
      cgate([0], phase_gate(1).as_expr()),
      hadamard_gate(1).as_expr(),
      cgate([0], t_gate(2).as_expr()),
      cgate([1], phase_gate(2).as_expr()),
      hadamard_gate(2).as_expr(),
    ]),
    3,
    labels=labeller(3, symbol="j"),
  )
  guard ex4.ngates == 7 else { fail("ex4 ngates") }
  guard ex4.nqubits == 3 else { fail("ex4 nqubits") }
  guard ex4.labels == ["j_2", "j_1", "j_0"] else { fail("ex4 labels") }
  inspect(
    circuitplot_summary(ex4),
    content="ngates=7;nqubits=3;gate_count=7;measurements=-;labels=j_2,j_1,j_0",
  )

  let measured = circuit_plot(
    @symcore.raw_mul([mz(0), hadamard_gate(0).as_expr()]),
    1,
    labels=labeller(1),
  )
  inspect(
    circuitplot_summary(measured),
    content="ngates=2;nqubits=1;gate_count=2;measurements=0:1;labels=q_0",
  )
}
