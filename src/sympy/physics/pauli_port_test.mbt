///|
test "physics.quantum.pauli: parity" {
  let sx = sigma_x()
  let sy = sigma_y()
  let sm = sigma_minus()
  let sp = sigma_plus()

  quantum_test_assert_string_equal(
    quantum_qapply_str("SigmaX()*SigmaZKet(0)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([sx.as_expr(), sigma_z_ket(0).as_expr()])),
      ),
    ),
    "SigmaX qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("SigmaY()*SigmaZKet(1)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([sy.as_expr(), sigma_z_ket(1).as_expr()])),
      ),
    ),
    "SigmaY qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_doit_str("InnerProduct(SigmaZBra(1), SigmaZKet(1))"),
    @symprint.to_string(
      inner_product(sigma_z_bra(1).as_expr(), sigma_z_ket(1).as_expr()),
    ),
    "SigmaZ inner product parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Dagger(SigmaPlus())"),
    quantum_eval_str(@symprint.to_string(dagger(sp.as_expr()))),
    "SigmaPlus dagger parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("qsimplify_pauli(SigmaX()*SigmaY())"),
    quantum_eval_str(
      @symprint.to_string(
        qsimplify_pauli(@symcore.raw_mul([sx.as_expr(), sy.as_expr()])),
      ),
    ),
    "qsimplify parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Commutator(SigmaX(), SigmaY()).doit()"),
    quantum_eval_str(
      @symprint.to_string(commutator(sx.as_expr(), sy.as_expr())),
    ),
    "commutator parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("AntiCommutator(SigmaMinus(), SigmaPlus()).doit()"),
    quantum_eval_str(
      @symprint.to_string(anticommutator(sm.as_expr(), sp.as_expr())),
    ),
    "anticommutator parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(sy.as_expr()),
    physics_eval_matrix("represent(SigmaY())"),
    2,
    2,
    "represent SigmaY parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(sigma_z_ket(1).as_expr()),
    physics_eval_matrix("represent(SigmaZKet(1))"),
    2,
    1,
    "represent SigmaZKet parity",
  )
}
