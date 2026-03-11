///|
test "physics.quantum.qubit: core state helpers" {
  let q = try! qubit("0101")
  inspect(q.to_string(), content="|0101>")
  inspect(q.repr(), content="Qubit(Integer(0),Integer(1),Integer(0),Integer(1))")
  inspect((try! q.flip(1)).to_string(), content="|0111>")
  inspect(q.dual().to_string(), content="<0101|")
  inspect(q.nqubits().to_string(), content="4")
  inspect(q.dimension().to_string(), content="4")

  let iq = try! int_qubit(5, 3)
  inspect(iq.to_string(), content="|5>")
  inspect(iq.repr(), content="IntQubit(Integer(5))")
  inspect(@symprint.to_string(iq.as_expr()), content="IntQubit(5)")
}

///|
test "physics.quantum.qubit/gate/represent: local actions" {
  let zero_zero = (try! qubit("00")).as_expr()
  let one_zero = (try! qubit("10")).as_expr()

  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([x_gate(0).as_expr(), zero_zero])),
    "Qubit(0, 1)",
    "X gate qapply",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()])),
    "sqrt(2)/2*Qubit(0) + sqrt(2)/2*Qubit(1)",
    "H gate qapply",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cnot_gate(1, 0).as_expr(), one_zero])),
    "Qubit(1, 1)",
    "CNOT qapply",
  )

  try! quantum_test_assert_matrix_equal(
    try! qubit_to_matrix((try! qubit("01")).as_expr(), nqubits=2),
    ["0", "1", "0", "0"],
    4,
    1,
    "qubit vector",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(x_gate(0).as_expr(), nqubits=1),
    ["0", "1", "1", "0"],
    2,
    2,
    "X gate matrix",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(cnot_gate(1, 0).as_expr(), nqubits=2),
    ["1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0", "1", "0", "0", "1", "0"],
    4,
    4,
    "CNOT matrix",
  )
  try! quantum_test_assert_expr_equal(
    try! matrix_to_qubit(try! represent_matrix(@symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]), nqubits=1)),
    "sqrt(2)/2*Qubit(0) + sqrt(2)/2*Qubit(1)",
    "matrix_to_qubit on H|0>",
  )
}

///|
test "physics.quantum.qubit/gate: controlled and simplification" {
  let one_zero = (try! qubit("10")).as_expr()
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cgate([1], x_gate(0).as_expr()), one_zero])),
    "Qubit(1, 1)",
    "controlled X via CGate",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(cphase(1, 0), nqubits=2),
    ["1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "-1"],
    4,
    4,
    "CPHASE matrix",
  )
  try! quantum_test_assert_expr_equal(
    gate_simp(@symcore.raw_mul([hadamard_gate(0).as_expr(), hadamard_gate(0).as_expr()])),
    "1",
    "H^2 simplification",
  )
  inspect(
    @symprint.to_string(gate_sort(@symcore.raw_mul([z_gate(1).as_expr(), x_gate(0).as_expr()]))),
    content="XGate(0)*ZGate(1)",
  )
}

///|
test "physics.quantum.qubit: measurement helpers" {
  let all_results = try! measure_all((try! qubit("1")).as_expr())
  inspect(quantum_measurements_to_expr_string(all_results), content="[(Qubit(1), 1)]")

  let partial_results = try! measure_partial((try! qubit("10")).as_expr(), [0])
  inspect(quantum_measurements_to_expr_string(partial_results), content="[(Qubit(1, 0), 1)]")

  let h_state = qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]))
  inspect(
    @symprint.to_string(try! measure_all_oneshot(h_state, sample=0.1)),
    content="Qubit(0)",
  )
  inspect(
    @symprint.to_string(try! measure_all_oneshot(h_state, sample=0.9)),
    content="Qubit(1)",
  )

  let partial_state = qapply(@symcore.raw_mul([hadamard_gate(1).as_expr(), (try! qubit("00")).as_expr()]))
  try! quantum_test_assert_expr_equal(
    try! measure_partial_oneshot(partial_state, [1], sample=0.1),
    "Qubit(0, 0)",
    "measure_partial_oneshot low sample",
  )
  try! quantum_test_assert_expr_equal(
    try! measure_partial_oneshot(partial_state, [1], sample=0.9),
    "Qubit(1, 0)",
    "measure_partial_oneshot high sample",
  )
}

///|
test "physics.quantum.gate: normalization and basis transforms" {
  normalized(false)
  inspect(
    @symprint.to_string(qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]))),
    content="Qubit(0) + Qubit(1)",
  )
  normalized(true)
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()])),
    "sqrt(2)/2*Qubit(0) + sqrt(2)/2*Qubit(1)",
    "normalized(true)",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! zx_basis_transform(),
    ["sqrt(2)/2", "sqrt(2)/2", "sqrt(2)/2", "-sqrt(2)/2"],
    2,
    2,
    "ZX basis transform",
  )
  try! quantum_test_assert_matrix_equal(
    try! zy_basis_transform(),
    ["I", "0", "0", "-1*I"],
    2,
    2,
    "ZY basis transform",
  )

  inspect(
    @symprint.to_string(try! random_circuit(4, 2, seed=7)),
    content="PhaseGate(1)*ZGate(0)*HadamardGate(1)*TGate(1)",
  )
}
