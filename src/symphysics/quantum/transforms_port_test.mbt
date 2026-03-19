///|
test "physics.quantum.transforms: parity" {
  let k1 = ket([@symcore.symbol("k1")]).as_expr()
  let k2 = ket([@symcore.symbol("k2")]).as_expr()
  let b1 = bra([@symcore.symbol("k1")]).as_expr()
  let a = operator([@symcore.symbol("A")]).as_expr()
  let b = operator([@symcore.symbol("B")]).as_expr()
  let c = operator([@symcore.symbol("C")]).as_expr()

  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(quantum_canonical_mul(@symcore.raw_mul([b1, k1]))),
    ),
    @sympy_physics.quantum_eval_str("Bra(k1)*Ket(k1)"),
    "bra*ket parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(quantum_canonical_mul(@symcore.raw_mul([k1, b1]))),
    ),
    @sympy_physics.quantum_eval_str("Ket(k1)*Bra(k1)"),
    "ket*bra parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_mul(
          @symcore.raw_mul([
            @symcore.raw_function("TensorProduct", [a, b]),
            @symcore.raw_function("TensorProduct", [k1, k2]),
          ]),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "TensorProduct(Operator(A), Operator(B))*TensorProduct(Ket(k1), Ket(k2))",
    ),
    "tensor product parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_mul(@symcore.raw_mul([a, @symcore.raw_add([b, c])])),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "expand(Operator(A)*(Operator(B) + Operator(C)))",
    ),
    "operator left distribution parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_pow(@symcore.raw_add([a, b]), @symcore.int(2)),
      ),
    ),
    @sympy_physics.quantum_eval_str("expand((Operator(A) + Operator(B))**2)"),
    "operator square parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_pow(x_gate(0).as_expr(), @symcore.int(2)),
      ),
    ),
    @sympy_physics.quantum_eval_str("XGate(0)**2"),
    "gate involution power parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_pow(phase_gate(0).as_expr(), @symcore.int(2)),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_simp(PhaseGate(0)*PhaseGate(0))"),
    "phase power parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_pow(t_gate(0).as_expr(), @symcore.int(2)),
      ),
    ),
    @sympy_physics.quantum_eval_str("gate_simp(TGate(0)*TGate(0))"),
    "t power parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_pow(cgate([1], x_gate(0).as_expr()), @symcore.int(2)),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "gate_simp(CGate((1,), XGate(0))*CGate((1,), XGate(0)))",
    ),
    "controlled involution power parity",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        quantum_canonical_pow(
          fermion_op(@symcore.symbol("c")).as_expr(),
          @symcore.int(2),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str("FermionOp(c)**2"),
    "fermion power parity",
  )
}
