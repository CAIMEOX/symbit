///|
test "physics.quantum.cg_simp: sum parity" {
  let x = @symcore.symbol("x")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = @symcore.symbol("c")
  let cp = @symcore.symbol("cp")
  let alpha = @symcore.symbol("alpha")
  let beta = @symcore.symbol("beta")
  let gamma = @symcore.symbol("gamma")
  let gammap = @symcore.symbol("gammap")

  let eq1 = x * quantum_sum1(
    cg(a, alpha, b, @symcore.int(0), a, alpha).as_expr(),
    alpha,
    @symcore.int(-1) * a,
    a,
  )
  try! quantum_test_assert_expr_equal(
    cg_simp(eq1),
    try! @sympy_physics.quantum_cg_simp(@symprint.to_string(eq1)),
    "cg_simp eq1",
  )

  let eq2 = quantum_sum1(
    ((@symcore.int(-1)) ^ (a - alpha)) * cg(a, alpha, a, @symcore.int(-1) * alpha, c, @symcore.int(0)).as_expr(),
    alpha,
    @symcore.int(-1) * a,
    a,
  )
  try! quantum_test_assert_expr_equal(
    cg_simp(eq2),
    try! @sympy_physics.quantum_cg_simp(@symprint.to_string(eq2)),
    "cg_simp eq2",
  )

  let eq4 = quantum_sum2(
    cg(a, alpha, b, beta, c, gamma).as_expr() * cg(a, alpha, b, beta, cp, gammap).as_expr(),
    alpha,
    @symcore.int(-1) * a,
    a,
    beta,
    @symcore.int(-1) * b,
    b,
  )
  try! quantum_test_assert_expr_equal(
    cg_simp(eq4),
    try! @sympy_physics.quantum_cg_simp(@symprint.to_string(eq4)),
    "cg_simp eq4",
  )
}

///|
test "physics.quantum.cg_simp: square-sum parity" {
  let half = quantum_test_frac(1, 2)
  let alpha = @symcore.symbol("alpha")
  let beta = @symcore.symbol("beta")

  let expr = quantum_sum2(
    (cg(half, alpha, half, beta, @symcore.int(1), alpha + beta).as_expr()) ^ @symcore.int(2),
    alpha,
    @symcore.int(-1) * half,
    half,
    beta,
    @symcore.int(-1) * half,
    half,
  )
  try! quantum_test_assert_expr_equal(
    cg_simp(expr),
    try! @sympy_physics.quantum_cg_simp(@symprint.to_string(expr)),
    "cg_simp square",
  )
}
