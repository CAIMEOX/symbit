///|
test "physics.quantum.qubit/gate/represent: base parity" {
  let zero_zero = (try! qubit("00")).as_expr()
  let h0 = hadamard_gate(0).as_expr()
  let x0 = x_gate(0).as_expr()
  let cnot = cnot_gate(1, 0).as_expr()

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_srepr_str(
      @symprint.to_string((try! qubit("01")).as_expr()),
    ),
    try! @sympy_physics.quantum_srepr_str("Qubit(0, 1)"),
    "Qubit srepr parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_srepr_str(
      @symprint.to_string((try! int_qubit(5, 3)).as_expr()),
    ),
    try! @sympy_physics.quantum_srepr_str("IntQubit(5)"),
    "IntQubit srepr parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(qapply(@symcore.raw_mul([x0, zero_zero]))),
    ),
    try! @sympy_physics.quantum_qapply_str("XGate(0)*Qubit(0, 0)"),
    "X gate qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([h0, (try! qubit("0")).as_expr()])),
      ),
    ),
    try! @sympy_physics.quantum_qapply_str("HadamardGate(0)*Qubit(0)"),
    "H gate qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cnot, (try! qubit("10")).as_expr()])),
      ),
    ),
    try! @sympy_physics.quantum_qapply_str("CNotGate(1,0)*Qubit(1, 0)"),
    "CNOT qapply parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! qubit_to_matrix((try! qubit("01")).as_expr(), nqubits=2),
    try! @sympy_physics.physics_eval_matrix("represent(Qubit(0, 1), nqubits=2)"),
    4,
    1,
    "Qubit matrix parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(x0, nqubits=1),
    try! @sympy_physics.physics_eval_matrix("represent(XGate(0), nqubits=1)"),
    2,
    2,
    "X matrix parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(cnot, nqubits=2),
    try! @sympy_physics.physics_eval_matrix(
      "represent(CNotGate(1,0), nqubits=2)",
    ),
    4,
    4,
    "CNOT matrix parity",
  )
}

///|
test "physics.quantum.qubit/gate: controlled parity" {
  let cgx = cgate([1], x_gate(0).as_expr())
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(cphase(1, 0), nqubits=2),
    try! @sympy_physics.physics_eval_matrix("represent(CPHASE(1,0), nqubits=2)"),
    4,
    4,
    "CPHASE matrix parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        gate_simp(
          @symcore.raw_mul([
            hadamard_gate(0).as_expr(),
            hadamard_gate(0).as_expr(),
          ]),
        ),
      ),
    ),
    try! @sympy_physics.quantum_eval_str("gate_simp(H(0)*H(0))"),
    "gate_simp parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cgx, (try! qubit("10")).as_expr()])),
      ),
    ),
    try! @sympy_physics.quantum_qapply_str("CGate((1,), XGate(0))*Qubit(1, 0)"),
    "CGate qapply parity",
  )
}

///|
test "physics.quantum.gate: ugate parity" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = @symcore.symbol("c")
  let d = @symcore.symbol("d")
  let umat = try! @symphysics.explicit_matrix_from_rows([[a, b], [c, d]])
  let u0 = try! u_gate_single(0, umat)
  let u1 = try! u_gate_single(1, umat)
  let cu0 = cgate([1], u0)

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(u0, nqubits=1),
    try! @sympy_physics.physics_eval_matrix(
      "represent(UGate((0,), Matrix([[a, b], [c, d]])), nqubits=1)",
    ),
    2,
    2,
    "UGate 1-qubit matrix parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([u0, (try! qubit("0")).as_expr()])),
      ),
    ),
    try! @sympy_physics.quantum_qapply_str(
      "UGate((0,), Matrix([[a, b], [c, d]]))*Qubit(0)",
    ),
    "UGate qapply |0> parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(u1, nqubits=2),
    try! @sympy_physics.physics_eval_matrix(
      "represent(UGate((1,), Matrix([[a, b], [c, d]])), nqubits=2)",
    ),
    4,
    4,
    "UGate embedded matrix parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(cu0, nqubits=2),
    try! @sympy_physics.physics_eval_matrix(
      "represent(CGate((1,), UGate((0,), Matrix([[a, b], [c, d]]))), nqubits=2)",
    ),
    4,
    4,
    "controlled UGate matrix parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([cu0, (try! qubit("10")).as_expr()])),
      ),
    ),
    try! @sympy_physics.quantum_qapply_str(
      "CGate((1,), UGate((0,), Matrix([[a, b], [c, d]])))*Qubit(1, 0)",
    ),
    "controlled UGate qapply parity",
  )

  let v = @symcore.symbol("v")
  let w = @symcore.symbol("w")
  let f = @symcore.symbol("f")
  let g = @symcore.symbol("g")
  let uadd = try! u_gate_single(
    0,
    try! @symphysics.explicit_matrix_from_rows([[v, w], [f, g]]),
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(x_gate(0).as_expr() + uadd, nqubits=2),
    try! @sympy_physics.physics_eval_matrix(
      "represent(XGate(0) + UGate((0,), ImmutableDenseMatrix([[v, w], [f, g]])), nqubits=2)",
    ),
    4,
    4,
    "X + UGate matrix parity",
  )
}

///|
test "physics.quantum.qubit: measurement parity" {
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      quantum_measurements_to_expr_string(
        try! measure_all((try! qubit("1")).as_expr()),
      ),
    ),
    try! @sympy_physics.quantum_eval_str("measure_all(Qubit(1))"),
    "measure_all parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      quantum_measurements_to_expr_string(
        try! measure_partial((try! qubit("10")).as_expr(), [0]),
      ),
    ),
    try! @sympy_physics.quantum_eval_str("measure_partial(Qubit(1, 0), (0,))"),
    "measure_partial parity",
  )

  let h_state = @symprint.to_string(
    qapply(
      @symcore.raw_mul([hadamard_gate(0).as_expr(), (try! qubit("0")).as_expr()]),
    ),
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        try! measure_all_oneshot(
          qapply(
            @symcore.raw_mul([
              hadamard_gate(0).as_expr(),
              (try! qubit("0")).as_expr(),
            ]),
          ),
          sample=0.1,
        ),
      ),
    ),
    try! @sympy_physics.quantum_measure_all_oneshot_str(h_state, 0.1),
    "measure_all_oneshot parity",
  )

  let partial_state = @symprint.to_string(
    qapply(
      @symcore.raw_mul([
        hadamard_gate(1).as_expr(),
        (try! qubit("00")).as_expr(),
      ]),
    ),
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        try! measure_partial_oneshot(
          qapply(
            @symcore.raw_mul([
              hadamard_gate(1).as_expr(),
              (try! qubit("00")).as_expr(),
            ]),
          ),
          [1],
          sample=0.9,
        ),
      ),
    ),
    try! @sympy_physics.quantum_measure_partial_oneshot_str(
      partial_state,
      [1],
      0.9,
    ),
    "measure_partial_oneshot parity",
  )
}

///|
test "physics.quantum.gate: normalization and basis-transform parity" {
  normalized(false)
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([
            hadamard_gate(0).as_expr(),
            (try! qubit("0")).as_expr(),
          ]),
        ),
      ),
    ),
    try! @sympy_physics.quantum_hadamard_normalized_qapply(
      false, "HadamardGate(0)*Qubit(0)",
    ),
    "normalized(false) parity",
  )
  normalized(true)

  try! quantum_test_assert_matrix_expr_equal(
    try! zx_basis_transform(),
    try! @sympy_physics.quantum_matrixcache_matrix("ZX"),
    2,
    2,
    "ZX basis transform parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! zy_basis_transform(),
    try! @sympy_physics.quantum_matrixcache_matrix("ZY"),
    2,
    2,
    "ZY basis transform parity",
  )
}
