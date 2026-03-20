///|
test "physics.quantum.commutator: constructor, expansion, and doit" {
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")
  let c_op = @symcore.symbol("C")

  quantum_test_assert_string_equal(
    @symprint.to_string(commutator(a, a_op)),
    "0",
    "commutator scalar annihilates",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(@symprint.to_string(commutator(b_op, a_op))),
    quantum_eval_str("Commutator(B, A)"),
    "commutator canonical order",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        commutator(@symcore.raw_mul([a, a_op]), @symcore.raw_mul([b, b_op])),
      ),
    ),
    quantum_eval_str("Commutator(a*A, b*B)"),
    "commutator scalar factors",
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
    "commutator expand mul",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        commutator_doit(commutator(a_op, b_op, evaluate=false)),
      ),
    ),
    quantum_doit_str("Commutator(A, B)"),
    "commutator doit",
  )
}

///|
test "physics.quantum.anticommutator: constructor and doit" {
  let a = @symcore.symbol("a")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")

  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(anticommutator(a, b_op)),
    ),
    quantum_eval_str("AntiCommutator(a, B)"),
    "anticommutator scalar",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(anticommutator(b_op, a_op)),
    ),
    quantum_eval_str("AntiCommutator(B, A)"),
    "anticommutator canonical order",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        anticommutator_doit(anticommutator(a_op, b_op, evaluate=false)),
      ),
    ),
    quantum_doit_str("AntiCommutator(A, B)"),
    "anticommutator doit",
  )
}

///|
test "physics.quantum.(anti)commutator: gate commuting subsets" {
  inspect(
    @symprint.to_string(commutator(x_gate(0).as_expr(), y_gate(1).as_expr())),
    content="0",
  )
  inspect(
    @symprint.to_string(
      commutator(cnot_gate(0, 1).as_expr(), z_gate(0).as_expr()),
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(
      commutator(cnot_gate(0, 1).as_expr(), x_gate(1).as_expr()),
    ),
    content="0",
  )
  inspect(
    @symprint.to_string(
      anticommutator(hadamard_gate(0).as_expr(), z_gate(1).as_expr()),
    ),
    content="2*ZGate(1)*HadamardGate(0)",
  )
}
