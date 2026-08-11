///|
test "physics.quantum.boson/fermion: parity" {
  let a = boson_op(Symbol("a"))
  let c = fermion_op(Symbol("c"))
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(commutator(a.as_expr(), a.dagger().as_expr())),
    ),
    quantum_doit_str("Commutator(BosonOp(a), Dagger(BosonOp(a)))"),
    "boson commutator parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(anticommutator(c.as_expr(), c.dagger().as_expr())),
    ),
    quantum_doit_str("AntiCommutator(FermionOp(c), Dagger(FermionOp(c)))"),
    "fermion anticommutator parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(@symcore.raw_mul([a.as_expr(), boson_fock_ket(@symcore.int(2))])),
      ),
    ),
    quantum_qapply_str("BosonOp(a)*BosonFockKet(2)"),
    "boson qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(
        qapply(
          @symcore.raw_mul([
            c.dagger().as_expr(),
            fermion_fock_ket(@symcore.int(0)),
          ]),
        ),
      ),
    ),
    quantum_qapply_str("Dagger(FermionOp(c))*FermionFockKet(0)"),
    "fermion qapply parity",
  )
}

///|
test "physics.quantum.operatorordering: parity" {
  let a = boson_op(Symbol("a"))
  let c = fermion_op(Symbol("c"))
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(
        normal_ordered_form(
          @symcore.raw_mul([a.as_expr(), a.dagger().as_expr()]),
        ),
      ),
    ),
    quantum_normal_order_str("BosonOp(a)*Dagger(BosonOp(a))"),
    "boson ordered parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.pretty_string(
        normal_ordered_form(
          @symcore.raw_mul([c.as_expr(), c.dagger().as_expr()]),
        ),
      ),
    ),
    quantum_normal_order_str("FermionOp(c)*Dagger(FermionOp(c))"),
    "fermion ordered parity",
  )
}
