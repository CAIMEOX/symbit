///|
test "physics.quantum.sho1d: parity" {
  quantum_test_assert_string_equal(
    quantum_eval_str("Dagger(RaisingOp(a))"),
    quantum_eval_str(@symprint.to_string(dagger(raising_op()))),
    "raising adjoint parity",
  )
  quantum_test_assert_string_equal(
    quantum_doit_str("Commutator(RaisingOp(a), LoweringOp(a))"),
    quantum_eval_str(
      @symprint.to_string(commutator(raising_op(), lowering_op())),
    ),
    "sho commutator parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("RaisingOp(a)*SHOKet(1)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([raising_op(), sho_ket(@symcore.int(1))])),
      ),
    ),
    "sho qapply parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(raising_op(), basis=Some(number_op()), ndim=4),
    quantum_represent_matrix("RaisingOp(a)", "NumberOp(n)", 4),
    4,
    4,
    "raising matrix parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(sho_hamiltonian(), basis=Some(number_op()), ndim=4),
    quantum_represent_matrix("Hamiltonian(d)", "NumberOp(n)", 4),
    4,
    4,
    "Hamiltonian matrix parity",
  )
}

///|
test "physics.quantum.sho1d: symbolic parity" {
  quantum_test_assert_string_equal(
    quantum_eval_str("RaisingOp(a).rewrite(\"xp\").doit()"),
    quantum_eval_str(@symprint.to_string(sho_rewrite_as_xp(raising_op()))),
    "raising rewrite xp parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("LoweringOp(a).rewrite(\"xp\").doit()"),
    quantum_eval_str(@symprint.to_string(sho_rewrite_as_xp(lowering_op()))),
    "lowering rewrite xp parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("NumberOp(n).rewrite(\"a\").doit()"),
    quantum_eval_str(
      @symprint.to_string(
        sho_rewrite_as_a(number_op(label=@symcore.symbol("n"))),
      ),
    ),
    "number rewrite a parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("LoweringOp(a)*SHOKet(k)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([lowering_op(), sho_ket(@symcore.symbol("k"))])),
      ),
    ),
    "lowering symbolic qapply parity",
  )
}
