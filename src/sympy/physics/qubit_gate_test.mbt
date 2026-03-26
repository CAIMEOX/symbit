///|
test "physics.quantum.qubit: core state helpers" {
  let q = qubit("0101")
  inspect(q.to_string(), content="|0101>")
  inspect(
    q.repr(),
    content="Qubit(Integer(0),Integer(1),Integer(0),Integer(1))",
  )
  inspect(q.flip(1).to_string(), content="|0111>")
  inspect(q.dual().to_string(), content="<0101|")
  inspect(q.nqubits().to_string(), content="4")
  inspect(q.dimension().to_string(), content="4")

  let iq = int_qubit(5, 3)
  inspect(iq.to_string(), content="|5>")
  inspect(iq.repr(), content="IntQubit(Integer(5))")
  inspect(@symprint.to_string(iq.as_expr()), content="IntQubit(5)")
}

///|
test "physics.quantum.qubit/gate/represent: local actions" {
  let zero_zero = qubit("00").as_expr()
  let one_zero = qubit("10").as_expr()

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([x_gate(0).as_expr(), zero_zero])),
    "Qubit(0, 1)",
    "X gate qapply",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()])),
    "sqrt(2)/2*Qubit(0) + sqrt(2)/2*Qubit(1)",
    "H gate qapply",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cnot_gate(1, 0).as_expr(), one_zero])),
    "Qubit(1, 1)",
    "CNOT qapply",
  )

  quantum_test_assert_matrix_equal(
    qubit_to_matrix(qubit("01").as_expr(), nqubits=2),
    ["0", "1", "0", "0"],
    4,
    1,
    "qubit vector",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(x_gate(0).as_expr(), nqubits=1),
    ["0", "1", "1", "0"],
    2,
    2,
    "X gate matrix",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(cnot_gate(1, 0).as_expr(), nqubits=2),
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "0", "1", "0", "0", "1",
      "0",
    ],
    4,
    4,
    "CNOT matrix",
  )
  quantum_test_assert_expr_equal(
    matrix_to_qubit(
      represent_matrix(
        @symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()]),
        nqubits=1,
      ),
    ),
    "sqrt(2)/2*Qubit(0) + sqrt(2)/2*Qubit(1)",
    "matrix_to_qubit on H|0>",
  )
}

///|
test "physics.quantum.qubit/gate: controlled and simplification" {
  let one_zero = qubit("10").as_expr()
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cgate([1], x_gate(0).as_expr()), one_zero])),
    "Qubit(1, 1)",
    "controlled X via CGate",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(cphase(1, 0), nqubits=2),
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "1", "0", "0", "0", "0",
      "-1",
    ],
    4,
    4,
    "CPHASE matrix",
  )
  quantum_test_assert_expr_equal(
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
  quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(@symcore.raw_mul([z_gate(0).as_expr(), x_gate(0).as_expr()])),
    ),
    "-1*XGate(0)*ZGate(0)",
    "gate_sort ZX anticommute",
  )
  quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(
        @symcore.raw_mul([y_gate(0).as_expr(), hadamard_gate(0).as_expr()]),
      ),
    ),
    "-1*HadamardGate(0)*YGate(0)",
    "gate_sort YH anticommute",
  )
  quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(
        @symcore.raw_mul([t_gate(0).as_expr(), phase_gate(0).as_expr()]),
      ),
    ),
    "PhaseGate(0)*TGate(0)",
    "gate_sort TS commute",
  )
  quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_sort(
        @symcore.raw_mul([z_gate(0).as_expr(), cnot_gate(0, 1).as_expr()]),
      ),
    ),
    "CNotGate(0, 1)*ZGate(0)",
    "gate_sort Z and CNOT",
  )
  quantum_test_assert_string_equal(
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
  quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_simp(@symcore.raw_pow(phase_gate(4).as_expr(), @symcore.int(3))),
    ),
    "PhaseGate(4)*ZGate(4)",
    "gate_simp S^3",
  )
  quantum_test_assert_string_equal(
    @symprint.to_string(
      gate_simp(@symcore.raw_pow(t_gate(0).as_expr(), @symcore.int(6))),
    ),
    "PhaseGate(0)*ZGate(0)",
    "gate_simp T^6",
  )
}

///|
test "physics.quantum.gate: ugate and controlled ugate" {
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let d = @symcore.Expr::Symbol("d")
  let umat = @symphysics.explicit_matrix_from_rows([[a, b], [c, d]])
  let u0 = u_gate_single(0, umat)

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u0, qubit("0").as_expr()])),
    "a*Qubit(0) + c*Qubit(1)",
    "UGate qapply on |0>",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u0, qubit("1").as_expr()])),
    "b*Qubit(0) + d*Qubit(1)",
    "UGate qapply on |1>",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(u0, nqubits=1),
    ["a", "b", "c", "d"],
    2,
    2,
    "UGate matrix in 1-qubit space",
  )

  let u1 = u_gate_single(1, umat)
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, qubit("00").as_expr()])),
    "a*Qubit(0, 0) + c*Qubit(1, 0)",
    "UGate larger-space qapply on |00>",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, qubit("01").as_expr()])),
    "a*Qubit(0, 1) + c*Qubit(1, 1)",
    "UGate larger-space qapply on |01>",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, qubit("10").as_expr()])),
    "b*Qubit(0, 0) + d*Qubit(1, 0)",
    "UGate larger-space qapply on |10>",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([u1, qubit("11").as_expr()])),
    "b*Qubit(0, 1) + d*Qubit(1, 1)",
    "UGate larger-space qapply on |11>",
  )

  let cu0 = cgate([1], u0)
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cu0, qubit("10").as_expr()])),
    "a*Qubit(1, 0) + c*Qubit(1, 1)",
    "controlled UGate on |10>",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cu0, qubit("11").as_expr()])),
    "b*Qubit(1, 0) + d*Qubit(1, 1)",
    "controlled UGate on |11>",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([cu0, qubit("01").as_expr()])),
    "Qubit(0, 1)",
    "controlled UGate inactive on |01>",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(cu0, nqubits=2),
    [
      "1", "0", "0", "0", "0", "1", "0", "0", "0", "0", "a", "b", "0", "0", "c",
      "d",
    ],
    4,
    4,
    "controlled UGate matrix",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(u1, nqubits=2),
    [
      "a", "0", "b", "0", "0", "a", "0", "b", "c", "0", "d", "0", "0", "c", "0",
      "d",
    ],
    4,
    4,
    "UGate embedded matrix",
  )

  let v = @symcore.Expr::Symbol("v")
  let w = @symcore.Expr::Symbol("w")
  let f = @symcore.Expr::Symbol("f")
  let g = @symcore.Expr::Symbol("g")
  let uadd = u_gate_single(
    0,
    @symphysics.explicit_matrix_from_rows([[v, w], [f, g]]),
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(x_gate(0).as_expr() + uadd, nqubits=2),
    [
      "v", "w + 1", "0", "0", "f + 1", "g", "0", "0", "0", "0", "v", "w + 1", "0",
      "0", "f + 1", "g",
    ],
    4,
    4,
    "X + UGate matrix addition",
  )

  let u2 = u_gate(
    [1, 0],
    @symphysics.explicit_matrix_from_rows([
      [@symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(0)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(0), @symcore.int(1)],
      [@symcore.int(0), @symcore.int(0), @symcore.int(-1), @symcore.int(0)],
    ]),
  )
  inspect(
    @symprint.to_string(qapply(@symcore.raw_mul([u2, qubit("00").as_expr()]))),
    content="Qubit(1, 0)",
  )
  inspect(
    @symprint.to_string(qapply(@symcore.raw_mul([u2, qubit("11").as_expr()]))),
    content="Qubit(0, 1)",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(u2, nqubits=2),
    [
      "0", "0", "1", "0", "0", "0", "0", "1", "1", "0", "0", "0", "0", "-1", "0",
      "0",
    ],
    4,
    4,
    "two-target UGate matrix",
  )
  quantum_test_assert_matrix_equal(
    represent_matrix(cgate([2], u2), nqubits=3),
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
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(gate_decompose(cgate([1], y_gate(0).as_expr())), nqubits=2),
    matrix_flat_strings(
      represent_matrix(cgate([1], y_gate(0).as_expr()), nqubits=2),
    ),
    4,
    4,
    "CY decomposition",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(gate_decompose(cgate([0], z_gate(1).as_expr())), nqubits=2),
    matrix_flat_strings(
      represent_matrix(cgate([0], z_gate(1).as_expr()), nqubits=2),
    ),
    4,
    4,
    "CZ decomposition",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(gate_decompose(swap_gate(1, 0).as_expr()), nqubits=2),
    matrix_flat_strings(represent_matrix(swap_gate(1, 0).as_expr(), nqubits=2)),
    4,
    4,
    "SWAP decomposition",
  )
}

///|
test "physics.quantum.qubit: measurement helpers" {
  let all_results = measure_all(qubit("1").as_expr())
  inspect(
    quantum_measurements_to_expr_string(all_results),
    content="[(Qubit(1), 1)]",
  )

  let partial_results = measure_partial(qubit("10").as_expr(), [0])
  inspect(
    quantum_measurements_to_expr_string(partial_results),
    content="[(Qubit(1, 0), 1)]",
  )

  let h_state = qapply(
    @symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()]),
  )
  inspect(
    @symprint.to_string(measure_all_oneshot(h_state, sample=0.1)),
    content="Qubit(0)",
  )
  inspect(
    @symprint.to_string(measure_all_oneshot(h_state, sample=0.9)),
    content="Qubit(1)",
  )

  let partial_state = qapply(
    @symcore.raw_mul([hadamard_gate(1).as_expr(), qubit("00").as_expr()]),
  )
  quantum_test_assert_expr_equal(
    measure_partial_oneshot(partial_state, [1], sample=0.1),
    "Qubit(0, 0)",
    "measure_partial_oneshot low sample",
  )
  quantum_test_assert_expr_equal(
    measure_partial_oneshot(partial_state, [1], sample=0.9),
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
        @symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()]),
      ),
    ),
    content="Qubit(0) + Qubit(1)",
  )
  normalized(true)
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()])),
    "sqrt(2)/2*Qubit(0) + sqrt(2)/2*Qubit(1)",
    "normalized(true)",
  )

  quantum_test_assert_matrix_expr_equal(
    zx_basis_transform(),
    ["sqrt(2)/2", "sqrt(2)/2", "sqrt(2)/2", "-sqrt(2)/2"],
    2,
    2,
    "ZX basis transform",
  )
  quantum_test_assert_matrix_equal(
    zy_basis_transform(),
    ["I", "0", "0", "-1*I"],
    2,
    2,
    "ZY basis transform",
  )

  inspect(
    @symprint.to_string(random_circuit(4, 2, seed=7)),
    content="PhaseGate(1)*ZGate(0)*HadamardGate(1)*TGate(1)",
  )
}
