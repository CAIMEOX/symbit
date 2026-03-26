///|
test "physics.quantum.sho1d: local ladder algebra and number-basis matrices" {
  quantum_test_assert_expr_equal(
    dagger(raising_op()),
    "LoweringOp(a)",
    "raising adjoint",
  )
  quantum_test_assert_expr_equal(
    commutator(raising_op(), lowering_op()),
    "-1",
    "[a^dagger, a]",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([raising_op(), sho_ket(@symcore.int(1))])),
    "sqrt(2)*SHOKet(2)",
    "raising action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([lowering_op(), sho_ket(@symcore.int(0))])),
    "0",
    "lowering vacuum",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([number_op(), sho_ket(@symcore.int(3))])),
    "3*SHOKet(3)",
    "number action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([sho_hamiltonian(), sho_ket(@symcore.int(1))])),
    "3*hbar*omega*SHOKet(1)/2",
    "Hamiltonian action",
  )
  quantum_test_assert_expr_equal(
    inner_product(sho_bra(@symcore.int(3)), sho_ket(@symcore.int(3))),
    "KroneckerDelta(3, 3)",
    "SHO overlap",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(raising_op(), basis=Some(number_op()), ndim=4),
    [
      "0", "0", "0", "0", "1", "0", "0", "0", "0", "sqrt(2)", "0", "0", "0", "0",
      "sqrt(3)", "0",
    ],
    4,
    4,
    "raising matrix",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(sho_ket(@symcore.int(3)), basis=Some(number_op()), ndim=4),
    ["0", "0", "0", "1"],
    4,
    1,
    "SHOKet basis vector",
  )
}

///|
test "physics.quantum.sho1d: symbolic rewrites and symbolic ladder action" {
  let k = @symcore.Expr::Symbol("k")
  assert_true(
    sho_rewrite_as_a(number_op()) ==
    @symcore.raw_mul([raising_op(), lowering_op()]),
  )
  assert_true(
    sho_rewrite_as_h(number_op()) ==
    sho_hamiltonian() * @symcore.raw_pow(hbar * sho_omega, @symcore.int(-1)) -
    quantum_test_frac(1, 2),
  )
  assert_true(
    sho_rewrite_as_n(sho_hamiltonian()) ==
    hbar * sho_omega * (number_op() + quantum_test_frac(1, 2)),
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([raising_op(), sho_ket(k)])),
    "sqrt(k + 1)*SHOKet(k + 1)",
    "raising symbolic action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([lowering_op(), sho_ket(k)])),
    "sqrt(k)*SHOKet(k - 1)",
    "lowering symbolic action",
  )
}

///|
test "physics.quantum.sho1d: qapply with sum_doit" {
  let p = @symcore.Expr::Symbol("p")
  let q = @symcore.Expr::Symbol("q")
  let n = @symcore.Expr::Symbol("n")
  let wf_n = @symcore.raw_function("wf", [n])

  quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        @symcore.raw_function("Sum", [
          @symcore.raw_mul([sho_ket(p), sho_bra(p)]),
          @symcore.raw_function("Tuple", [
            p,
            @symcore.int(0),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          ]),
        ]),
        sho_ket(q),
      ]),
      sum_doit=true,
    ),
    "SHOKet(q)",
    "sho resolution of identity on ket",
  )
  quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        sho_bra(q),
        @symcore.raw_function("Sum", [
          wf_n * sho_ket(n),
          @symcore.raw_function("Tuple", [
            n,
            @symcore.int(0),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          ]),
        ]),
      ]),
      sum_doit=true,
    ),
    "wf(q)",
    "sho bra projection through sum",
  )
}
