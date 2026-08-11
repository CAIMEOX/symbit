///|
test "physics.quantum.boson/fermion: local operator and qapply rules" {
  let a = boson_op(Symbol("a"))
  let c = fermion_op(Symbol("c"))
  inspect(Show::to_string(a), content="a")
  inspect(Show::to_string(a.dagger()), content="Dagger(a)")
  inspect(Show::to_string(c.dagger()), content="Dagger(c)")

  quantum_test_assert_expr_equal(
    commutator(a.as_expr(), a.dagger().as_expr()),
    "1",
    "boson commutator",
  )
  quantum_test_assert_expr_equal(
    anticommutator(c.as_expr(), c.dagger().as_expr()),
    "1",
    "fermion anticommutator",
  )

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([a.as_expr(), boson_fock_ket(@symcore.int(3))])),
    "sqrt(3)*BosonFockKet(2)",
    "boson fock apply",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([a.as_expr(), boson_coherent_ket(Symbol("alpha"))])),
    "alpha*BosonCoherentKet(alpha)",
    "boson coherent apply",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([c.as_expr(), fermion_fock_ket(@symcore.int(1))])),
    "FermionFockKet(0)",
    "fermion annihilation apply",
  )
  quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([c.dagger().as_expr(), fermion_fock_ket(@symcore.int(1))]),
    ),
    "0",
    "fermion creation saturates",
  )
}

///|
test "physics.quantum.operatorordering: local normal forms" {
  let a = boson_op(Symbol("a"))
  let c = fermion_op(Symbol("c"))
  quantum_test_assert_expr_equal(
    normal_ordered_form(@symcore.raw_mul([a.as_expr(), a.dagger().as_expr()])),
    "1 + BosonOp(a, 0)*BosonOp(a, 1)",
    "boson ordered form",
  )
  quantum_test_assert_expr_equal(
    normal_ordered_form(@symcore.raw_mul([c.as_expr(), c.dagger().as_expr()])),
    "1 - FermionOp(c, 0)*FermionOp(c, 1)",
    "fermion ordered form",
  )
}
