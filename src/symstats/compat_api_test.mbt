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
    Some(v) => assert_eq(@symprint.to_string(v), "MatrixStudentTDensity(X, 3, Mean, RowCov, ColCov)")
    None => assert_true(false)
  }

  let mg = matrix_gamma(
    "MG",
    params=[@symcore.int(2), @symcore.int(3), @symcore.symbol("Scale")],
  )
  match matrix_density(mg, @symcore.symbol("X")) {
    Some(v) => assert_eq(@symprint.to_string(v), "MatrixGammaDensity(X, 2, 3, Scale)")
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
test "compat symbolic mgf cf quantile entropy parity" {
  let b = beta("B", params=[@symcore.int(2), @symcore.int(5)])
  let sb = @symcore.symbol("B")
  let t = @symcore.symbol("t")
  let b_mgf = moment_generating_function(sb, t, rvs=[b])
  let b_mgf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda B, t: moment_generating_function(B)(t))(stats.Beta('B', 2, 5), t)",
  )
  assert_true(expr_equiv_to(b_mgf, b_mgf_oracle))
  assert_true(!@symprint.to_string(b_mgf).contains("moment_generating_function("))
  let b_cf = characteristic_function(sb, t, rvs=[b])
  let b_cf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda B, t: characteristic_function(B)(t))(stats.Beta('B', 2, 5), t)",
  )
  assert_true(expr_equiv_to(b_cf, b_cf_oracle))
  assert_true(!@symprint.to_string(b_cf).contains("characteristic_function("))

  let l = logistic("L", params=[@symcore.int(0), @symcore.int(2)])
  let sl = @symcore.symbol("L")
  let q = quantile(sl, try! @symcore.rational_from_ints(1, 4), rvs=[l])
  assert_true(expr_equiv_to(q, "-2*log(3)"))
  assert_true(!@symprint.to_string(q).contains("quantile("))

  let u = uniform("Ue", params=[@symcore.int(1), @symcore.int(3)])
  let su = @symcore.symbol("Ue")
  let ue = entropy(su, rvs=[u])
  let ue_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Ue: entropy(Ue))(stats.Uniform('Ue', 1, 3))",
  )
  assert_true(expr_equiv_to(ue, ue_oracle))
  assert_true(!@symprint.to_string(ue).contains("entropy("))

  let gwe = gumbel("Gwe", params=[@symcore.int(2), @symcore.int(0)])
  let sgwe = @symcore.symbol("Gwe")
  let gwe_q = quantile(sgwe, try! @symcore.rational_from_ints(1, 4), rvs=[gwe])
  assert_true(expr_equiv_to(gwe_q, "-2*log(log(4))"))
  assert_true(!@symprint.to_string(gwe_q).contains("quantile("))

  let laq = laplace("Laq", params=[@symcore.int(0), @symcore.int(2)])
  let slaq = @symcore.symbol("Laq")
  let laq_q = quantile(slaq, try! @symcore.rational_from_ints(1, 4), rvs=[laq])
  assert_true(expr_equiv_to(laq_q, "-2*log(2)"))

  let tq = triangular("Tq", params=[@symcore.int(0), @symcore.int(2), @symcore.int(1)])
  let stq = @symcore.symbol("Tq")
  let tq_q = quantile(stq, try! @symcore.rational_from_ints(1, 4), rvs=[tq])
  assert_true(expr_equiv_to(tq_q, "sqrt(2)/2"))

  let pq = power_function("Pq", params=[@symcore.int(2), @symcore.int(0), @symcore.int(3)])
  let spq = @symcore.symbol("Pq")
  let pq_q = quantile(spq, try! @symcore.rational_from_ints(1, 4), rvs=[pq])
  assert_true(expr_equiv_to(pq_q, "3/2"))

  let trq = trapezoidal(
    "Trq",
    params=[@symcore.int(0), @symcore.int(1), @symcore.int(2), @symcore.int(4)],
  )
  let strq = @symcore.symbol("Trq")
  let trq_q = quantile(strq, try! @symcore.rational_from_ints(1, 4), rvs=[trq])
  assert_true(expr_equiv_to(trq_q, "9/8"))

  let stq2 = student_t("Stq", params=[@symcore.int(5)])
  let sstq2 = @symcore.symbol("Stq")
  let stq2_q = quantile(sstq2, try! @symcore.rational_from_ints(1, 2), rvs=[stq2])
  assert_true(expr_equiv_to(stq2_q, "0"))

  let rcq = reciprocal("Rcq", params=[@symcore.int(1), @symcore.int(3)])
  let srcq = @symcore.symbol("Rcq")
  let rcq_q = quantile(srcq, try! @symcore.rational_from_ints(1, 2), rvs=[rcq])
  assert_true(expr_equiv_to(rcq_q, "sqrt(3)"))
  assert_true(!@symprint.to_string(rcq_q).contains("ReciprocalQuantile("))

  let lmq = lomax("Lmq", params=[@symcore.int(2), @symcore.int(3)])
  let slmq = @symcore.symbol("Lmq")
  let lmq_q = quantile(slmq, try! @symcore.rational_from_ints(1, 4), rvs=[lmq])
  assert_true(expr_equiv_to(lmq_q, "-3 + 2*sqrt(3)"))
  assert_true(!@symprint.to_string(lmq_q).contains("LomaxQuantile("))

  let bwe = beta("Bwe", params=[@symcore.int(2), @symcore.int(5)])
  let sbwe = @symcore.symbol("Bwe")
  let bwe_e = entropy(sbwe, rvs=[bwe])
  let bwe_s = @symprint.to_string(bwe_e)
  assert_true(!bwe_s.contains("Entropy("))
  assert_true(bwe_s.contains("digamma"))

  let rwe = rayleigh("Rwe", params=[@symcore.int(2)])
  let srwe = @symcore.symbol("Rwe")
  let rwe_e = entropy(srwe, rvs=[rwe])
  let rwe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Rwe: entropy(Rwe))(stats.Rayleigh('Rwe', 2))",
  )
  assert_true(expr_equiv_to(rwe_e, rwe_oracle))

  let wwe = weibull("Wwe", params=[@symcore.int(3), @symcore.int(5)])
  let swwe = @symcore.symbol("Wwe")
  let wwe_e = entropy(swwe, rvs=[wwe])
  let wwe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Wwe: entropy(Wwe))(stats.Weibull('Wwe', 3, 5))",
  )
  assert_true(expr_equiv_to(wwe_e, wwe_oracle))

  let lwe = log_normal("Lwe", params=[@symcore.int(0), @symcore.int(2)])
  let slwe = @symcore.symbol("Lwe")
  let lwe_e = entropy(slwe, rvs=[lwe])
  assert_true(expr_equiv_to(lwe_e, "log(2*sqrt(2*pi)) + 1/2"))

  let twe = triangular("Twe", params=[@symcore.int(0), @symcore.int(2), @symcore.int(1)])
  let stwe_twe = @symcore.symbol("Twe")
  let twe_e = entropy(stwe_twe, rvs=[twe])
  let twe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Twe: entropy(Twe))(stats.Triangular('Twe', 0, 2, 1))",
  )
  assert_true(expr_equiv_to(twe_e, twe_oracle))

  let pwe = power_function("Pwe", params=[@symcore.int(2), @symcore.int(0), @symcore.int(3)])
  let spwe = @symcore.symbol("Pwe")
  let pwe_e = entropy(spwe, rvs=[pwe])
  let pwe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Pwe: entropy(Pwe))(stats.PowerFunction('Pwe', 2, 0, 3))",
  )
  assert_true(expr_equiv_to(pwe_e, pwe_oracle))

  let stwe_rv = student_t("Stwe", params=[@symcore.int(5)])
  let sstwe = @symcore.symbol("Stwe")
  let stwe_e = entropy(sstwe, rvs=[stwe_rv])
  assert_true(
    expr_equiv_to(
      stwe_e,
      "3*digamma(3) + -3*digamma(5/2) + log(sqrt(5)*beta(5/2, 1/2))",
    ),
  )

  let vmwe = von_mises("Vmwe", params=[@symcore.int(0), @symcore.int(2)])
  let svmwe = @symcore.symbol("Vmwe")
  let vmwe_e = entropy(svmwe, rvs=[vmwe])
  assert_true(
    expr_equiv_to(
      vmwe_e,
      "log(2*pi*besseli(0, 2)) + -2*besseli(1, 2)*besseli(0, 2)**-1",
    ),
  )

  let trwe = trapezoidal(
    "Trwe",
    params=[@symcore.int(0), @symcore.int(1), @symcore.int(2), @symcore.int(4)],
  )
  let strwe = @symcore.symbol("Trwe")
  let trwe_e = entropy(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_e, "3/10 + log(5/2)"))

  let lmwe = lomax("Lmwe", params=[@symcore.int(2), @symcore.int(3)])
  let slmwe = @symcore.symbol("Lmwe")
  let lmwe_e = entropy(slmwe, rvs=[lmwe])
  let lmwe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Lmwe: entropy(Lmwe))(stats.Lomax('Lmwe', 2, 3))",
  )
  assert_true(expr_equiv_to(lmwe_e, lmwe_oracle))
  assert_true(!@symprint.to_string(lmwe_e).contains("LomaxEntropy("))
}

///|
test "compat generated discrete parity batch" {
  let h = hypergeometric("H", params=[@symcore.int(20), @symcore.int(7), @symcore.int(12)])
  let sh = @symcore.symbol("H")
  let h_pmf = density(h, @symcore.int(3))
  let h_pmf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda H: density(H)(3))(stats.Hypergeometric('H', 20, 7, 12))",
  )
  assert_true(expr_equiv_to(h_pmf, h_pmf_oracle))
  let h_cdf = probability(le(sh, @symcore.int(3)), rv=h)
  let h_cdf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda H: P(H <= 3))(stats.Hypergeometric('H', 20, 7, 12))",
  )
  assert_true(expr_equiv_to(h_cdf, h_cdf_oracle))

  let f = flory_schulz("F", params=[try! @symcore.rational_from_ints(1, 3)])
  let sf = @symcore.symbol("F")
  let t = @symcore.symbol("t")
  let f_mean = expectation(sf, rvs=[f])
  let f_mean_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda F: E(F))(stats.FlorySchulz('F', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(f_mean, f_mean_oracle))
  let f_var = variance(sf, rvs=[f])
  let f_var_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda F: variance(F))(stats.FlorySchulz('F', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(f_var, f_var_oracle))
  let f_mgf = moment_generating_function(sf, t, rvs=[f])
  let f_mgf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda F, t: moment_generating_function(F)(t))(stats.FlorySchulz('F', Rational(1, 3)), t)",
  )
  assert_true(expr_equiv_to(f_mgf, f_mgf_oracle))

  let l = logarithmic("Lx", params=[try! @symcore.rational_from_ints(1, 3)])
  let sl = @symcore.symbol("Lx")
  let l_pmf = density(l, @symcore.int(2))
  let l_pmf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Lx: density(Lx)(2))(stats.Logarithmic('Lx', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(l_pmf, l_pmf_oracle))
  let l_mean = expectation(sl, rvs=[l])
  let l_mean_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Lx: E(Lx))(stats.Logarithmic('Lx', Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(l_mean, l_mean_oracle))

  let s = skellam("Sx", params=[@symcore.int(2), @symcore.int(3)])
  let ssx = @symcore.symbol("Sx")
  let s_pmf = density(s, @symcore.int(1))
  assert_true(expr_equiv_to(s_pmf, "sqrt(2)*sqrt(3)**-1*exp(-5)*besseli(1, 2*sqrt(6))"))
  let s_cf = characteristic_function(ssx, t, rvs=[s])
  let s_cf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Sx, t: characteristic_function(Sx)(t))(stats.Skellam('Sx', 2, 3), t)",
  )
  assert_true(expr_equiv_to(s_cf, s_cf_oracle))

  let y = yule_simon("Yx", params=[@symcore.int(3)])
  let sy = @symcore.symbol("Yx")
  let y_pmf = density(y, @symcore.int(2))
  let y_pmf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Yx: density(Yx)(2))(stats.YuleSimon('Yx', 3))",
  )
  assert_true(expr_equiv_to(y_pmf, y_pmf_oracle))
  let y_mean = expectation(sy, rvs=[y])
  let y_mean_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Yx: E(Yx))(stats.YuleSimon('Yx', 3))",
  )
  assert_true(expr_equiv_to(y_mean, y_mean_oracle))
}

///|
test "compat weibull parity ordering" {
  let w = weibull("W0", params=[@symcore.int(3), @symcore.int(5)])
  let x = @symcore.symbol("x")
  let sw = @symcore.symbol("W0")
  let d = density(w, x)
  let d_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda W0, x: Piecewise((density(W0)(x), Ge(x, 0)), (0, True)))(stats.Weibull('W0', 3, 5), x)",
  )
  assert_true(expr_equiv_to(d, d_oracle))
  let c = cdf(w, x)
  let c_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda W0, x: cdf(W0)(x))(stats.Weibull('W0', 3, 5), x)",
  )
  assert_true(expr_equiv_to(c, c_oracle))
  let m = expectation(sw, rvs=[w])
  let m_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda W0: E(W0))(stats.Weibull('W0', 3, 5))",
  )
  assert_true(expr_equiv_to(m, m_oracle))
  let v = variance(sw, rvs=[w])
  let v_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda W0: variance(W0))(stats.Weibull('W0', 3, 5))",
  )
  assert_true(expr_equiv_to(v, v_oracle))
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
  let bb_pmf = density(bb, @symcore.int(2))
  let bb_pmf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda BB: density(BB)(2))(stats.BetaBinomial('BB', 10, 2, 3))",
  )
  assert_true(expr_equiv_to(bb_pmf, bb_pmf_oracle))
  let bb_cdf = cdf(bb, @symcore.int(2))
  let bb_cdf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda BB: P(BB <= 2))(stats.BetaBinomial('BB', 10, 2, 3))",
  )
  assert_true(expr_equiv_to(bb_cdf, bb_cdf_oracle))

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

  let bp = bernoulli_process("BP", params=[try! @symcore.rational_from_ints(1, 3)])
  let t = @symcore.symbol("t")
  match process_mean_at(bp, t) {
    Some(v) => assert_true(expr_equiv_to(v, "1/3"))
    None => fail("missing bernoulli process mean")
  }
  match process_variance_at(bp, t) {
    Some(v) => assert_true(expr_equiv_to(v, "2/9"))
    None => fail("missing bernoulli process variance")
  }
  match process_transition_probability(
    bp,
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(2),
  ) {
    Some(v) => assert_true(expr_equiv_to(v, "1/3"))
    None => fail("missing bernoulli process transition")
  }
  match process_transition_probability(
    bp,
    @symcore.int(1),
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ) {
    Some(v) => assert_true(expr_equiv_to(v, "2/3"))
    None => fail("missing bernoulli process transition")
  }

  let gp = gamma_process("GP", params=[@symcore.int(2), @symcore.int(3)])
  match process_mean_at(gp, t) {
    Some(v) => {
      let o = try! @sympy_stats.stats_eval_str(
        "(lambda GP, t: E(GP(t)))(stats.GammaProcess('GP', 2, 3), t)",
      )
      assert_true(expr_equiv_to(v, o))
    }
    None => fail("missing gamma process mean")
  }
  match process_variance_at(gp, t) {
    Some(v) => {
      let o = try! @sympy_stats.stats_eval_str(
        "(lambda GP, t: variance(GP(t)))(stats.GammaProcess('GP', 2, 3), t)",
      )
      assert_true(expr_equiv_to(v, o))
    }
    None => fail("missing gamma process variance")
  }
  match process_transition_probability(
    gp,
    @symcore.int(2),
    @symcore.int(5),
    @symcore.int(1),
    @symcore.int(3),
  ) {
    Some(v) => {
      let vs = @symprint.to_string(v)
      assert_true(!vs.contains("GammaProcessTransitionProb"))
      assert_true(vs.contains("Piecewise"))
      assert_true(vs.contains("gamma"))
    }
    None => fail("missing gamma process transition")
  }
}
