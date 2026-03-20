///|
test "physics.quantum.commutator: parity" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")
  let c_op = @symcore.symbol("C")

  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(commutator(b_op, a_op))),
    quantum_eval_str("Commutator(B, A)"),
    "commutator canonical parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        commutator(@symcore.raw_mul([a, a_op]), @symcore.raw_mul([b, b_op])),
      ),
    ),
    quantum_eval_str("Commutator(a*A, b*B)"),
    "commutator scalar factor parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        commutator_expand(
          commutator(@symcore.raw_mul([a_op, b_op]), c_op, evaluate=false),
        ),
      ),
    ),
    quantum_expand_commutator_str("Commutator(A*B, C)"),
    "commutator expand parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(anticommutator(b_op, a_op)),
    ),
    quantum_eval_str("AntiCommutator(B, A)"),
    "anticommutator parity",
  )
}

///|
test "physics.quantum.(anti)commutator: gate parity" {
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(commutator(x_gate(0).as_expr(), y_gate(1).as_expr())),
    ),
    quantum_doit_str("Commutator(XGate(0), YGate(1))"),
    "disjoint one-qubit commutator parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        commutator(cnot_gate(0, 1).as_expr(), z_gate(0).as_expr()),
      ),
    ),
    quantum_doit_str("Commutator(CNotGate(0, 1), ZGate(0))"),
    "CNOT/Z commutator parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        commutator(cnot_gate(0, 1).as_expr(), x_gate(1).as_expr()),
      ),
    ),
    quantum_doit_str("Commutator(CNotGate(0, 1), XGate(1))"),
    "CNOT/X commutator parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(
      anticommutator(hadamard_gate(0).as_expr(), z_gate(1).as_expr()),
      nqubits=2,
    ),
    physics_eval_matrix(
      "represent(AntiCommutator(HadamardGate(0), ZGate(1)).doit(), nqubits=2)",
    ),
    4,
    4,
    "disjoint one-qubit anticommutator parity",
  )
}
