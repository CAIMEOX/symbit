///|
test "physics.quantum.pauli: local operators, states, and simplification" {
  let sx = sigma_x()
  let sy = sigma_y()
  let sz = sigma_z()
  let sp = sigma_plus()
  let sm = sigma_minus()
  inspect(sx.to_string(), content="SigmaX()")
  inspect(
    sigma_x(name=Some(@symcore.symbol("a"))).repr(),
    content="SigmaX(Symbol('a'))",
  )
  inspect(sigma_z_ket(0).dual().to_string(), content="<0|")

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([sx.as_expr(), sigma_z_ket(0).as_expr()])),
    "SigmaZKet(1)",
    "SigmaX action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([sy.as_expr(), sigma_z_ket(1).as_expr()])),
    "-I*SigmaZKet(0)",
    "SigmaY action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([sm.as_expr(), sigma_z_ket(0).as_expr()])),
    "SigmaZKet(1)",
    "SigmaMinus action",
  )
  quantum_test_assert_expr_equal(
    inner_product(sigma_z_bra(1).as_expr(), sigma_z_ket(1).as_expr()),
    "1",
    "SigmaZ inner product",
  )
  inspect(@symprint.to_string(dagger(sp.as_expr())), content="SigmaMinus()")
  inspect(@symprint.to_string(dagger(sz.as_expr())), content="SigmaZ()")
  quantum_test_assert_expr_equal(
    qsimplify_pauli(@symcore.raw_mul([sx.as_expr(), sy.as_expr()])),
    "I*SigmaZ()",
    "qsimplify xy",
  )
  quantum_test_assert_expr_equal(
    commutator(sx.as_expr(), sy.as_expr()),
    "2*I*SigmaZ()",
    "pauli commutator",
  )
  quantum_test_assert_expr_equal(
    anticommutator(sm.as_expr(), sp.as_expr()),
    "1",
    "pauli anticommutator",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_pauli_operator(sy.as_expr()),
    ["0", "-I", "I", "0"],
    2,
    2,
    "represent SigmaY",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_pauli_state(sigma_z_ket(1).as_expr()),
    ["0", "1"],
    2,
    1,
    "represent SigmaZKet",
  )
}
