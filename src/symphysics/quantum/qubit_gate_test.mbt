///|
test "physics.quantum.qubit: core state helpers" {
  let q = try! qubit("0101")
  inspect(q.to_string(), content="|0101>")
  inspect(
    q.repr(),
    content="Qubit(Integer(0),Integer(1),Integer(0),Integer(1))",
  )
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
    qapply(
      @symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]),
    ),
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
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0", "1", "0", "0", "1",
      "0",
    ],
    4,
    4,
    "CNOT matrix",
  )
  try! quantum_test_assert_expr_equal(
    try! matrix_to_qubit(
      try! represent_matrix(
        @symcore.raw_mul([
          hadamard_gate(0).as_expr(),
          (try! qubit("0")).as_expr(),
        ]),
        nqubits=1,
      ),
    ),
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
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "1", "0", "0", "0", "0",
      "-1",
    ],
    4,
    4,
    "CPHASE matrix",
  )
  try! quantum_test_assert_expr_equal(
    gate_simp(
      @symcore.raw_mul([hadamard_gate(0).as_expr(), hadamard_gate(0).as_expr()]),
    ),
    "1",
    "H^2 simplification",
  )
  inspect(
    @symprint.to_string(
      gate_sort(@symcore.raw_mul([z_gate(1).as_expr(), x_gate(0).as_expr()])),
    ),
    content="XGate(0)*ZGate(1)",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(@symcore.raw_mul([z_gate(0).as_expr(), x_gate(0).as_expr()])),
    ),
    "-1*XGate(0)*ZGate(0)",
    "gate_sort ZX anticommute",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(@symcore.raw_mul([y_gate(0).as_expr(), hadamard_gate(0).as_expr()])),
    ),
    "-1*HadamardGate(0)*YGate(0)",
    "gate_sort YH anticommute",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(@symcore.raw_mul([t_gate(0).as_expr(), phase_gate(0).as_expr()])),
    ),
    "PhaseGate(0)*TGate(0)",
    "gate_sort TS commute",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(@symcore.raw_mul([z_gate(0).as_expr(), cnot_gate(0, 1).as_expr()])),
    ),
    "CNotGate(0, 1)*ZGate(0)",
    "gate_sort Z and CNOT",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_simp(
        @symcore.raw_add([
          @symcore.raw_pow(x_gate(0).as_expr(), @symcore.int(2)),
          @symcore.raw_pow(y_gate(0).as_expr(), @symcore.int(2)),
        ]),
      ),
    ),
    "2",
    "gate_simp additive powers",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_simp(
        @symcore.raw_pow(phase_gate(4).as_expr(), @symcore.int(3)),
      ),
    ),
    "PhaseGate(4)*ZGate(4)",
    "gate_simp S^3",
  )
  try! quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_simp(
        @symcore.raw_pow(t_gate(0).as_expr(), @symcore.int(6)),
      ),
    ),
    "PhaseGate(0)*ZGate(0)",
    "gate_simp T^6",
  )
}

///|
test "physics.quantum.gate: ugate and controlled ugate" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = @symcore.symbol("c")
  let d = @symcore.symbol("d")
  let umat = try! @symphysics.explicit_matrix_from_rows([[a, b], [c, d]])
  let u0 = try! u_gate_single(0, umat)

  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u0, (try! qubit("0")).as_expr()])),
    "a*Qubit(0) + c*Qubit(1)",
    "UGate qapply on |0>",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u0, (try! qubit("1")).as_expr()])),
    "b*Qubit(0) + d*Qubit(1)",
    "UGate qapply on |1>",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(u0, nqubits=1),
    ["a", "b", "c", "d"],
    2,
    2,
    "UGate matrix in 1-qubit space",
  )

  let u1 = try! u_gate_single(1, umat)
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, (try! qubit("00")).as_expr()])),
    "a*Qubit(0, 0) + c*Qubit(1, 0)",
    "UGate larger-space qapply on |00>",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, (try! qubit("01")).as_expr()])),
    "a*Qubit(0, 1) + c*Qubit(1, 1)",
    "UGate larger-space qapply on |01>",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, (try! qubit("10")).as_expr()])),
    "b*Qubit(0, 0) + d*Qubit(1, 0)",
    "UGate larger-space qapply on |10>",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, (try! qubit("11")).as_expr()])),
    "b*Qubit(0, 1) + d*Qubit(1, 1)",
    "UGate larger-space qapply on |11>",
  )

  let cu0 = cgate([1], u0)
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cu0, (try! qubit("10")).as_expr()])),
    "a*Qubit(1, 0) + c*Qubit(1, 1)",
    "controlled UGate on |10>",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cu0, (try! qubit("11")).as_expr()])),
    "b*Qubit(1, 0) + d*Qubit(1, 1)",
    "controlled UGate on |11>",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cu0, (try! qubit("01")).as_expr()])),
    "Qubit(0, 1)",
    "controlled UGate inactive on |01>",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(cu0, nqubits=2),
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "a", "b", "0", "0", "c",
      "d",
    ],
    4,
    4,
    "controlled UGate matrix",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(u1, nqubits=2),
    [
      "a", "0", "b", "0", "0", "a", "0", "b", "c", "0", "d", "0", "0", "c", "0",
      "d",
    ],
    4,
    4,
    "UGate embedded matrix",
  )

  let v = @symcore.symbol("v")
  let w = @symcore.symbol("w")
  let f = @symcore.symbol("f")
  let g = @symcore.symbol("g")
  let uadd = try! u_gate_single(
    0,
    try! @symphysics.explicit_matrix_from_rows([[v, w], [f, g]]),
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(x_gate(0).as_expr() + uadd, nqubits=2),
    [
      "v", "w + 1", "0", "0", "f + 1", "g", "0", "0", "0", "0", "v", "w + 1", "0",
      "0", "f + 1", "g",
    ],
    4,
    4,
    "X + UGate matrix addition",
  )

  let u2 = try! u_gate(
    [1, 0],
    try! @symphysics.explicit_matrix_from_rows([
      [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(-1), @symcore.int(0)],
    ]),
  )
  inspect(
    @symprint.to_string(
      qapply(@symcore.raw_mul([u2, (try! qubit("00")).as_expr()])),
    ),
    content="Qubit(1, 0)",
  )
  inspect(
    @symprint.to_string(
      qapply(@symcore.raw_mul([u2, (try! qubit("11")).as_expr()])),
    ),
    content="Qubit(0, 1)",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(u2, nqubits=2),
    [
      "0", "0", "1", "0", "0", "0", "0", "1", "1", "0", "0", "0", "0", "-1", "0",
      "0",
    ],
    4,
    4,
    "two-target UGate matrix",
  )
  try! quantum_test_assert_matrix_equal(
    try! represent_matrix(cgate([2], u2), nqubits=3),
    [
      "1", "0", "0", "0", "0", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0",
      "0", "0", "0", "1", "0", "0", "0", "0", "0", "0", "0", "0", "1", "0", "0",
      "0", "0", "0", "0", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0", "0",
      "0", "0", "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0", "0", "0",
      "0", "-1", "0", "0",
    ],
    8,
    8,
    "controlled two-target UGate matrix",
  )
}

///|
test "physics.quantum.gate: decomposition helpers" {
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      gate_decompose(cgate([1], y_gate(0).as_expr())),
      nqubits=2,
    ),
    try! matrix_flat_strings(
      try! represent_matrix(cgate([1], y_gate(0).as_expr()), nqubits=2),
    ),
    4,
    4,
    "CY decomposition",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      gate_decompose(cgate([0], z_gate(1).as_expr())),
      nqubits=2,
    ),
    try! matrix_flat_strings(
      try! represent_matrix(cgate([0], z_gate(1).as_expr()), nqubits=2),
    ),
    4,
    4,
    "CZ decomposition",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(gate_decompose(swap_gate(1, 0).as_expr()), nqubits=2),
    try! matrix_flat_strings(
      try! represent_matrix(swap_gate(1, 0).as_expr(), nqubits=2),
    ),
    4,
    4,
    "SWAP decomposition",
  )
}

///|
test "physics.quantum.qubit: measurement helpers" {
  let all_results = try! measure_all((try! qubit("1")).as_expr())
  inspect(
    quantum_measurements_to_expr_string(all_results),
    content="[(Qubit(1), 1)]",
  )

  let partial_results = try! measure_partial((try! qubit("10")).as_expr(), [0])
  inspect(
    quantum_measurements_to_expr_string(partial_results),
    content="[(Qubit(1, 0), 1)]",
  )

  let h_state = qapply(
    @symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]),
  )
  inspect(
    @symprint.to_string(try! measure_all_oneshot(h_state, sample=0.1)),
    content="Qubit(0)",
  )
  inspect(
    @symprint.to_string(try! measure_all_oneshot(h_state, sample=0.9)),
    content="Qubit(1)",
  )

  let partial_state = qapply(
    @symcore.raw_mul([hadamard_gate(1).as_expr(), (try! qubit("00")).as_expr()]),
  )
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
    @symprint.to_string(
      qapply(
        @symcore.raw_mul([
          hadamard_gate(0).as_expr(),
          (try! qubit("0")).as_expr(),
        ]),
      ),
    ),
    content="Qubit(0) + Qubit(1)",
  )
  normalized(true)
  try! quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]),
    ),
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
