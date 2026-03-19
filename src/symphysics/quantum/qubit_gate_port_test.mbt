///|
test "physics.quantum.qubit/gate/represent: base parity" {
  let zero_zero = qubit("00").as_expr()
  let h0 = hadamard_gate(0).as_expr()
  let x0 = x_gate(0).as_expr()
  let cnot = cnot_gate(1, 0).as_expr()

  quantum_test_assert_string_equal(
    @sympy_physics.quantum_srepr_str(@symprint.to_string(qubit("01").as_expr())),
    @sympy_physics.quantum_srepr_str("Qubit(0, 1)"),
    "Qubit srepr parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_srepr_str(
      @symprint.to_string(int_qubit(5, 3).as_expr()),
    ),
    @sympy_physics.quantum_srepr_str("IntQubit(5)"),
    "IntQubit srepr parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([x0, zero_zero]))),
    ),
    @sympy_physics.quantum_qapply_str("XGate(0)*Qubit(0, 0)"),
    "X gate qapply parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([h0, qubit("0").as_expr()]))),
    ),
    @sympy_physics.quantum_qapply_str("HadamardGate(0)*Qubit(0)"),
    "H gate qapply parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cnot, qubit("10").as_expr()])),
      ),
    ),
    @sympy_physics.quantum_qapply_str("CNotGate(1,0)*Qubit(1, 0)"),
    "CNOT qapply parity",
  )
  quantum_test_assert_matrix_expr_equal(
    qubit_to_matrix(qubit("01").as_expr(), nqubits=2),
    @sympy_physics.physics_eval_matrix("represent(Qubit(0, 1), nqubits=2)"),
    4,
    1,
    "Qubit matrix parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(x0, nqubits=1),
    @sympy_physics.physics_eval_matrix("represent(XGate(0), nqubits=1)"),
    2,
    2,
    "X matrix parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(cnot, nqubits=2),
    @sympy_physics.physics_eval_matrix("represent(CNotGate(1,0), nqubits=2)"),
    4,
    4,
    "CNOT matrix parity",
  )
}

///|
test "physics.quantum.qubit/gate: controlled parity" {
  let cgx = cgate([1], x_gate(0).as_expr())
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(cphase(1, 0), nqubits=2),
    @sympy_physics.physics_eval_matrix("represent(CPHASE(1,0), nqubits=2)"),
    4,
    4,
    "CPHASE matrix parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_simp(
          @symcore.raw_mul([
            hadamard_gate(0).as_expr(),
            hadamard_gate(0).as_expr(),
          ]),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_simp(H(0)*H(0))"),
    "gate_simp parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cgx, qubit("10").as_expr()])),
      ),
    ),
    @sympy_physics.quantum_qapply_str("CGate((1,), XGate(0))*Qubit(1, 0)"),
    "CGate qapply parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_sort(@symcore.raw_mul([z_gate(0).as_expr(), x_gate(0).as_expr()])),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_sort(ZGate(0)*XGate(0))"),
    "gate_sort ZX parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_sort(
          @symcore.raw_mul([y_gate(0).as_expr(), hadamard_gate(0).as_expr()]),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_sort(YGate(0)*HadamardGate(0))"),
    "gate_sort YH parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_sort(
          @symcore.raw_mul([t_gate(0).as_expr(), phase_gate(0).as_expr()]),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_sort(TGate(0)*PhaseGate(0))"),
    "gate_sort TS parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_sort(
          @symcore.raw_mul([z_gate(0).as_expr(), cnot_gate(0, 1).as_expr()]),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_sort(ZGate(0)*CNotGate(0, 1))"),
    "gate_sort Z/CNOT parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_simp(
          @symcore.raw_add([
            @symcore.raw_pow(x_gate(0).as_expr(), @symcore.int(2)),
            @symcore.raw_pow(y_gate(0).as_expr(), @symcore.int(2)),
          ]),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_simp(XGate(0)**2 + YGate(0)**2)"),
    "gate_simp additive powers parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_simp(@symcore.raw_pow(phase_gate(4).as_expr(), @symcore.int(3))),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_simp(PhaseGate(4)**3)"),
    "gate_simp S^3 parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_simp(@symcore.raw_pow(t_gate(0).as_expr(), @symcore.int(6))),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_simp(TGate(0)**6)"),
    "gate_simp T^6 parity",
  )
}

///|
test "physics.quantum.gate: ugate parity" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = @symcore.symbol("c")
  let d = @symcore.symbol("d")
  let umat = @symphysics.explicit_matrix_from_rows([[a, b], [c, d]])
  let u0 = u_gate_single(0, umat)
  let u1 = u_gate_single(1, umat)
  let cu0 = cgate([1], u0)

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(u0, nqubits=1),
    @sympy_physics.physics_eval_matrix(
      "represent(UGate((0,), Matrix([[a, b], [c, d]])), nqubits=1)",
    ),
    2,
    2,
    "UGate 1-qubit matrix parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([u0, qubit("0").as_expr()]))),
    ),
    @sympy_physics.quantum_qapply_str(
      "UGate((0,), Matrix([[a, b], [c, d]]))*Qubit(0)",
    ),
    "UGate qapply |0> parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(u1, nqubits=2),
    @sympy_physics.physics_eval_matrix(
      "represent(UGate((1,), Matrix([[a, b], [c, d]])), nqubits=2)",
    ),
    4,
    4,
    "UGate embedded matrix parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(cu0, nqubits=2),
    @sympy_physics.physics_eval_matrix(
      "represent(CGate((1,), UGate((0,), Matrix([[a, b], [c, d]]))), nqubits=2)",
    ),
    4,
    4,
    "controlled UGate matrix parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cu0, qubit("10").as_expr()])),
      ),
    ),
    @sympy_physics.quantum_qapply_str(
      "CGate((1,), UGate((0,), Matrix([[a, b], [c, d]])))*Qubit(1, 0)",
    ),
    "controlled UGate qapply parity",
  )

  let v = @symcore.symbol("v")
  let w = @symcore.symbol("w")
  let f = @symcore.symbol("f")
  let g = @symcore.symbol("g")
  let uadd = u_gate_single(
    0,
    @symphysics.explicit_matrix_from_rows([[v, w], [f, g]]),
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(x_gate(0).as_expr() + uadd, nqubits=2),
    @sympy_physics.physics_eval_matrix(
      "represent(XGate(0) + UGate((0,), ImmutableDenseMatrix([[v, w], [f, g]])), nqubits=2)",
    ),
    4,
    4,
    "X + UGate matrix parity",
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
  let cu2 = cgate([2], u2)
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([u2, qubit("00").as_expr()]))),
    ),
    @sympy_physics.quantum_qapply_str(
      "UGate((1, 0), Matrix([[0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 0, 1], [0, 0, -1, 0]]))*Qubit(0, 0)",
    ),
    "two-target UGate qapply parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([u2, qubit("11").as_expr()]))),
    ),
    @sympy_physics.quantum_qapply_str(
      "UGate((1, 0), Matrix([[0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 0, 1], [0, 0, -1, 0]]))*Qubit(1, 1)",
    ),
    "two-target UGate qapply parity on |11>",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cu2, qubit("100").as_expr()])),
      ),
    ),
    @sympy_physics.quantum_qapply_str(
      "CGate((2,), UGate((1, 0), Matrix([[0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 0, 1], [0, 0, -1, 0]])))*Qubit(1, 0, 0)",
    ),
    "controlled two-target UGate qapply parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cu2, qubit("000").as_expr()])),
      ),
    ),
    @sympy_physics.quantum_qapply_str(
      "CGate((2,), UGate((1, 0), Matrix([[0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 0, 1], [0, 0, -1, 0]])))*Qubit(0, 0, 0)",
    ),
    "controlled two-target UGate inactive parity",
  )
}

///|
test "physics.quantum.gate: decomposition parity" {
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(gate_decompose(cgate([1], y_gate(0).as_expr())), nqubits=2),
    @sympy_physics.physics_eval_matrix(
      "represent(CGate((1,), YGate(0)).decompose(), nqubits=2)",
    ),
    4,
    4,
    "CY decompose parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(gate_decompose(cgate([0], z_gate(1).as_expr())), nqubits=2),
    @sympy_physics.physics_eval_matrix(
      "represent(CGate((0,), ZGate(1)).decompose(), nqubits=2)",
    ),
    4,
    4,
    "CZ decompose parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(gate_decompose(swap_gate(1, 0).as_expr()), nqubits=2),
    @sympy_physics.physics_eval_matrix(
      "represent(SwapGate(1, 0).decompose(), nqubits=2)",
    ),
    4,
    4,
    "SWAP decompose parity",
  )
}

///|
test "physics.quantum.qubit: measurement parity" {
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      quantum_measurements_to_expr_string(measure_all(qubit("1").as_expr())),
    ),
    @sympy_physics.quantum_eval_str("measure_all(Qubit(1))"),
    "measure_all parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      quantum_measurements_to_expr_string(
        measure_partial(qubit("10").as_expr(), [0]),
      ),
    ),
    @sympy_physics.quantum_eval_str("measure_partial(Qubit(1, 0), (0,))"),
    "measure_partial parity",
  )

  let h_state = @symprint.to_string(
    qapply(@symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()])),
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        measure_all_oneshot(
          qapply(
            @symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()]),
          ),
          sample=0.1,
        ),
      ),
    ),
    @sympy_physics.quantum_measure_all_oneshot_str(h_state, 0.1),
    "measure_all_oneshot parity",
  )

  let partial_state = @symprint.to_string(
    qapply(
      @symcore.raw_mul([hadamard_gate(1).as_expr(), qubit("00").as_expr()]),
    ),
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        measure_partial_oneshot(
          qapply(
            @symcore.raw_mul([hadamard_gate(1).as_expr(), qubit("00").as_expr()]),
          ),
          [1],
          sample=0.9,
        ),
      ),
    ),
    @sympy_physics.quantum_measure_partial_oneshot_str(partial_state, [1], 0.9),
    "measure_partial_oneshot parity",
  )
}

///|
test "physics.quantum.gate: normalization and basis-transform parity" {
  normalized(false)
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([hadamard_gate(0).as_expr(), qubit("0").as_expr()]),
        ),
      ),
    ),
    @sympy_physics.quantum_hadamard_normalized_qapply(
      false, "HadamardGate(0)*Qubit(0)",
    ),
    "normalized(false) parity",
  )
  normalized(true)

  quantum_test_assert_matrix_expr_equal(
    zx_basis_transform(),
    @sympy_physics.quantum_matrixcache_matrix("ZX"),
    2,
    2,
    "ZX basis transform parity",
  )
  quantum_test_assert_matrix_expr_equal(
    zy_basis_transform(),
    @sympy_physics.quantum_matrixcache_matrix("ZY"),
    2,
    2,
    "ZY basis transform parity",
  )
}
