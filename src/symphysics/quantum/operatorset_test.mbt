///|
test "physics.quantum.operatorset: local mappings" {
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(operators_to_state(x_op()).unwrap_or(@symcore.int(0))),
    ),
    @sympy_physics.quantum_eval_str("XKet(x)"),
    "XOp to XKet",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        operators_to_state(px_op()).unwrap_or(@symcore.int(0)),
      ),
    ),
    @sympy_physics.quantum_eval_str("PxKet(px)"),
    "PxOp to PxKet",
  )
  let ops = state_to_operators(x_bra(position=@symcore.symbol("y"))).unwrap_or([])
  guard ops.length() == 1 else { fail("expected one operator") }
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(@symprint.to_string(ops[0])),
    @sympy_physics.quantum_eval_str("XOp()"),
    "XBra to XOp",
  )

  let generic = operators_to_state(operator([@symcore.symbol("A")]).as_expr()).unwrap_or(
    @symcore.int(0),
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(@symprint.to_string(generic)),
    @sympy_physics.quantum_eval_str("Ket(psi)"),
    "generic Operator to Ket",
  )

  let spin_x = operators_to_state_many([j2(), jx()]).unwrap_or(@symcore.int(0))
  quantum_test_assert_expr_equal(spin_x, "JxKet(1/2, 1/2)", "J2/Jx to JxKet")
  let spin_ops = state_to_operators(
    jy_bra(quantum_test_frac(1, 2), quantum_test_frac(1, 2)).as_expr(),
  ).unwrap_or([])
  guard spin_ops.length() == 2 else { fail("expected two spin operators") }
  quantum_test_assert_expr_equal(spin_ops[0], "J2", "JyBra first operator")
  quantum_test_assert_expr_equal(spin_ops[1], "Jy", "JyBra second operator")
}
