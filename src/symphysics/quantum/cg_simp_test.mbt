///|
test "physics.quantum.cg_simp: core sum identities" {
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
    "x*(2*a + 1)*KroneckerDelta(b, 0)",
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
    "sqrt(2*a + 1)*KroneckerDelta(c, 0)",
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
    "KroneckerDelta(c, cp)*KroneckerDelta(gamma, gammap)",
    "cg_simp eq4",
  )
}

///|
test "physics.quantum.cg_simp: square orthogonality identity" {
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
  try! quantum_test_assert_expr_equal(cg_simp(expr), "1", "cg_simp square")
}

///|
test "physics.quantum.cg_simp: additive identities" {
  let j = @symcore.symbol("j")
  let half = quantum_test_frac(1, 2)

  let eq1 = @symcore.add([
    @symcore.mul([@symcore.int(2), cg(half, half, j, @symcore.int(0), half, half).as_expr()]),
    cg(half, @symcore.int(-1) * half, j, @symcore.int(0), half, @symcore.int(-1) * half).as_expr(),
  ])
  try! quantum_test_assert_expr_equal(
    cg_simp(eq1),
    "2*KroneckerDelta(j, 0) + CG(1/2, 1/2, j, 0, 1/2, 1/2)",
    "cg_simp additive eq1",
  )

  let eq2 = @symcore.add([
    cg(@symcore.int(1), @symcore.int(1), @symcore.int(1), @symcore.int(-1), @symcore.int(0), @symcore.int(0)).as_expr(),
    @symcore.mul([
      @symcore.int(-1),
      cg(@symcore.int(1), @symcore.int(0), @symcore.int(1), @symcore.int(0), @symcore.int(0), @symcore.int(0)).as_expr(),
    ]),
    cg(@symcore.int(1), @symcore.int(-1), @symcore.int(1), @symcore.int(1), @symcore.int(0), @symcore.int(0)).as_expr(),
  ])
  try! quantum_test_assert_expr_equal(
    cg_simp(eq2),
    "sqrt(3)",
    "cg_simp additive eq2",
  )
}

///|
test "physics.quantum.cg_simp: additive eq9 square families" {
  let half = quantum_test_frac(1, 2)
  let m1 = @symcore.symbol("m1")
  let m2 = @symcore.symbol("m2")

  let a = (cg(half, half, half, @symcore.int(-1) * half, @symcore.int(1), @symcore.int(0)).as_expr()) ^
    @symcore.int(2)
  let b = (cg(half, half, half, @symcore.int(-1) * half, @symcore.int(0), @symcore.int(0)).as_expr()) ^
    @symcore.int(2)
  try! quantum_test_assert_expr_equal(cg_simp(a + b), "1", "cg_simp eq9 square numeric")
  try! quantum_test_assert_expr_equal(
    cg_simp(@symcore.add([@symcore.mul([@symcore.int(5), a]), @symcore.mul([@symcore.int(3), b])])),
    "3 + 2*CG(1/2, 1/2, 1/2, -1/2, 1, 0)**2",
    "cg_simp eq9 square weighted numeric",
  )

  let s1 = (cg(half, m1, half, m2, @symcore.int(1), @symcore.int(1)).as_expr()) ^ @symcore.int(2)
  let s2 = (cg(half, m1, half, m2, @symcore.int(1), @symcore.int(0)).as_expr()) ^ @symcore.int(2)
  let s3 = (cg(half, m1, half, m2, @symcore.int(1), @symcore.int(-1)).as_expr()) ^ @symcore.int(2)
  let s4 = (cg(half, m1, half, m2, @symcore.int(0), @symcore.int(0)).as_expr()) ^ @symcore.int(2)
  try! quantum_test_assert_expr_equal(cg_simp(@symcore.add([s1, s2, s3, s4])), "1", "cg_simp eq9 square symbolic")
  try! quantum_test_assert_expr_equal(
    cg_simp(
      @symcore.add([
        @symcore.mul([@symcore.int(3), s1]),
        @symcore.mul([@symcore.int(5), s2]),
        @symcore.mul([@symcore.int(3), s3]),
        @symcore.mul([@symcore.int(4), s4]),
      ]),
    ),
    "3 + 2*CG(1/2, m1, 1/2, m2, 1, 0)**2 + CG(1/2, m1, 1/2, m2, 0, 0)**2",
    "cg_simp eq9 square weighted symbolic",
  )
}

///|
test "physics.quantum.cg_simp: additive eq9 cross families" {
  let half = quantum_test_frac(1, 2)
  let m1 = @symcore.symbol("m1")
  let m1p = @symcore.symbol("m1p")
  let m2 = @symcore.symbol("m2")
  let m2p = @symcore.symbol("m2p")

  let a = @symcore.mul([
    cg(half, half, half, @symcore.int(-1) * half, @symcore.int(1), @symcore.int(0)).as_expr(),
    cg(half, @symcore.int(-1) * half, half, half, @symcore.int(1), @symcore.int(0)).as_expr(),
  ])
  let b = @symcore.mul([
    cg(half, half, half, @symcore.int(-1) * half, @symcore.int(0), @symcore.int(0)).as_expr(),
    cg(half, @symcore.int(-1) * half, half, half, @symcore.int(0), @symcore.int(0)).as_expr(),
  ])
  try! quantum_test_assert_expr_equal(cg_simp(a + b), "0", "cg_simp eq9 cross numeric")

  let s1 = @symcore.mul([
    cg(half, m1, half, m2, @symcore.int(1), @symcore.int(1)).as_expr(),
    cg(half, m1p, half, m2p, @symcore.int(1), @symcore.int(1)).as_expr(),
  ])
  let s2 = @symcore.mul([
    cg(half, m1, half, m2, @symcore.int(1), @symcore.int(0)).as_expr(),
    cg(half, m1p, half, m2p, @symcore.int(1), @symcore.int(0)).as_expr(),
  ])
  let s3 = @symcore.mul([
    cg(half, m1, half, m2, @symcore.int(1), @symcore.int(-1)).as_expr(),
    cg(half, m1p, half, m2p, @symcore.int(1), @symcore.int(-1)).as_expr(),
  ])
  let s4 = @symcore.mul([
    cg(half, m1, half, m2, @symcore.int(0), @symcore.int(0)).as_expr(),
    cg(half, m1p, half, m2p, @symcore.int(0), @symcore.int(0)).as_expr(),
  ])
  try! quantum_test_assert_expr_equal(
    cg_simp(@symcore.add([s1, s2, s3, s4])),
    "KroneckerDelta(m1, m1p)*KroneckerDelta(m2, m2p)",
    "cg_simp eq9 cross symbolic",
  )
}
