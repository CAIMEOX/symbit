///|
test "physics.quantum.boson/fermion: local operator and qapply rules" {
  let a = boson_op(@symcore.symbol("a"))
  let c = fermion_op(@symcore.symbol("c"))
  inspect(a.to_string(), content="a")
  inspect(a.dagger().to_string(), content="Dagger(a)")
  inspect(c.dagger().to_string(), content="Dagger(c)")

  try! quantum_test_assert_expr_equal(
    commutator(a.as_expr(), a.dagger().as_expr()),
    "1",
    "boson commutator",
  )
  try! quantum_test_assert_expr_equal(
    anticommutator(c.as_expr(), c.dagger().as_expr()),
    "1",
    "fermion anticommutator",
  )

  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([a.as_expr(), boson_fock_ket(@symcore.int(3))])),
    "sqrt(3)*BosonFockKet(2)",
    "boson fock apply",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([a.as_expr(), boson_coherent_ket(@symcore.symbol("alpha"))])),
    "alpha*BosonCoherentKet(alpha)",
    "boson coherent apply",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([c.as_expr(), try! fermion_fock_ket(@symcore.int(1))])),
    "FermionFockKet(0)",
    "fermion annihilation apply",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([c.dagger().as_expr(), try! fermion_fock_ket(@symcore.int(1))])),
    "0",
    "fermion creation saturates",
  )
}

///|
test "physics.quantum.operatorordering: local normal forms" {
  let a = boson_op(@symcore.symbol("a"))
  let c = fermion_op(@symcore.symbol("c"))
  try! quantum_test_assert_expr_equal(
    normal_ordered_form(@symcore.raw_mul([a.as_expr(), a.dagger().as_expr()])),
    "1 + BosonOp(a, 0)*BosonOp(a, 1)",
    "boson ordered form",
  )
  try! quantum_test_assert_expr_equal(
    normal_ordered_form(@symcore.raw_mul([c.as_expr(), c.dagger().as_expr()])),
    "1 - FermionOp(c, 0)*FermionOp(c, 1)",
    "fermion ordered form",
  )
}
