///|
test "physics.quantum.sho1d: local ladder algebra and number-basis matrices" {
  try! quantum_test_assert_expr_equal(
    dagger(raising_op()),
    "LoweringOp(a)",
    "raising adjoint",
  )
  try! quantum_test_assert_expr_equal(
    commutator(raising_op(), lowering_op()),
    "-1",
    "[a^dagger, a]",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([raising_op(), sho_ket(@symcore.int(1))])),
    "sqrt(2)*SHOKet(2)",
    "raising action",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([lowering_op(), sho_ket(@symcore.int(0))])),
    "0",
    "lowering vacuum",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([number_op(), sho_ket(@symcore.int(3))])),
    "3*SHOKet(3)",
    "number action",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([sho_hamiltonian(), sho_ket(@symcore.int(1))])),
    "3*hbar*omega*SHOKet(1)/2",
    "Hamiltonian action",
  )
  try! quantum_test_assert_expr_equal(
    inner_product(sho_bra(@symcore.int(3)), sho_ket(@symcore.int(3))),
    "KroneckerDelta(3, 3)",
    "SHO overlap",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(raising_op(), basis=Some(number_op()), ndim=4),
    [
      "0", "0", "0", "0", "1", "0", "0", "0", "0", "sqrt(2)", "0", "0", "0", "0",
      "sqrt(3)", "0",
    ],
    4,
    4,
    "raising matrix",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      sho_ket(@symcore.int(3)),
      basis=Some(number_op()),
      ndim=4,
    ),
    ["0", "0", "0", "1"],
    4,
    1,
    "SHOKet basis vector",
  )
}

///|
test "physics.quantum.sho1d: symbolic rewrites and symbolic ladder action" {
  let k = @symcore.symbol("k")
  guard sho_rewrite_as_a(number_op()) ==
    @symcore.raw_mul([raising_op(), lowering_op()]) else {
    fail("number rewrite as a")
  }
  guard sho_rewrite_as_h(number_op()) ==
    sho_hamiltonian() * @symcore.raw_pow(hbar * sho_omega, @symcore.int(-1)) -
    quantum_test_frac(1, 2) else {
    fail("number rewrite as H")
  }
  guard sho_rewrite_as_n(sho_hamiltonian()) ==
    hbar * sho_omega * (number_op() + quantum_test_frac(1, 2)) else {
    fail("Hamiltonian rewrite as N")
  }
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([raising_op(), sho_ket(k)])),
    "sqrt(k + 1)*SHOKet(k + 1)",
    "raising symbolic action",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([lowering_op(), sho_ket(k)])),
    "sqrt(k)*SHOKet(k - 1)",
    "lowering symbolic action",
  )
}

///|
test "physics.quantum.sho1d: qapply with sum_doit" {
  let p = @symcore.symbol("p")
  let q = @symcore.symbol("q")
  let n = @symcore.symbol("n")
  let wf_n = @symcore.raw_function("wf", [n])

  try! quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        @symcore.raw_function("Sum", [
          @symcore.raw_mul([sho_ket(p), sho_bra(p)]),
          @symcore.raw_function("Tuple", [p, @symcore.int(0), @symcore.symbol("oo")]),
        ]),
        sho_ket(q),
      ]),
      sum_doit=true,
    ),
    "SHOKet(q)",
    "sho resolution of identity on ket",
  )
  try! quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        sho_bra(q),
        @symcore.raw_function("Sum", [
          wf_n * sho_ket(n),
          @symcore.raw_function("Tuple", [n, @symcore.int(0), @symcore.symbol("oo")]),
        ]),
      ]),
      sum_doit=true,
    ),
    "wf(q)",
    "sho bra projection through sum",
  )
}
