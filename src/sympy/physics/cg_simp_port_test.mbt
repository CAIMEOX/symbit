///|
test "physics.quantum.cg_simp: sum parity" {
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = @symcore.Expr::Symbol("c")
  let cp = @symcore.Expr::Symbol("cp")
  let alpha = @symcore.Expr::Symbol("alpha")
  let beta = @symcore.Expr::Symbol("beta")
  let gamma = @symcore.Expr::Symbol("gamma")
  let gammap = @symcore.Expr::Symbol("gammap")

  let eq1 = x *
    quantum_sum1(
      cg(a, alpha, b, @symcore.int(0), a, alpha).as_expr(),
      alpha,
      @symcore.int(-1) * a,
      a,
    )
  quantum_test_assert_expr_equal(
    cg_simp(eq1),
    quantum_cg_simp(@symprint.pretty_string(eq1)),
    "cg_simp eq1",
  )

  let eq2 = quantum_sum1(
    (@symcore.int(-1) ^ (a - alpha)) *
    cg(a, alpha, a, @symcore.int(-1) * alpha, c, @symcore.int(0)).as_expr(),
    alpha,
    @symcore.int(-1) * a,
    a,
  )
  quantum_test_assert_expr_equal(
    cg_simp(eq2),
    quantum_cg_simp(@symprint.pretty_string(eq2)),
    "cg_simp eq2",
  )

  let eq4 = quantum_sum2(
    cg(a, alpha, b, beta, c, gamma).as_expr() *
    cg(a, alpha, b, beta, cp, gammap).as_expr(),
    alpha,
    @symcore.int(-1) * a,
    a,
    beta,
    @symcore.int(-1) * b,
    b,
  )
  quantum_test_assert_expr_equal(
    cg_simp(eq4),
    quantum_cg_simp(@symprint.pretty_string(eq4)),
    "cg_simp eq4",
  )
}

///|
test "physics.quantum.cg_simp: square-sum parity" {
  let half = quantum_test_frac(1, 2)
  let alpha = @symcore.Expr::Symbol("alpha")
  let beta = @symcore.Expr::Symbol("beta")

  let expr = quantum_sum2(
    cg(half, alpha, half, beta, @symcore.int(1), alpha + beta).as_expr() ^
    @symcore.int(2),
    alpha,
    @symcore.int(-1) * half,
    half,
    beta,
    @symcore.int(-1) * half,
    half,
  )
  quantum_test_assert_expr_equal(
    cg_simp(expr),
    quantum_cg_simp(@symprint.pretty_string(expr)),
    "cg_simp square",
  )
}

///|
test "physics.quantum.cg_simp: additive parity" {
  let j = @symcore.Expr::Symbol("j")
  let half = quantum_test_frac(1, 2)

  let eq1 = @symcore.add([
    @symcore.mul([
      @symcore.int(2),
      cg(half, half, j, @symcore.int(0), half, half).as_expr(),
    ]),
    cg(
      half,
      @symcore.int(-1) * half,
      j,
      @symcore.int(0),
      half,
      @symcore.int(-1) * half,
    ).as_expr(),
  ])
  quantum_test_assert_expr_equal(
    cg_simp(eq1),
    quantum_cg_simp(@symprint.pretty_string(eq1)),
    "cg_simp additive eq1",
  )

  let eq2 = @symcore.add([
    cg(
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(-1),
      @symcore.int(0),
      @symcore.int(0),
    ).as_expr(),
    @symcore.mul([
      @symcore.int(-1),
      cg(
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(0),
      ).as_expr(),
    ]),
    cg(
      @symcore.int(1),
      @symcore.int(-1),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(0),
    ).as_expr(),
  ])
  quantum_test_assert_expr_equal(
    cg_simp(eq2),
    quantum_cg_simp(@symprint.pretty_string(eq2)),
    "cg_simp additive eq2",
  )
}

///|
test "physics.quantum.cg_simp: additive eq9 square parity" {
  let half = quantum_test_frac(1, 2)
  let m1 = @symcore.Expr::Symbol("m1")
  let m2 = @symcore.Expr::Symbol("m2")

  let a = cg(
      half,
      half,
      half,
      @symcore.int(-1) * half,
      @symcore.int(1),
      @symcore.int(0),
    ).as_expr() ^
    @symcore.int(2)
  let b = cg(
      half,
      half,
      half,
      @symcore.int(-1) * half,
      @symcore.int(0),
      @symcore.int(0),
    ).as_expr() ^
    @symcore.int(2)
  let numeric = @symcore.add([a, b])
  quantum_test_assert_expr_equal(
    cg_simp(numeric),
    quantum_cg_simp(@symprint.pretty_string(numeric)),
    "cg_simp eq9 square numeric",
  )
  let numeric_weighted = @symcore.add([
    @symcore.mul([@symcore.int(5), a]),
    @symcore.mul([@symcore.int(3), b]),
  ])
  quantum_test_assert_expr_equal(
    cg_simp(numeric_weighted),
    quantum_cg_simp(@symprint.pretty_string(numeric_weighted)),
    "cg_simp eq9 square weighted numeric",
  )

  let s1 = cg(half, m1, half, m2, @symcore.int(1), @symcore.int(1)).as_expr() ^
    @symcore.int(2)
  let s2 = cg(half, m1, half, m2, @symcore.int(1), @symcore.int(0)).as_expr() ^
    @symcore.int(2)
  let s3 = cg(half, m1, half, m2, @symcore.int(1), @symcore.int(-1)).as_expr() ^
    @symcore.int(2)
  let s4 = cg(half, m1, half, m2, @symcore.int(0), @symcore.int(0)).as_expr() ^
    @symcore.int(2)
  let symbolic = @symcore.add([s1, s2, s3, s4])
  quantum_test_assert_expr_equal(
    cg_simp(symbolic),
    quantum_cg_simp(@symprint.pretty_string(symbolic)),
    "cg_simp eq9 square symbolic",
  )
  let symbolic_weighted = @symcore.add([
    @symcore.mul([@symcore.int(3), s1]),
    @symcore.mul([@symcore.int(5), s2]),
    @symcore.mul([@symcore.int(3), s3]),
    @symcore.mul([@symcore.int(4), s4]),
  ])
  quantum_test_assert_expr_equal(
    cg_simp(symbolic_weighted),
    quantum_cg_simp(@symprint.pretty_string(symbolic_weighted)),
    "cg_simp eq9 square weighted symbolic",
  )
}

///|
test "physics.quantum.cg_simp: additive eq9 cross parity" {
  let half = quantum_test_frac(1, 2)
  let m1 = @symcore.Expr::Symbol("m1")
  let m1p = @symcore.Expr::Symbol("m1p")
  let m2 = @symcore.Expr::Symbol("m2")
  let m2p = @symcore.Expr::Symbol("m2p")

  let numeric = @symcore.add([
    @symcore.mul([
      cg(
        half,
        half,
        half,
        @symcore.int(-1) * half,
        @symcore.int(1),
        @symcore.int(0),
      ).as_expr(),
      cg(
        half,
        @symcore.int(-1) * half,
        half,
        half,
        @symcore.int(1),
        @symcore.int(0),
      ).as_expr(),
    ]),
    @symcore.mul([
      cg(
        half,
        half,
        half,
        @symcore.int(-1) * half,
        @symcore.int(0),
        @symcore.int(0),
      ).as_expr(),
      cg(
        half,
        @symcore.int(-1) * half,
        half,
        half,
        @symcore.int(0),
        @symcore.int(0),
      ).as_expr(),
    ]),
  ])
  let symbolic = @symcore.add([
    @symcore.mul([
      cg(half, m1, half, m2, @symcore.int(1), @symcore.int(1)).as_expr(),
      cg(half, m1p, half, m2p, @symcore.int(1), @symcore.int(1)).as_expr(),
    ]),
    @symcore.mul([
      cg(half, m1, half, m2, @symcore.int(1), @symcore.int(0)).as_expr(),
      cg(half, m1p, half, m2p, @symcore.int(1), @symcore.int(0)).as_expr(),
    ]),
    @symcore.mul([
      cg(half, m1, half, m2, @symcore.int(1), @symcore.int(-1)).as_expr(),
      cg(half, m1p, half, m2p, @symcore.int(1), @symcore.int(-1)).as_expr(),
    ]),
    @symcore.mul([
      cg(half, m1, half, m2, @symcore.int(0), @symcore.int(0)).as_expr(),
      cg(half, m1p, half, m2p, @symcore.int(0), @symcore.int(0)).as_expr(),
    ]),
  ])
  quantum_test_assert_expr_equal(
    cg_simp(numeric),
    quantum_cg_simp(@symprint.pretty_string(numeric)),
    "cg_simp eq9 cross numeric",
  )
  quantum_test_assert_expr_equal(
    cg_simp(symbolic),
    quantum_cg_simp(@symprint.pretty_string(symbolic)),
    "cg_simp eq9 cross symbolic",
  )
}
