///|
fn expr_equiv_to(ours : @symcore.Expr, oracle_expr : String) -> Bool {
  try! @sympy_stats.stats_expr_equiv(@symprint.to_string(ours), oracle_expr)
}

///|
test "compat aliases p/e/h and where_" {
  let x = @symcore.symbol("X")
  let rv = die("X", sides=6)
  let pe = p(eq(x, @symcore.int(1)), rv=rv)
  assert_true(try! @sympy_stats.stats_expr_equiv(@symprint.to_string(pe), "1/6"))
  let ee = e(x, rvs=[rv])
  assert_true(try! @sympy_stats.stats_expr_equiv(@symprint.to_string(ee), "7/2"))
  let he = h(x)
  assert_eq(@symprint.to_string(he), "entropy(X)")
  let w = where_(ge(x, @symcore.int(2)))
  assert_eq(@symprint.to_string(w), "where(Ge(X, 2))")
}

///|
test "compat uniform parity density cdf moments quantile" {
  let u = uniform("U", params=[@symcore.int(0), @symcore.int(2)])
  let x = @symcore.symbol("x")
  let d = density(u, x)
  let d_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda U, x: density(U)(x))(stats.Uniform('U', 0, 2), x)",
  )
  assert_true(expr_equiv_to(d, d_oracle))

  let c = cdf(u, x)
  let c_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda U, x: cdf(U)(x))(stats.Uniform('U', 0, 2), x)",
  )
  assert_true(expr_equiv_to(c, c_oracle))

  let su = @symcore.symbol("U")
  let m = expectation(su, rvs=[u])
  assert_true(expr_equiv_to(m, "1"))
  let v = variance(su, rvs=[u])
  assert_true(expr_equiv_to(v, "1/3"))

  let q = quantile(su, try! @symcore.rational_from_ints(1, 4), rvs=[u])
  assert_true(expr_equiv_to(q, "1/2"))
}

///|
test "compat distribution constructors symbolic fallback" {
  let a = beta("A", params=[@symcore.int(2), @symcore.int(5)])
  let x = @symcore.symbol("x")
  let d = density(a, x)
  assert_eq(
    @symprint.to_string(d),
    "Piecewise(Tuple((x*beta(2, 5)**-1*(-1*x + 1)**4), And(Le(0, x), Le(x, 1))), Tuple(0, True))",
  )

  let m = matrix_student_t(
    "M",
    params=[
      @symcore.int(3),
      @symcore.symbol("Mean"),
      @symcore.symbol("RowCov"),
      @symcore.symbol("ColCov"),
    ],
  )
  let md = matrix_density(m, @symcore.symbol("X"))
  match md {
    Some(v) => assert_eq(@symprint.to_string(v), "MatrixStudentTDensity(X, M)")
    None => assert_true(false)
  }
}

///|
test "compat mgf and characteristic function parity" {
  let b = binomial("B", @symcore.int(5), try! @symcore.rational_from_ints(1, 3))
  let sb = @symcore.symbol("B")
  let t = @symcore.symbol("t")

  let mgf = moment_generating_function(sb, t, rvs=[b])
  let mgf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda B, t: moment_generating_function(B)(t))(Binomial('B', 5, Rational(1, 3)), t)",
  )
  assert_true(expr_equiv_to(mgf, mgf_oracle))

  let cf = characteristic_function(sb, t, rvs=[b])
  let cf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda B, t: characteristic_function(B)(t))(Binomial('B', 5, Rational(1, 3)), t)",
  )
  assert_true(expr_equiv_to(cf, cf_oracle))
}

///|
test "compat special constructors keep concrete behavior" {
  let g = gamma("G", @symcore.int(3), @symcore.int(2))
  let ge = expectation(@symcore.symbol("G"), rvs=[g])
  assert_true(try! @sympy_stats.stats_expr_equiv(@symprint.to_string(ge), "6"))
  let w = wishart("W", @symcore.int(4), @symcore.symbol("Sigma"))
  let wd = matrix_density(w, @symcore.symbol("X"))
  match wd {
    Some(v) => assert_eq(@symprint.to_string(v), "WishartDensity(X, 4, Sigma)")
    None => assert_true(false)
  }
}

///|
test "compat symbolic families and rademacher parity" {
  let r = rayleigh("R", params=[@symcore.int(2)])
  let sr = @symcore.symbol("R")
  let re = expectation(sr, rvs=[r])
  let rv = variance(sr, rvs=[r])
  let re_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda R: E(R))(stats.Rayleigh('R', 2))",
  )
  let rv_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda R: variance(R))(stats.Rayleigh('R', 2))",
  )
  assert_true(expr_equiv_to(re, re_oracle))
  assert_true(expr_equiv_to(rv, rv_oracle))

  let rad = rademacher("X")
  let sx = @symcore.symbol("X")
  assert_true(expr_equiv_to(expectation(sx, rvs=[rad]), "0"))
  assert_true(expr_equiv_to(variance(sx, rvs=[rad]), "1"))
  let p1 = probability(eq(sx, @symcore.int(1)), rv=rad)
  assert_true(expr_equiv_to(p1, "1/2"))
}

///|
test "compat matrix helpers shape smoke" {
  let xs = [@symcore.symbol("X"), @symcore.symbol("Y")]
  let vars = variance_matrix(xs)
  inspect(vars.length(), content="2")
  inspect(vars[0].length(), content="2")
  let cross = cross_covariance_matrix(xs, [@symcore.symbol("Z")])
  inspect(cross.length(), content="2")
  inspect(cross[0].length(), content="1")
}

///|
test "compat non-fallback symbolic families" {
  let bb = beta_binomial("BB", params=[@symcore.int(10), @symcore.int(2), @symcore.int(3)])
  assert_eq(
    @symprint.to_string(density(bb, @symcore.int(2))),
    "BetaBinomialPMF(2, 10, 2, 3)",
  )
  assert_eq(
    @symprint.to_string(cdf(bb, @symcore.int(2))),
    "BetaBinomialCDF(2, 10, 2, 3)",
  )

  let d = dirichlet("D", params=[@symcore.int(2), @symcore.int(3)])
  let sd = @symcore.symbol("D")
  assert_eq(@symprint.to_string(expectation(sd, rvs=[d])), "DirichletMean(D, 2, 3)")
  assert_eq(@symprint.to_string(variance(sd, rvs=[d])), "DirichletVariance(D, 2, 3)")

  let mc = discrete_markov_chain("MC", params=[@symcore.symbol("Tmat")])
  let t = @symcore.symbol("t")
  match process_mean_at(mc, t) {
    Some(v) => assert_eq(@symprint.to_string(v), "DiscreteMarkovChainMeanAt(t, Tmat)")
    None => fail("missing symbolic process mean")
  }

  let gue = gaussian_unitary_ensemble("GUE", params=[@symcore.int(3)])
  match matrix_density(gue, @symcore.symbol("X")) {
    Some(v) => assert_eq(@symprint.to_string(v), "GaussianUnitaryEnsembleDensity(X, 3)")
    None => fail("missing symbolic matrix density")
  }
}
