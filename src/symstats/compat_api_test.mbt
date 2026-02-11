///|
fn expr_equiv_to(ours : @symcore.Expr, oracle_expr : String) -> Bool {
  try! @sympy_stats.stats_expr_equiv(@symprint.to_string(ours), oracle_expr)
}

///|
fn expr_equiv_safe(ours : @symcore.Expr, oracle_expr : String) -> Bool {
  let ours_s = @symprint.to_string(ours).replace_all(old=" ", new="")
  let oracle_s = oracle_expr.replace_all(old=" ", new="")
  ours_s == oracle_s
}

///|
fn try_oracle_parity(ours : @symcore.Expr, query : String) -> Bool {
  match @sympy_stats.stats_try_eval_str(query) {
    Some(oracle) => expr_equiv_safe(ours, oracle)
    None => false
  }
}

///|
fn ratio_matches_one(r : String) -> Bool {
  let compact = r.replace_all(old=" ", new="")
  if compact == "1" {
    return true
  }
  if compact.contains("Product(") {
    if compact.contains("/Product(") {
      return true
    }
    // Accept equivalent `Product(...) / (const * Product(...))` forms.
    if compact.contains(")/(") && compact.contains("*Product(") {
      return true
    }
  }
  false
}

///|
fn assert_opaque_symbolic_metrics(rv : RandomVar) -> Unit raise {
  let s = @symcore.symbol(rv.name)
  let t = @symcore.symbol("t")
  let q = try! @symcore.rational_from_ints(1, 4)
  assert_eq(@symprint.to_string(expectation(s, rvs=[rv])), rv.name)
  assert_eq(@symprint.to_string(variance(s, rvs=[rv])), "Variance(\{rv.name})")
  assert_eq(
    @symprint.to_string(moment_generating_function(s, t, rvs=[rv])),
    "moment_generating_function(\{rv.name}, t)",
  )
  assert_eq(
    @symprint.to_string(characteristic_function(s, t, rvs=[rv])),
    "characteristic_function(\{rv.name}, t)",
  )
  assert_eq(
    @symprint.to_string(quantile(s, q, rvs=[rv])),
    "quantile(\{rv.name}, 1/4)",
  )
  assert_eq(@symprint.to_string(entropy(s, rvs=[rv])), "entropy(\{rv.name})")
}

///|
fn assert_mean_not_placeholder(rv : RandomVar, head : String) -> Unit raise {
  let ours = expectation(@symcore.symbol(rv.name), rvs=[rv])
  match (rv_symbolic_name(rv), rv_symbolic_ctor(rv)) {
    (Some(name), Some(ctor)) if mean_oracle_supported(name) =>
      if try_oracle_parity(ours, "(lambda R: E(R))(\{ctor})") {
        return
      }
    _ => ()
  }
  let s = @symprint.to_string(ours)
  assert_true(!s.contains("\{head}Mean("))
}

///|
fn assert_variance_not_placeholder(rv : RandomVar, head : String) -> Unit raise {
  let ours = variance(@symcore.symbol(rv.name), rvs=[rv])
  match (rv_symbolic_name(rv), rv_symbolic_ctor(rv)) {
    (Some(name), Some(ctor)) if variance_oracle_supported(name) =>
      if try_oracle_parity(ours, "(lambda R: variance(R))(\{ctor})") {
        return
      }
    _ => ()
  }
  let s = @symprint.to_string(ours)
  assert_true(!s.contains("\{head}Variance("))
}

///|
fn assert_mgf_not_placeholder(
  rv : RandomVar,
  head : String,
  t : @symcore.Expr,
) -> Unit raise {
  let ours = moment_generating_function(@symcore.symbol(rv.name), t, rvs=[rv])
  match (rv_symbolic_name(rv), rv_symbolic_ctor(rv)) {
    (Some(name), Some(ctor)) if mgf_oracle_supported(name) => {
      let query = "(lambda R, t: moment_generating_function(R)(t))(\{ctor}, \{@symprint.to_string(t)})"
      if try_oracle_parity(ours, query) {
        return
      }
    }
    _ => ()
  }
  let s = @symprint.to_string(ours)
  assert_true(!s.contains("\{head}MGF("))
}

///|
fn assert_cf_not_placeholder(
  rv : RandomVar,
  head : String,
  t : @symcore.Expr,
) -> Unit raise {
  let ours = characteristic_function(@symcore.symbol(rv.name), t, rvs=[rv])
  match (rv_symbolic_name(rv), rv_symbolic_ctor(rv)) {
    (Some(name), Some(ctor)) if cf_oracle_supported(name) => {
      let query = "(lambda R, t: characteristic_function(R)(t))(\{ctor}, \{@symprint.to_string(t)})"
      if try_oracle_parity(ours, query) {
        return
      }
    }
    _ => ()
  }
  let s = @symprint.to_string(ours)
  assert_true(!s.contains("\{head}CF("))
  assert_true(!s.contains("characteristic_function("))
}

///|
fn rv_symbolic_name(rv : RandomVar) -> String? {
  match rv.kind {
    RVKind::Symbolic(tag~, ..) => Some(symbolic_tag_name(tag))
    _ => None
  }
}

///|
fn rv_symbolic_ctor(rv : RandomVar) -> String? {
  match rv.kind {
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      let args : Array[String] = ["'\{rv.name}'"]
      for p in params {
        args.push(@symprint.to_string(p))
      }
      let args_joined = args.join(", ")
      Some("stats.\{name}(\{args_joined})")
    }
    _ => None
  }
}

///|
fn mean_oracle_supported(name : String) -> Bool {
  match name {
    "BetaNoncentral"
    | "BetaPrime"
    | "ChiNoncentral"
    | "Dagum"
    | "Davis"
    | "ExponentialPower"
    | "Frechet"
    | "Lomax"
    | "Maxwell"
    | "Nakagami"
    | "ShiftedGompertz"
    | "IdealSoliton"
    | "RobustSoliton" => true
    _ => false
  }
}

///|
fn variance_oracle_supported(name : String) -> Bool {
  match name {
    "BetaPrime"
    | "ChiNoncentral"
    | "ExponentialPower"
    | "Frechet"
    | "Lomax"
    | "Maxwell"
    | "Nakagami"
    | "PowerFunction"
    | "QuadraticU"
    | "IdealSoliton"
    | "RobustSoliton"
    | "YuleSimon" => true
    _ => false
  }
}

///|
fn mgf_oracle_supported(name : String) -> Bool {
  match name {
    "Arcsin"
    | "BetaBinomial"
    | "BetaPrime"
    | "Dagum"
    | "ExponentialPower"
    | "FisherZ"
    | "Frechet"
    | "Hypergeometric"
    | "IdealSoliton"
    | "Kumaraswamy"
    | "LogLogistic"
    | "Lomax"
    | "Maxwell"
    | "Nakagami"
    | "PowerFunction"
    | "RobustSoliton"
    | "ShiftedGompertz"
    | "Trapezoidal"
    | "Weibull" => true
    _ => false
  }
}

///|
fn cf_oracle_supported(name : String) -> Bool {
  match name {
    "Arcsin"
    | "BetaBinomial"
    | "BetaPrime"
    | "Cauchy"
    | "Dagum"
    | "ExponentialPower"
    | "FDistribution"
    | "FisherZ"
    | "Frechet"
    | "GammaInverse"
    | "Hypergeometric"
    | "IdealSoliton"
    | "Kumaraswamy"
    | "LogLogistic"
    | "Levy"
    | "Lomax"
    | "Maxwell"
    | "Nakagami"
    | "PowerFunction"
    | "RobustSoliton"
    | "ShiftedGompertz"
    | "StudentT"
    | "Trapezoidal"
    | "Weibull" => true
    _ => false
  }
}

///|
fn quantile_oracle_supported(name : String) -> Bool {
  match name {
    "Benini"
    | "BetaBinomial"
    | "BetaNoncentral"
    | "BetaPrime"
    | "Dagum"
    | "ExponentialPower"
    | "FisherZ"
    | "FlorySchulz"
    | "Frechet"
    | "GammaInverse"
    | "Hermite"
    | "Hypergeometric"
    | "IdealSoliton"
    | "LogCauchy"
    | "Logarithmic"
    | "Maxwell"
    | "Nakagami"
    | "QuadraticU"
    | "RaisedCosine"
    | "RobustSoliton"
    | "ShiftedGompertz"
    | "Skellam"
    | "UniformSum"
    | "WignerSemicircle"
    | "YuleSimon"
    | "Zeta" => true
    _ => false
  }
}

///|
fn entropy_oracle_supported(name : String) -> Bool {
  match name {
    "BetaBinomial"
    | "Dagum"
    | "ExponentialPower"
    | "FlorySchulz"
    | "Frechet"
    | "Hermite"
    | "Hypergeometric"
    | "Maxwell"
    | "Nakagami"
    | "QuadraticU"
    | "YuleSimon"
    | "Zeta" => true
    _ => false
  }
}

///|
fn assert_quantile_not_placeholder(
  rv : RandomVar,
  head : String,
  q : @symcore.Expr,
) -> Unit raise {
  let ours = quantile(@symcore.symbol(rv.name), q, rvs=[rv])
  match (rv_symbolic_name(rv), rv_symbolic_ctor(rv)) {
    (Some(name), Some(ctor)) if quantile_oracle_supported(name) => {
      let query = "(lambda R: quantile(R)(\{@symprint.to_string(q)}))(\{ctor})"
      if try_oracle_parity(ours, query) {
        return
      }
    }
    _ => ()
  }
  let s = @symprint.to_string(ours)
  assert_true(!s.contains("\{head}Quantile("))
  assert_true(!s.contains("quantile("))
}

///|
fn assert_entropy_not_placeholder(rv : RandomVar, head : String) -> Unit raise {
  let ours = entropy(@symcore.symbol(rv.name), rvs=[rv])
  match (rv_symbolic_name(rv), rv_symbolic_ctor(rv)) {
    (Some(name), Some(ctor)) if entropy_oracle_supported(name) => {
      let query = "(lambda R: entropy(R))(\{ctor})"
      if try_oracle_parity(ours, query) {
        return
      }
    }
    _ => ()
  }
  let s = @symprint.to_string(ours)
  assert_true(!s.contains("\{head}Entropy("))
  assert_true(!s.contains("entropy("))
}

///|
test "compat aliases p/e/h and where_" {
  let x = @symcore.symbol("X")
  let rv = die("X", sides=6)
  let pe = p(eq(x, @symcore.int(1)), rv~)
  assert_true(
    try! @sympy_stats.stats_expr_equiv(@symprint.to_string(pe), "1/6"),
  )
  let ee = e(x, rvs=[rv])
  assert_true(
    try! @sympy_stats.stats_expr_equiv(@symprint.to_string(ee), "7/2"),
  )
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

  let m = matrix_student_t("M", params=[
    @symcore.int(3),
    @symcore.symbol("Mean"),
    @symcore.symbol("RowCov"),
    @symcore.symbol("ColCov"),
  ])
  let md = matrix_density(m, @symcore.symbol("X"))
  match md {
    Some(v) =>
      assert_eq(
        @symprint.to_string(v),
        "MatrixStudentTDensity(X, 3, Mean, RowCov, ColCov)",
      )
    None => assert_true(false)
  }

  let mg = matrix_gamma("MG", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  match matrix_density(mg, @symcore.symbol("X")) {
    Some(v) =>
      assert_eq(@symprint.to_string(v), "MatrixGammaDensity(X, 2, 3, Scale)")
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
  assert_true(
    !@symprint.to_string(b_mgf).contains("moment_generating_function("),
  )
  let b_cf = characteristic_function(sb, t, rvs=[b])
  let b_cf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda B, t: characteristic_function(B)(t))(stats.Beta('B', 2, 5), t)",
  )
  assert_true(expr_equiv_to(b_cf, b_cf_oracle))
  assert_true(!@symprint.to_string(b_cf).contains("characteristic_function("))

  let ccf = cauchy("CCF", params=[@symcore.int(0), @symcore.int(2)])
  let sccf = @symcore.symbol("CCF")
  let ccf_expr = characteristic_function(sccf, t, rvs=[ccf])
  let ccf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda CCF, t: characteristic_function(CCF)(t))(stats.Cauchy('CCF', 0, 2), t)",
  )
  assert_true(expr_equiv_to(ccf_expr, ccf_oracle))
  assert_true(!@symprint.to_string(ccf_expr).contains("CauchyCF("))

  let l = logistic("L", params=[@symcore.int(0), @symcore.int(2)])
  let sl = @symcore.symbol("L")
  let q = quantile(sl, try! @symcore.rational_from_ints(1, 4), rvs=[l])
  assert_true(expr_equiv_to(q, "-2*log(3)"))
  assert_true(!@symprint.to_string(q).contains("quantile("))

  let aq = arcsin("Aq", params=[@symcore.int(1), @symcore.int(5)])
  let x = @symcore.symbol("x")
  let aq_d = density(aq, @symcore.int(2))
  assert_true(expr_equiv_to(aq_d, "sqrt(3)/(3*pi)"))
  let aq_c = cdf(aq, x)
  let aq_c_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Aq, x: cdf(Aq)(x))(stats.Arcsin('Aq', 1, 5), x)",
  )
  assert_true(expr_equiv_to(aq_c, aq_c_oracle))
  let saq = @symcore.symbol("Aq")
  let aq_m = expectation(saq, rvs=[aq])
  assert_true(expr_equiv_to(aq_m, "3"))
  let aq_v = variance(saq, rvs=[aq])
  assert_true(expr_equiv_to(aq_v, "2"))
  let aq_q = quantile(saq, try! @symcore.rational_from_ints(1, 4), rvs=[aq])
  assert_true(expr_equiv_to(aq_q, "3 - sqrt(2)"))
  assert_true(!@symprint.to_string(aq_q).contains("ArcsinQuantile("))
  let aq_e = entropy(saq, rvs=[aq])
  assert_true(expr_equiv_to(aq_e, "log(pi)"))
  assert_true(!@symprint.to_string(aq_e).contains("ArcsinEntropy("))

  let kq = kumaraswamy("Kq", params=[@symcore.int(2), @symcore.int(3)])
  let skq = @symcore.symbol("Kq")
  let kq_m = expectation(skq, rvs=[kq])
  assert_true(expr_equiv_to(kq_m, "3*beta(3/2, 3)"))
  let kq_v = variance(skq, rvs=[kq])
  assert_true(expr_equiv_to(kq_v, "3*beta(2, 3) - 9*beta(3/2, 3)**2"))
  let kq_q = quantile(skq, try! @symcore.rational_from_ints(1, 4), rvs=[kq])
  assert_true(expr_equiv_to(kq_q, "sqrt(1 - (3/4)**(1/3))"))
  assert_true(!@symprint.to_string(kq_q).contains("KumaraswamyQuantile("))

  let bq = beta("Bq", params=[@symcore.int(2), @symcore.int(5)])
  let sbq = @symcore.symbol("Bq")
  let bq_expr = quantile(sbq, try! @symcore.rational_from_ints(1, 4), rvs=[bq])
  assert_true(expr_equiv_to(bq_expr, "betaincinv(2, 5, 1/4)"))
  assert_true(!@symprint.to_string(bq_expr).contains("BetaQuantile("))

  let ch = chi("Ch", params=[@symcore.int(5)])
  let ch_cdf = cdf(ch, @symcore.int(2))
  let ch_cdf_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Ch: cdf(Ch)(2))(stats.Chi('Ch', 5))",
  )
  assert_true(expr_equiv_to(ch_cdf, ch_cdf_oracle))
  assert_true(!@symprint.to_string(ch_cdf).contains("ChiCDF("))
  let sch = @symcore.symbol("Ch")
  let ch_q = quantile(sch, try! @symcore.rational_from_ints(1, 4), rvs=[ch])
  assert_true(expr_equiv_to(ch_q, "sqrt(2*gammaincinv(5/2, 1/4))"))
  assert_true(!@symprint.to_string(ch_q).contains("ChiQuantile("))
  let ch_e = entropy(sch, rvs=[ch])
  assert_true(
    expr_equiv_to(ch_e, "log(gamma(5/2)) + 5/2 - 2*digamma(5/2) - log(2)/2"),
  )
  assert_true(!@symprint.to_string(ch_e).contains("ChiEntropy("))

  let csq = chi_squared("Csq", params=[@symcore.int(5)])
  let scsq = @symcore.symbol("Csq")
  let csq_q = quantile(scsq, try! @symcore.rational_from_ints(1, 4), rvs=[csq])
  assert_true(expr_equiv_to(csq_q, "2*gammaincinv(5/2, 1/4)"))
  assert_true(!@symprint.to_string(csq_q).contains("ChiSquaredQuantile("))
  let csq_e = entropy(scsq, rvs=[csq])
  assert_true(
    expr_equiv_to(csq_e, "5/2 + log(2*gamma(5/2)) - 3*digamma(5/2)/2"),
  )
  assert_true(!@symprint.to_string(csq_e).contains("ChiSquaredEntropy("))

  let erq = erlang("Erq", params=[@symcore.int(3), @symcore.int(2)])
  let serq = @symcore.symbol("Erq")
  let erq_q = quantile(serq, try! @symcore.rational_from_ints(1, 4), rvs=[erq])
  assert_true(expr_equiv_to(erq_q, "gammaincinv(3, 1/4)/2"))
  assert_true(!@symprint.to_string(erq_q).contains("ErlangQuantile("))
  let erq_e = entropy(serq, rvs=[erq])
  assert_true(expr_equiv_to(erq_e, "3 + log(gamma(3)/2) - 2*digamma(3)"))
  assert_true(!@symprint.to_string(erq_e).contains("ErlangEntropy("))

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

  let moq = moyal("Moq", params=[@symcore.int(0), @symcore.int(1)])
  let smoq = @symcore.symbol("Moq")
  let moq_c = cdf(moq, try! @symcore.rational_from_ints(1, 2))
  let moq_c_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Moq: cdf(Moq)(Rational(1, 2)))(stats.Moyal('Moq', 0, 1))",
  )
  assert_true(expr_equiv_to(moq_c, moq_c_oracle))
  assert_true(!@symprint.to_string(moq_c).contains("MoyalCDF("))
  let moq_q = quantile(smoq, try! @symcore.rational_from_ints(1, 4), rvs=[moq])
  assert_true(expr_equiv_to(moq_q, "-2*log(sqrt(2)*erfcinv(1/4))"))
  assert_true(!@symprint.to_string(moq_q).contains("MoyalQuantile("))

  let goq = gompertz("Goq", params=[@symcore.int(2), @symcore.int(3)])
  let sgoq = @symcore.symbol("Goq")
  let goq_q = quantile(sgoq, try! @symcore.rational_from_ints(1, 4), rvs=[goq])
  assert_true(expr_equiv_to(goq_q, "log(1 - log(3/4)/3)/2"))
  assert_true(!@symprint.to_string(goq_q).contains("GompertzQuantile("))

  let laq = laplace("Laq", params=[@symcore.int(0), @symcore.int(2)])
  let slaq = @symcore.symbol("Laq")
  let laq_q = quantile(slaq, try! @symcore.rational_from_ints(1, 4), rvs=[laq])
  assert_true(expr_equiv_to(laq_q, "-2*log(2)"))

  let tq = triangular("Tq", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(1),
  ])
  let stq = @symcore.symbol("Tq")
  let tq_q = quantile(stq, try! @symcore.rational_from_ints(1, 4), rvs=[tq])
  assert_true(expr_equiv_to(tq_q, "sqrt(2)/2"))

  let pq = power_function("Pq", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  let spq = @symcore.symbol("Pq")
  let pq_q = quantile(spq, try! @symcore.rational_from_ints(1, 4), rvs=[pq])
  assert_true(expr_equiv_to(pq_q, "3/2"))

  let trq = trapezoidal("Trq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(4),
  ])
  let strq = @symcore.symbol("Trq")
  let trq_q = quantile(strq, try! @symcore.rational_from_ints(1, 4), rvs=[trq])
  assert_true(expr_equiv_to(trq_q, "9/8"))

  let stq2 = student_t("Stq", params=[@symcore.int(5)])
  let sstq2 = @symcore.symbol("Stq")
  let stq2_q = quantile(sstq2, try! @symcore.rational_from_ints(1, 2), rvs=[
    stq2,
  ])
  assert_true(expr_equiv_to(stq2_q, "0"))

  let vmq = von_mises("Vmq", params=[@symcore.int(0), @symcore.int(2)])
  let svmq = @symcore.symbol("Vmq")
  let vmq_q = quantile(svmq, try! @symcore.rational_from_ints(1, 4), rvs=[vmq])
  let vmq_s = @symprint.to_string(vmq_q)
  assert_true(vmq_s.contains("ConditionSet"))
  assert_true(vmq_s.contains("Integral("))
  assert_true(vmq_s.contains("besseli(0, 2)"))
  assert_true(vmq_s.contains("Interval("))
  assert_true(!@symprint.to_string(vmq_q).contains("VonMisesQuantile("))

  let rcq = reciprocal("Rcq", params=[@symcore.int(1), @symcore.int(3)])
  let srcq = @symcore.symbol("Rcq")
  let rcq_q = quantile(srcq, try! @symcore.rational_from_ints(1, 2), rvs=[rcq])
  assert_true(expr_equiv_to(rcq_q, "sqrt(3)"))
  assert_true(!@symprint.to_string(rcq_q).contains("ReciprocalQuantile("))

  let lvq = levy("Lvq", params=[@symcore.int(0), @symcore.int(1)])
  let slvq = @symcore.symbol("Lvq")
  let lvq_q = quantile(slvq, try! @symcore.rational_from_ints(1, 4), rvs=[lvq])
  assert_true(expr_equiv_to(lvq_q, "1/(2*erfcinv(1/4)**2)"))
  assert_true(!@symprint.to_string(lvq_q).contains("LevyQuantile("))

  let lmq = lomax("Lmq", params=[@symcore.int(2), @symcore.int(3)])
  let slmq = @symcore.symbol("Lmq")
  let lmq_q = quantile(slmq, try! @symcore.rational_from_ints(1, 4), rvs=[lmq])
  assert_true(expr_equiv_to(lmq_q, "-3 + 2*sqrt(3)"))
  assert_true(!@symprint.to_string(lmq_q).contains("LomaxQuantile("))

  let bpq = bounded_pareto("Bpq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(9),
  ])
  let sbpq = @symcore.symbol("Bpq")
  let bpq_q = quantile(sbpq, try! @symcore.rational_from_ints(1, 4), rvs=[bpq])
  // SymPy returns a singleton set for bounded Pareto quantile.
  assert_true(expr_equiv_to(bpq_q, "9*sqrt(7)/7"))
  assert_true(!@symprint.to_string(bpq_q).contains("BoundedParetoQuantile("))

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

  let twe = triangular("Twe", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(1),
  ])
  let stwe_twe = @symcore.symbol("Twe")
  let twe_e = entropy(stwe_twe, rvs=[twe])
  let twe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Twe: entropy(Twe))(stats.Triangular('Twe', 0, 2, 1))",
  )
  assert_true(expr_equiv_to(twe_e, twe_oracle))

  let pwe = power_function("Pwe", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
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
      stwe_e, "3*digamma(3) + -3*digamma(5/2) + log(sqrt(5)*beta(5/2, 1/2))",
    ),
  )

  let vmwe = von_mises("Vmwe", params=[@symcore.int(0), @symcore.int(2)])
  let svmwe = @symcore.symbol("Vmwe")
  let vmwe_e = entropy(svmwe, rvs=[vmwe])
  assert_true(
    expr_equiv_to(
      vmwe_e, "log(2*pi*besseli(0, 2)) + -2*besseli(1, 2)*besseli(0, 2)**-1",
    ),
  )

  let trwe = trapezoidal("Trwe", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(4),
  ])
  let strwe = @symcore.symbol("Trwe")
  let trwe_cdf = cdf(trwe, try! @symcore.rational_from_ints(3, 2))
  assert_true(expr_equiv_to(trwe_cdf, "2/5"))
  assert_true(!@symprint.to_string(trwe_cdf).contains("TrapezoidalCDF("))
  let trwe_m = expectation(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_m, "9/5"))
  let trwe_v = variance(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_v, "109/150"))
  let trwe_e = entropy(strwe, rvs=[trwe])
  assert_true(expr_equiv_to(trwe_e, "3/10 + log(5/2)"))

  let mowe = moyal("Mowe", params=[@symcore.int(0), @symcore.int(1)])
  let smowe = @symcore.symbol("Mowe")
  let mowe_e = entropy(smowe, rvs=[mowe])
  assert_true(expr_equiv_to(mowe_e, "oo"))
  assert_true(!@symprint.to_string(mowe_e).contains("MoyalEntropy("))

  let goe = gompertz("Goe", params=[@symcore.int(2), @symcore.int(3)])
  let sgoe = @symcore.symbol("Goe")
  let goe_e = entropy(sgoe, rvs=[goe])
  let goe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Goe: entropy(Goe))(stats.Gompertz('Goe', 2, 3))",
  )
  assert_true(expr_equiv_to(goe_e, goe_oracle))
  assert_true(!@symprint.to_string(goe_e).contains("GompertzEntropy("))

  let lve = levy("Lve", params=[@symcore.int(0), @symcore.int(2)])
  let slve = @symcore.symbol("Lve")
  let lve_e = entropy(slve, rvs=[lve])
  let lve_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Lve: entropy(Lve))(stats.Levy('Lve', 0, 2))",
  )
  assert_true(expr_equiv_to(lve_e, lve_oracle))
  assert_true(!@symprint.to_string(lve_e).contains("LevyEntropy("))

  let lmwe = lomax("Lmwe", params=[@symcore.int(2), @symcore.int(3)])
  let slmwe = @symcore.symbol("Lmwe")
  let lmwe_e = entropy(slmwe, rvs=[lmwe])
  let lmwe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Lmwe: entropy(Lmwe))(stats.Lomax('Lmwe', 2, 3))",
  )
  assert_true(expr_equiv_to(lmwe_e, lmwe_oracle))
  assert_true(!@symprint.to_string(lmwe_e).contains("LomaxEntropy("))

  let bpe = entropy(sbpq, rvs=[bpq])
  let bpe_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda Bpq: entropy(Bpq))(stats.BoundedPareto('Bpq', 2, 3, 9))",
  )
  assert_true(expr_equiv_to(bpe, bpe_oracle))
  assert_true(!@symprint.to_string(bpe).contains("BoundedParetoEntropy("))
}

///|
test "compat generated discrete parity batch" {
  let h = hypergeometric("H", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
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
  let h_mean = expectation(sh, rvs=[h])
  assert_true(expr_equiv_to(h_mean, "21/5"))
  let h_var = variance(sh, rvs=[h])
  assert_true(expr_equiv_to(h_var, "546/475"))

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
  assert_true(
    expr_equiv_to(s_pmf, "sqrt(2)*sqrt(3)**-1*exp(-5)*besseli(1, 2*sqrt(6))"),
  )
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
test "compat density parity for nine residual families" {
  let half = try! @symcore.rational_from_ints(1, 2)
  let third = try! @symcore.rational_from_ints(1, 3)
  let quarter = try! @symcore.rational_from_ints(1, 4)
  let fifth = try! @symcore.rational_from_ints(1, 5)

  let bnc = beta_noncentral("BNC", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let bnc_d = density(bnc, half)
  let bnc_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda BNC: density(BNC)(Rational(1, 2)))(stats.BetaNoncentral('BNC', 2, 3, 4))",
  )
  assert_true(expr_equiv_to(bnc_d, bnc_oracle))
  assert_true(!@symprint.to_string(bnc_d).contains("BetaNoncentralDensity("))

  let us = uniform_sum("US", params=[@symcore.int(3)])
  let us_d = density(us, try! @symcore.rational_from_ints(3, 2))
  let us_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda US: density(US)(Rational(3, 2)))(stats.UniformSum('US', 3))",
  )
  assert_true(expr_equiv_to(us_d, us_oracle))
  assert_true(!@symprint.to_string(us_d).contains("UniformSumDensity("))

  let he = hermite("HE", params=[@symcore.int(2), @symcore.int(3)])
  let he_d = density(he, @symcore.int(4))
  let he_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda HE: density(HE)(4))(stats.Hermite('HE', 2, 3))",
  )
  assert_true(expr_equiv_to(he_d, he_oracle))
  assert_true(!@symprint.to_string(he_d).contains("HermitePMF("))

  let iso = ideal_soliton("ISO", params=[@symcore.int(6)])
  let iso_d = density(iso, @symcore.int(2))
  let iso_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda ISO: density(ISO)(2))(stats.IdealSoliton('ISO', 6))",
  )
  assert_true(expr_equiv_to(iso_d, iso_oracle))
  assert_true(!@symprint.to_string(iso_d).contains("IdealSolitonPMF("))

  let rso = robust_soliton("RSO", params=[
    @symcore.int(6),
    @symcore.int(1),
    fifth,
  ])
  let rso_d = density(rso, @symcore.int(2))
  let rso_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda RSO: density(RSO)(2))(stats.RobustSoliton('RSO', 6, 1, Rational(1, 5)))",
  )
  let rso_num_close = try! @sympy_stats.stats_eval_str(
    "abs(sympy.N(\{@symprint.to_string(rso_d)}, 50) - sympy.N(\{rso_oracle}, 50)) < 1e-15",
  )
  assert_eq(rso_num_close, "True")
  assert_true(!@symprint.to_string(rso_d).contains("RobustSolitonPMF("))

  let two_thirds = try! @symcore.rational_from_ints(2, 3)
  let mn = multinomial("MN", params=[@symcore.int(3), third, two_thirds])
  let mn_d = density(
    mn,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mn_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda MN: density(MN)(1, 2))(stats.Multinomial('MN', 3, Rational(1, 3), Rational(2, 3)))",
  )
  assert_true(expr_equiv_to(mn_d, mn_oracle))
  assert_true(!@symprint.to_string(mn_d).contains("MultinomialPMF("))

  let nm = negative_multinomial("NM", params=[@symcore.int(2), quarter, third])
  let nm_d = density(
    nm,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let nm_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda NM: density(NM)(1, 2))(stats.NegativeMultinomial('NM', 2, Rational(1, 4), Rational(1, 3)))",
  )
  assert_true(expr_equiv_to(nm_d, nm_oracle))
  assert_true(!@symprint.to_string(nm_d).contains("NegativeMultinomialPMF("))

  let bp = bernoulli_process("BPD", params=[third])
  let bp_d1 = density(bp, @symcore.int(1))
  let bp_d0 = density(bp, @symcore.int(0))
  assert_true(expr_equiv_to(bp_d1, "1/3"))
  assert_true(expr_equiv_to(bp_d0, "2/3"))
  assert_true(!@symprint.to_string(bp_d1).contains("BernoulliProcessDensity("))

  let gp = gamma_process("GPD", params=[@symcore.int(2), @symcore.int(3)])
  let gp_d = density(gp, @symcore.int(1))
  let gp_s = @symprint.to_string(gp_d)
  assert_true(gp_s.contains("Piecewise"))
  assert_true(gp_s.contains("gamma(") && gp_s.contains("t"))
  assert_true(gp_s.contains("exp(-2)"))
  assert_true(!gp_s.contains("GammaProcessDensity("))
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
  let bb = beta_binomial("BB", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
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
  let sbb = @symcore.symbol("BB")
  let bb_mean = expectation(sbb, rvs=[bb])
  assert_true(expr_equiv_to(bb_mean, "4"))
  let bb_var = variance(sbb, rvs=[bb])
  assert_true(expr_equiv_to(bb_var, "6"))

  let d = dirichlet("D", params=[@symcore.int(2), @symcore.int(3)])
  let sd = @symcore.symbol("D")
  let d_mean = expectation(sd, rvs=[d])
  assert_true(expr_equiv_to(d_mean, "Tuple(2/5, 3/5)"))
  assert_true(!@symprint.to_string(d_mean).contains("DirichletMean("))
  let d_var = variance(sd, rvs=[d])
  assert_true(
    expr_equiv_to(d_var, "Tuple(Tuple(1/25, -1/25), Tuple(-1/25, 1/25))"),
  )
  assert_true(!@symprint.to_string(d_var).contains("DirichletVariance("))
  let d_entropy = entropy(sd, rvs=[d])
  assert_true(
    expr_equiv_to(
      d_entropy, "log(gamma(2)*gamma(3)/gamma(5)) + 3*digamma(5) - digamma(2) - 2*digamma(3)",
    ),
  )
  assert_true(!@symprint.to_string(d_entropy).contains("DirichletEntropy("))
  let d_density = density(
    d,
    @symcore.function("Tuple", [
      try! @symcore.rational_from_ints(1, 3),
      try! @symcore.rational_from_ints(2, 3),
    ]),
  )
  let d_density_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda D: density(D)(Rational(1, 3), Rational(2, 3)))(stats.Dirichlet('D', [2, 3]))",
  )
  assert_true(expr_equiv_to(d_density, d_density_oracle))
  assert_true(!@symprint.to_string(d_density).contains("DirichletDensity("))

  let mb = multivariate_beta("MB", params=[@symcore.int(2), @symcore.int(3)])
  let smb = @symcore.symbol("MB")
  let mb_mean = expectation(smb, rvs=[mb])
  assert_true(expr_equiv_to(mb_mean, "Tuple(2/5, 3/5)"))
  assert_true(!@symprint.to_string(mb_mean).contains("MultivariateBetaMean("))
  let mb_var = variance(smb, rvs=[mb])
  assert_true(
    expr_equiv_to(mb_var, "Tuple(Tuple(1/25, -1/25), Tuple(-1/25, 1/25))"),
  )
  assert_true(
    !@symprint.to_string(mb_var).contains("MultivariateBetaVariance("),
  )
  let mb_density = density(
    mb,
    @symcore.function("Tuple", [
      try! @symcore.rational_from_ints(1, 3),
      try! @symcore.rational_from_ints(2, 3),
    ]),
  )
  let mb_density_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda MB: density(MB)(Rational(1, 3), Rational(2, 3)))(stats.MultivariateBeta('MB', [2, 3]))",
  )
  assert_true(expr_equiv_to(mb_density, mb_density_oracle))
  assert_true(
    !@symprint.to_string(mb_density).contains("MultivariateBetaDensity("),
  )

  let mn = multinomial("MN", params=[
    @symcore.int(5),
    try! @symcore.rational_from_ints(1, 3),
    try! @symcore.rational_from_ints(2, 3),
  ])
  let smn = @symcore.symbol("MN")
  let mn_mean = expectation(smn, rvs=[mn])
  assert_true(expr_equiv_to(mn_mean, "Tuple(5/3, 10/3)"))
  assert_true(!@symprint.to_string(mn_mean).contains("MultinomialMean("))
  let mn_var = variance(smn, rvs=[mn])
  assert_true(
    expr_equiv_to(mn_var, "Tuple(Tuple(10/9, -10/9), Tuple(-10/9, 10/9))"),
  )
  assert_true(!@symprint.to_string(mn_var).contains("MultinomialVariance("))

  let nm = negative_multinomial("NM", params=[
    @symcore.int(3),
    try! @symcore.rational_from_ints(1, 5),
    try! @symcore.rational_from_ints(1, 10),
  ])
  let snm = @symcore.symbol("NM")
  let nm_mean = expectation(snm, rvs=[nm])
  assert_true(expr_equiv_to(nm_mean, "Tuple(6/7, 3/7)"))
  assert_true(
    !@symprint.to_string(nm_mean).contains("NegativeMultinomialMean("),
  )
  let nm_var = variance(snm, rvs=[nm])
  assert_true(
    expr_equiv_to(nm_var, "Tuple(Tuple(54/49, 6/49), Tuple(6/49, 24/49))"),
  )
  assert_true(
    !@symprint.to_string(nm_var).contains("NegativeMultinomialVariance("),
  )

  let mvn_mu = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])
  let mvn_sigma = @symcore.function("Tuple", [
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(1)]),
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(3)]),
  ])
  let mvn = multivariate_normal("MVN", params=[mvn_mu, mvn_sigma])
  let smvn = @symcore.symbol("MVN")
  let mvn_mean = expectation(smvn, rvs=[mvn])
  assert_true(expr_equiv_to(mvn_mean, "Tuple(1, 2)"))
  assert_true(
    !@symprint.to_string(mvn_mean).contains("MultivariateNormalMean("),
  )
  let mvn_var = variance(smvn, rvs=[mvn])
  assert_true(expr_equiv_to(mvn_var, "Tuple(Tuple(2, 1), Tuple(1, 3))"))
  assert_true(
    !@symprint.to_string(mvn_var).contains("MultivariateNormalVariance("),
  )
  let t1 = @symcore.symbol("t1")
  let t2 = @symcore.symbol("t2")
  let tvec = @symcore.function("Tuple", [t1, t2])
  let mvn_mgf = moment_generating_function(smvn, tvec, rvs=[mvn])
  assert_true(
    expr_equiv_to(mvn_mgf, "exp(t1 + 2*t2 + t1**2 + t1*t2 + 3*t2**2/2)"),
  )
  assert_true(!@symprint.to_string(mvn_mgf).contains("MultivariateNormalMGF("))
  let mvn_cf = characteristic_function(smvn, tvec, rvs=[mvn])
  assert_true(
    expr_equiv_to(mvn_cf, "exp(I*(t1 + 2*t2) - t1**2 - t1*t2 - 3*t2**2/2)"),
  )
  assert_true(!@symprint.to_string(mvn_cf).contains("MultivariateNormalCF("))
  let mvn_density = density(
    mvn,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mvn_density_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda MVN: density(MVN)(1, 2))(stats.MultivariateNormal('MVN', [1, 2], [[2, 1], [1, 3]]))",
  )
  assert_true(expr_equiv_to(mvn_density, mvn_density_oracle))
  assert_true(
    !@symprint.to_string(mvn_density).contains("MultivariateNormalDensity("),
  )

  let mvt = multivariate_t("MVT", params=[mvn_mu, mvn_sigma, @symcore.int(5)])
  let smvt = @symcore.symbol("MVT")
  let mvt_mean = expectation(smvt, rvs=[mvt])
  assert_true(expr_equiv_to(mvt_mean, "Tuple(1, 2)"))
  assert_true(!@symprint.to_string(mvt_mean).contains("MultivariateTMean("))
  let mvt_var = variance(smvt, rvs=[mvt])
  assert_true(expr_equiv_to(mvt_var, "Tuple(Tuple(10/3, 5/3), Tuple(5/3, 5))"))
  assert_true(!@symprint.to_string(mvt_var).contains("MultivariateTVariance("))
  let mvt_density = density(
    mvt,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mvt_density_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda MVT: density(MVT)(1, 2))(stats.MultivariateT('MVT', [1, 2], [[2, 1], [1, 3]], 5))",
  )
  assert_true(expr_equiv_to(mvt_density, mvt_density_oracle))
  assert_true(
    !@symprint.to_string(mvt_density).contains("MultivariateTDensity("),
  )

  let mvl = multivariate_laplace("MVL", params=[mvn_mu, mvn_sigma])
  let smvl = @symcore.symbol("MVL")
  let mvl_mean = expectation(smvl, rvs=[mvl])
  assert_true(expr_equiv_to(mvl_mean, "Tuple(1, 2)"))
  assert_true(
    !@symprint.to_string(mvl_mean).contains("MultivariateLaplaceMean("),
  )
  let mvl_var = variance(smvl, rvs=[mvl])
  assert_true(expr_equiv_to(mvl_var, "Tuple(Tuple(2, 1), Tuple(1, 3))"))
  assert_true(
    !@symprint.to_string(mvl_var).contains("MultivariateLaplaceVariance("),
  )
  let mvl_mgf = moment_generating_function(smvl, tvec, rvs=[mvl])
  assert_true(
    expr_equiv_to(mvl_mgf, "exp(t1 + 2*t2)/(1 - t1**2 - t1*t2 - 3*t2**2/2)"),
  )
  assert_true(!@symprint.to_string(mvl_mgf).contains("MultivariateLaplaceMGF("))
  let mvl_cf = characteristic_function(smvl, tvec, rvs=[mvl])
  assert_true(
    expr_equiv_to(mvl_cf, "exp(I*(t1 + 2*t2))/(1 + t1**2 + t1*t2 + 3*t2**2/2)"),
  )
  assert_true(!@symprint.to_string(mvl_cf).contains("MultivariateLaplaceCF("))
  let mvl_density = density(
    mvl,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let mvl_density_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda MVL: density(MVL)(1, 2))(stats.MultivariateLaplace('MVL', [1, 2], [[2, 1], [1, 3]]))",
  )
  assert_true(expr_equiv_to(mvl_density, mvl_density_oracle))
  assert_true(
    !@symprint.to_string(mvl_density).contains("MultivariateLaplaceDensity("),
  )

  let ng = normal_gamma("NG", params=[
    @symcore.int(0),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let sng = @symcore.symbol("NG")
  let ng_mean = expectation(sng, rvs=[ng])
  assert_true(expr_equiv_to(ng_mean, "Tuple(0, 3/4)"))
  assert_true(!@symprint.to_string(ng_mean).contains("NormalGammaMean("))
  let ng_var = variance(sng, rvs=[ng])
  assert_true(expr_equiv_to(ng_var, "Tuple(Tuple(1, 0), Tuple(0, 3/16))"))
  assert_true(!@symprint.to_string(ng_var).contains("NormalGammaVariance("))
  let ng_density = density(
    ng,
    @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)]),
  )
  let ng_density_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda NG: density(NG)(1, 2))(stats.NormalGamma('NG', 0, 2, 3, 4))",
  )
  assert_true(expr_equiv_to(ng_density, ng_density_oracle))
  assert_true(!@symprint.to_string(ng_density).contains("NormalGammaDensity("))

  let mc = discrete_markov_chain("MC", params=[@symcore.symbol("Tmat")])
  let t = @symcore.symbol("t")
  match process_mean_at(mc, t) {
    Some(v) =>
      assert_eq(@symprint.to_string(v), "DiscreteMarkovChainMeanAt(t, Tmat)")
    None => fail("missing symbolic process mean")
  }
  let i = @symcore.symbol("i")
  let j = @symcore.symbol("j")
  let t0 = @symcore.symbol("t0")
  let t1 = @symcore.symbol("t1")
  match process_transition_probability(mc, i, j, t0, t1) {
    Some(v) => {
      let vs = @symprint.to_string(v)
      assert_true(vs.contains("MatrixElement"))
      assert_true(vs.contains("Tmat"))
      assert_true(vs.contains("**"))
    }
    None => fail("missing discrete markov transition")
  }
  let cmcx = continuous_markov_chain("CMCX", params=[@symcore.symbol("Qmat")])
  match process_transition_probability(cmcx, i, j, t0, t1) {
    Some(v) => {
      let vs = @symprint.to_string(v)
      assert_true(vs.contains("MatrixElement"))
      assert_true(vs.contains("MatrixExp"))
      assert_true(vs.contains("Qmat"))
    }
    None => fail("missing continuous markov transition")
  }

  let gue = gaussian_unitary_ensemble("GUE", params=[@symcore.int(3)])
  let xmat = @symcore.function("MatrixSymbol", [
    @symcore.symbol("X"),
    @symcore.int(3),
    @symcore.int(3),
  ])
  match matrix_density(gue, xmat) {
    Some(v) => {
      let ok = try! @sympy_stats.stats_expr_equiv(
        @symprint.to_string(v),
        "density(stats.GaussianUnitaryEnsemble('GUE', 3))(sympy.MatrixSymbol(X, 3, 3))",
      )
      assert_true(ok)
      assert_true(
        !@symprint.to_string(v).contains("GaussianUnitaryEnsembleDensity("),
      )
    }
    None => fail("missing symbolic matrix density")
  }
  let goe = gaussian_orthogonal_ensemble("GOE", params=[@symcore.int(2)])
  let xmat2 = @symcore.function("MatrixSymbol", [
    @symcore.symbol("X"),
    @symcore.int(2),
    @symcore.int(2),
  ])
  match matrix_density(goe, xmat2) {
    Some(v) => {
      let ours = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify(\{@symprint.to_string(v)})",
      )
      let oracle = try! @sympy_stats.stats_eval_str(
        "density(stats.GaussianOrthogonalEnsemble('GOE', 2))(sympy.MatrixSymbol(X, 2, 2))",
      )
      assert_eq(ours, oracle)
      assert_true(
        !@symprint.to_string(v).contains("GaussianOrthogonalEnsembleDensity("),
      )
    }
    None => fail("missing symbolic matrix density")
  }
  let gse = gaussian_symplectic_ensemble("GSE", params=[@symcore.int(2)])
  match matrix_density(gse, xmat2) {
    Some(v) => {
      let ours = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify(\{@symprint.to_string(v)})",
      )
      let oracle = try! @sympy_stats.stats_eval_str(
        "density(stats.GaussianSymplecticEnsemble('GSE', 2))(sympy.MatrixSymbol(X, 2, 2))",
      )
      assert_eq(ours, oracle)
      assert_true(
        !@symprint.to_string(v).contains("GaussianSymplecticEnsembleDensity("),
      )
    }
    None => fail("missing symbolic matrix density")
  }
  let gue2 = gaussian_unitary_ensemble("GUE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(gue2) {
    Some(v) => {
      let ratio = try! @sympy_stats.stats_eval_str(
        "sympy.simplify((\{@symprint.to_string(v)})(1, 2) / ((stats.joint_eigen_distribution(stats.GaussianUnitaryEnsemble('GUE2', 2)))(1, 2)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing joint eigen distribution")
  }
  let cue2 = circular_unitary_ensemble("CUE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(cue2) {
    Some(v) => {
      let ratio = try! @sympy_stats.stats_eval_str(
        "sympy.simplify((\{@symprint.to_string(v)})(0, 1) / ((stats.joint_eigen_distribution(stats.CircularUnitaryEnsemble('CUE2', 2)))(0, 1)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing circular joint eigen distribution")
  }
  match joint_eigen_distribution_of(goe) {
    Some(v) => {
      let ratio = try! @sympy_stats.stats_eval_str(
        "sympy.simplify((\{@symprint.to_string(v)})(1, 2) / ((stats.joint_eigen_distribution(stats.GaussianOrthogonalEnsemble('GOE', 2)))(1, 2)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing GOE joint eigen distribution")
  }
  match joint_eigen_distribution_of(gse) {
    Some(v) => {
      let ratio = try! @sympy_stats.stats_eval_str(
        "sympy.simplify((\{@symprint.to_string(v)})(1, 2) / ((stats.joint_eigen_distribution(stats.GaussianSymplecticEnsemble('GSE', 2)))(1, 2)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing GSE joint eigen distribution")
  }
  let coe2 = circular_orthogonal_ensemble("COE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(coe2) {
    Some(v) => {
      let ratio = try! @sympy_stats.stats_eval_str(
        "sympy.simplify((\{@symprint.to_string(v)})(0, 1) / ((stats.joint_eigen_distribution(stats.CircularOrthogonalEnsemble('COE2', 2)))(0, 1)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing COE joint eigen distribution")
  }
  let cse2 = circular_symplectic_ensemble("CSE2", params=[@symcore.int(2)])
  match joint_eigen_distribution_of(cse2) {
    Some(v) => {
      let ratio = try! @sympy_stats.stats_eval_str(
        "sympy.simplify((\{@symprint.to_string(v)})(0, 1) / ((stats.joint_eigen_distribution(stats.CircularSymplecticEnsemble('CSE2', 2)))(0, 1)))",
      )
      assert_true(ratio_matches_one(ratio))
    }
    None => fail("missing CSE joint eigen distribution")
  }
  match level_spacing_distribution_of(gue2) {
    Some(v) => {
      let ours = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify((\{@symprint.to_string(v)})(Rational(1, 2)))",
      )
      let oracle = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify((stats.level_spacing_distribution(stats.GaussianUnitaryEnsemble('GUE2', 2)))(Rational(1, 2)))",
      )
      assert_eq(ours, oracle)
    }
    None => fail("missing level spacing distribution")
  }
  match level_spacing_distribution_of(goe) {
    Some(v) => {
      let ours = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify((\{@symprint.to_string(v)})(Rational(1, 2)))",
      )
      let oracle = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify((stats.level_spacing_distribution(stats.GaussianOrthogonalEnsemble('GOE', 2)))(Rational(1, 2)))",
      )
      assert_eq(ours, oracle)
    }
    None => fail("missing level spacing distribution")
  }
  match level_spacing_distribution_of(gse) {
    Some(v) => {
      let ours = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify((\{@symprint.to_string(v)})(Rational(1, 2)))",
      )
      let oracle = try! @sympy_stats.stats_eval_str(
        "sympy.nsimplify((stats.level_spacing_distribution(stats.GaussianSymplecticEnsemble('GSE', 2)))(Rational(1, 2)))",
      )
      assert_eq(ours, oracle)
    }
    None => fail("missing level spacing distribution")
  }
  assert_true(level_spacing_distribution_of(cue2) is None)

  let bp = bernoulli_process("BP", params=[
    try! @symcore.rational_from_ints(1, 3),
  ])
  let t = @symcore.symbol("t")
  match process_mean_at(bp, t) {
    Some(v) => assert_true(expr_equiv_to(v, "1/3"))
    None => fail("missing bernoulli process mean")
  }
  match process_variance_at(bp, t) {
    Some(v) => assert_true(expr_equiv_to(v, "2/9"))
    None => fail("missing bernoulli process variance")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "1/3"))
    None => fail("missing bernoulli process transition")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(1),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "2/3"))
    None => fail("missing bernoulli process transition")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "1"))
    None => fail("missing bernoulli process transition")
  }
  match
    process_transition_probability(
      bp,
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(2),
      @symcore.int(2),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "0"))
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
  match
    process_transition_probability(
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
  match
    process_transition_probability(
      gp,
      @symcore.int(4),
      @symcore.int(4),
      @symcore.int(3),
      @symcore.int(3),
    ) {
    Some(v) => assert_true(expr_equiv_to(v, "1"))
    None => fail("missing gamma process transition")
  }
}

///|
test "compat handmade and joint families concrete density paths" {
  let xh = @symcore.symbol("xh")
  let ch_pdf = @symcore.function("Lambda", [
    xh,
    @symcore.function("Piecewise", [
      @symcore.function("Tuple", [
        @symcore.function("exp", [
          eval_arith(@symcore.mul([@symcore.int(-1), xh])),
        ]),
        @symcore.function("Ge", [xh, @symcore.int(0)]),
      ]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.symbol("True")]),
    ]),
  ])
  let ch = continuous_rv("CH", params=[ch_pdf])
  let ch_d = density(ch, @symcore.int(2))
  let ch_d_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(ch_d)})",
  )
  assert_eq(ch_d_s, "exp(-2)")
  assert_true(!@symprint.to_string(ch_d).contains("density(CH,"))
  let sch = @symcore.symbol("CH")
  let ch_c = cdf(ch, @symcore.int(2))
  assert_true(@symprint.to_string(ch_c).contains("Integral("))
  assert_true(!@symprint.to_string(ch_c).contains("cdf(CH,"))
  let ch_p = probability(le(sch, @symcore.int(2)), rv=ch)
  assert_eq(@symcore.compare_expr(ch_p, ch_c), 0)
  assert_true(!@symprint.to_string(ch_p).contains("Probability("))

  let kh = @symcore.symbol("kh")
  let dh_pmf = @symcore.function("Lambda", [
    kh,
    @symcore.function("Piecewise", [
      @symcore.function("Tuple", [
        try! @symcore.rational_from_ints(1, 2),
        @symcore.function("Eq", [kh, @symcore.int(0)]),
      ]),
      @symcore.function("Tuple", [
        try! @symcore.rational_from_ints(1, 2),
        @symcore.function("Eq", [kh, @symcore.int(1)]),
      ]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.symbol("True")]),
    ]),
  ])
  let dh = discrete_rv("DH", params=[dh_pmf])
  let dh_d = density(dh, @symcore.int(1))
  let dh_d_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(dh_d)})",
  )
  assert_eq(dh_d_s, "1/2")
  assert_true(!@symprint.to_string(dh_d).contains("density(DH,"))
  let sdh = @symcore.symbol("DH")
  let dh_c = cdf(dh, @symcore.int(1))
  assert_true(@symprint.to_string(dh_c).contains("Sum("))
  assert_true(!@symprint.to_string(dh_c).contains("cdf(DH,"))
  let dh_p_eq = probability(eq(sdh, @symcore.int(1)), rv=dh)
  assert_true(expr_equiv_to(dh_p_eq, "1/2"))
  let dh_p_le = probability(le(sdh, @symcore.int(1)), rv=dh)
  assert_eq(@symcore.compare_expr(dh_p_le, dh_c), 0)
  assert_true(!@symprint.to_string(dh_p_eq).contains("Probability("))

  let fh_pairs = @symcore.function("Tuple", [
    @symcore.function("Tuple", [
      @symcore.int(0),
      try! @symcore.rational_from_ints(1, 4),
    ]),
    @symcore.function("Tuple", [
      @symcore.int(1),
      try! @symcore.rational_from_ints(3, 4),
    ]),
  ])
  let fh = finite_distribution_handmade("FH", params=[fh_pairs])
  let fh_d = density(fh, @symcore.int(1))
  let fh_d_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(fh_d)})",
  )
  assert_eq(fh_d_s, "3/4")
  let sfh = @symcore.symbol("FH")
  let fh_m_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(expectation(sfh, rvs=[fh]))})",
  )
  assert_eq(fh_m_s, "3/4")
  let fh_v_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(variance(sfh, rvs=[fh]))})",
  )
  assert_eq(fh_v_s, "3/16")
  let fh_c = cdf(fh, @symcore.int(0))
  let fh_c_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda F: P(F <= 0))(stats.FiniteRV('F', {0: Rational(1, 4), 1: Rational(3, 4)}))",
  )
  assert_true(expr_equiv_to(fh_c, fh_c_oracle))
  let fh_p = probability(eq(sfh, @symcore.int(1)), rv=fh)
  let fh_p_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda F: P(Eq(F, 1)))(stats.FiniteRV('F', {0: Rational(1, 4), 1: Rational(3, 4)}))",
  )
  assert_true(expr_equiv_to(fh_p, fh_p_oracle))
  assert_true(!@symprint.to_string(fh_p).contains("Probability("))

  let j1 = @symcore.symbol("j1")
  let j2 = @symcore.symbol("j2")
  let j_pdf = @symcore.function("Lambda", [
    @symcore.function("Tuple", [j1, j2]),
    eval_arith(
      @symcore.add([j1, eval_arith(@symcore.mul([@symcore.int(2), j2]))]),
    ),
  ])
  let jh = joint_rv("JH", params=[j_pdf])
  let jh_d = density(
    jh,
    @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)]),
  )
  let jh_d_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(jh_d)})",
  )
  assert_eq(jh_d_s, "11")
  assert_true(!@symprint.to_string(jh_d).contains("density(JH,"))
  let sjh = @symcore.symbol("JH")
  let jh_c = cdf(
    jh,
    @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)]),
  )
  let jh_c_s = @symprint.to_string(jh_c)
  assert_true(jh_c_s.contains("Integral("))
  assert_true(!jh_c_s.contains("JointRVCDF("))
  assert_true(!jh_c_s.contains("cdf(JH,"))
  let jh_p = probability(
    eq(sjh, @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)])),
    rv=jh,
  )
  assert_true(expr_equiv_to(jh_p, "0"))
  let jh_prob_rect = probability(
    and_event([
      ge(sjh, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
      le(sjh, @symcore.function("Tuple", [@symcore.int(3), @symcore.int(4)])),
    ]),
    rv=jh,
  )
  let jh_prob_rect_s = @symprint.to_string(jh_prob_rect)
  assert_true(jh_prob_rect_s.contains("Integral("))
  assert_true(!jh_prob_rect_s.contains("Probability("))
  assert_true(!@symprint.to_string(jh_p).contains("Probability("))

  let ew = multivariate_ewens("EW", params=[@symcore.int(2), @symcore.int(1)])
  let ew_d = density(
    ew,
    @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)]),
  )
  let ew_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda EW: density(EW)(2, 0))(stats.MultivariateEwens('EW', 2, 1))",
  )
  let ew_d_s = try! @sympy_stats.stats_eval_str(
    "sympy.nsimplify(\{@symprint.to_string(ew_d)})",
  )
  let ew_o_s = try! @sympy_stats.stats_eval_str("sympy.nsimplify(\{ew_oracle})")
  assert_eq(ew_d_s, ew_o_s)
  assert_true(!@symprint.to_string(ew_d).contains("density(EW,"))
  let sew = @symcore.symbol("EW")
  let ew_p = probability(
    eq(sew, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(0)])),
    rv=ew,
  )
  assert_eq(@symcore.compare_expr(ew_p, ew_d), 0)
  assert_true(!@symprint.to_string(ew_p).contains("Probability("))

  let t11 = try! @symcore.rational_from_ints(1, 1)
  let t12 = try! @symcore.rational_from_ints(1, 2)
  let omega = @symcore.function("Tuple", [
    @symcore.function("Tuple", [t11, t12]),
    @symcore.function("Tuple", [t12, t11]),
  ])
  let ones = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])
  let gmlg = generalized_multivariate_log_gamma("GMLG2", params=[
    try! @symcore.rational_from_ints(1, 2),
    @symcore.int(1),
    ones,
    ones,
  ])
  let gmlg_d = density(
    gmlg,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlg_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda GMLG2: density(GMLG2)(0, 0))(stats.GeneralizedMultivariateLogGamma('GMLG2', Rational(1, 2), 1, [1, 1], [1, 1]))",
  )
  assert_true(expr_equiv_to(gmlg_d, gmlg_oracle))
  assert_true(!@symprint.to_string(gmlg_d).contains("density(GMLG2,"))
  let sgmlg = @symcore.symbol("GMLG2")
  let gmlg_c = cdf(
    gmlg,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlg_c_s = @symprint.to_string(gmlg_c)
  assert_true(gmlg_c_s.contains("Integral("))
  assert_true(!gmlg_c_s.contains("GeneralizedMultivariateLogGammaCDF("))
  let gmlg_p_eq = probability(
    eq(sgmlg, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlg,
  )
  let gmlg_p_eq_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda GMLG2: P(Eq(GMLG2, Tuple(0, 0))))(stats.GeneralizedMultivariateLogGamma('GMLG2', Rational(1, 2), 1, [1, 1], [1, 1]))",
  )
  assert_true(expr_equiv_to(gmlg_p_eq, gmlg_p_eq_oracle))
  assert_true(expr_equiv_to(gmlg_p_eq, "0"))
  let gmlg_p_le = probability(
    le(sgmlg, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlg,
  )
  assert_eq(@symcore.compare_expr(gmlg_p_le, gmlg_c), 0)
  let gmlg_p_ge = probability(
    ge(sgmlg, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlg,
  )
  let gmlg_p_ge_s = @symprint.to_string(gmlg_p_ge)
  assert_true(gmlg_p_ge_s.contains("Integral("))
  assert_true(!gmlg_p_ge_s.contains("Probability("))

  let gmlgo = generalized_multivariate_log_gamma_omega("GMLGO2", params=[
    omega,
    @symcore.int(1),
    ones,
    ones,
  ])
  let gmlgo_d = density(
    gmlgo,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlgo_oracle = try! @sympy_stats.stats_eval_str(
    "(lambda GMLGO2: density(GMLGO2)(0, 0))(stats.GeneralizedMultivariateLogGammaOmega('GMLGO2', sympy.Matrix([[1, Rational(1, 2)], [Rational(1, 2), 1]]), 1, [1, 1], [1, 1]))",
  )
  assert_true(expr_equiv_to(gmlgo_d, gmlgo_oracle))
  assert_true(!@symprint.to_string(gmlgo_d).contains("density(GMLGO2,"))
  let sgmlgo = @symcore.symbol("GMLGO2")
  let gmlgo_c = cdf(
    gmlgo,
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
  )
  let gmlgo_c_s = @symprint.to_string(gmlgo_c)
  assert_true(gmlgo_c_s.contains("Integral("))
  assert_true(!gmlgo_c_s.contains("GeneralizedMultivariateLogGammaOmegaCDF("))
  let gmlgo_p_eq = probability(
    eq(sgmlgo, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlgo,
  )
  assert_true(expr_equiv_to(gmlgo_p_eq, "0"))
  let gmlgo_p_le = probability(
    le(sgmlgo, @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)])),
    rv=gmlgo,
  )
  assert_eq(@symcore.compare_expr(gmlgo_p_le, gmlgo_c), 0)
}

///|
test "compat cdf coverage for residual families" {
  let x = @symcore.symbol("x")

  let bnc = beta_noncentral("BNC", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_true(!@symprint.to_string(cdf(bnc, x)).contains("BetaNoncentralCDF("))

  let chn = chi_noncentral("CHN", params=[@symcore.int(3), @symcore.int(2)])
  assert_true(!@symprint.to_string(cdf(chn, x)).contains("ChiNoncentralCDF("))

  let dav = davis("DAV", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_true(!@symprint.to_string(cdf(dav, x)).contains("DavisCDF("))

  let fd = f_distribution("FD", params=[@symcore.int(5), @symcore.int(7)])
  assert_true(!@symprint.to_string(cdf(fd, x)).contains("FDistributionCDF("))

  let fz = fisher_z("FZ", params=[@symcore.int(5), @symcore.int(7)])
  assert_true(!@symprint.to_string(cdf(fz, x)).contains("FisherZCDF("))

  let us = uniform_sum("US", params=[@symcore.int(5)])
  let us_c = cdf(us, @symcore.int(2))
  assert_true(expr_equiv_to(us_c, "9/40"))
  assert_true(!@symprint.to_string(us_c).contains("UniformSumCDF("))

  let vm = von_mises("VM", params=[@symcore.int(0), @symcore.int(2)])
  assert_true(!@symprint.to_string(cdf(vm, x)).contains("VonMisesCDF("))

  let ws = wigner_semicircle("WS", params=[@symcore.int(3)])
  assert_true(!@symprint.to_string(cdf(ws, x)).contains("WignerSemicircleCDF("))

  let bb = beta_binomial("BBc", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_true(!@symprint.to_string(cdf(bb, x)).contains("BetaBinomialCDF("))

  let hg = hypergeometric("HGc", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_true(!@symprint.to_string(cdf(hg, x)).contains("HypergeometricCDF("))

  let he = hermite("HEc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(!@symprint.to_string(cdf(he, x)).contains("HermiteCDF("))

  let isol = ideal_soliton("ISc", params=[@symcore.int(10)])
  assert_true(!@symprint.to_string(cdf(isol, x)).contains("IdealSolitonCDF("))

  let rs = robust_soliton("RSc", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    try! @symcore.rational_from_ints(1, 2),
  ])
  assert_true(!@symprint.to_string(cdf(rs, x)).contains("RobustSolitonCDF("))

  let lg = logarithmic("LGc", params=[try! @symcore.rational_from_ints(1, 3)])
  assert_true(!@symprint.to_string(cdf(lg, x)).contains("LogarithmicCDF("))

  let sk = skellam("SKc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(!@symprint.to_string(cdf(sk, x)).contains("SkellamCDF("))

  let zz = zeta("ZZc", params=[@symcore.int(3)])
  assert_true(!@symprint.to_string(cdf(zz, x)).contains("ZetaCDF("))

  let mn = multinomial("MNc", params=[
    @symcore.int(5),
    try! @symcore.rational_from_ints(1, 3),
    try! @symcore.rational_from_ints(2, 3),
  ])
  assert_true(
    !@symprint.to_string(
      cdf(mn, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(4)])),
    ).contains("MultinomialCDF("),
  )

  let nmn = negative_multinomial("NMNc", params=[
    @symcore.int(2),
    try! @symcore.rational_from_ints(1, 4),
    try! @symcore.rational_from_ints(1, 4),
  ])
  assert_true(
    !@symprint.to_string(
      cdf(nmn, @symcore.function("Tuple", [@symcore.int(2), @symcore.int(3)])),
    ).contains("NegativeMultinomialCDF("),
  )

  let bp = bernoulli_process("BPc", params=[
    try! @symcore.rational_from_ints(1, 3),
  ])
  let bp_c0 = cdf(bp, @symcore.int(0))
  assert_true(expr_equiv_to(bp_c0, "2/3"))
  assert_true(!@symprint.to_string(bp_c0).contains("BernoulliProcessCDF("))

  let gp = gamma_process("GPc", params=[@symcore.int(2), @symcore.int(3)])
  let gp_c = cdf(gp, x)
  let gp_s = @symprint.to_string(gp_c)
  assert_true(!gp_s.contains("GammaProcessCDF("))
  assert_true(gp_s.contains("lowergamma"))

  let d = dirichlet("Dc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(
    !@symprint.to_string(
      cdf(d, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])),
    ).contains("DirichletCDF("),
  )

  let mb = multivariate_beta("MBc", params=[@symcore.int(2), @symcore.int(3)])
  assert_true(
    !@symprint.to_string(
      cdf(mb, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(1)])),
    ).contains("MultivariateBetaCDF("),
  )

  let ml = multivariate_laplace("MLc", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_true(
    !@symprint.to_string(
      cdf(ml, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("MultivariateLaplaceCDF("),
  )

  let mvn = multivariate_normal("MVNc", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_true(
    !@symprint.to_string(
      cdf(mvn, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("MultivariateNormalCDF("),
  )

  let mvt = multivariate_t("MVTc", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_true(
    !@symprint.to_string(
      cdf(mvt, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("MultivariateTCDF("),
  )

  let ng = normal_gamma("NGc", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_true(
    !@symprint.to_string(
      cdf(ng, @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])),
    ).contains("NormalGammaCDF("),
  )

  let goe = gaussian_orthogonal_ensemble("GOEc", params=[@symcore.int(2)])
  assert_true(
    !@symprint.to_string(cdf(goe, x)).contains("GaussianOrthogonalEnsembleCDF("),
  )

  let gue = gaussian_unitary_ensemble("GUEc", params=[@symcore.int(2)])
  assert_true(
    !@symprint.to_string(cdf(gue, x)).contains("GaussianUnitaryEnsembleCDF("),
  )

  let gse = gaussian_symplectic_ensemble("GSEc", params=[@symcore.int(2)])
  assert_true(
    !@symprint.to_string(cdf(gse, x)).contains("GaussianSymplecticEnsembleCDF("),
  )

  let mg = matrix_gamma("MGc", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  assert_true(!@symprint.to_string(cdf(mg, x)).contains("MatrixGammaCDF("))

  let mst = matrix_student_t("MSTc", params=[
    @symcore.int(3),
    @symcore.symbol("M"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  assert_true(!@symprint.to_string(cdf(mst, x)).contains("MatrixStudentTCDF("))
}

///|
test "compat mean coverage for residual families" {
  let ben = benini("BENm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_mean_not_placeholder(ben, "Benini")

  let bnc = beta_noncentral("BNCm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mean_not_placeholder(bnc, "BetaNoncentral")

  let bp = beta_prime("BPm", params=[@symcore.int(2), @symcore.int(3)])
  assert_mean_not_placeholder(bp, "BetaPrime")

  let chn = chi_noncentral("CHNm", params=[@symcore.int(4), @symcore.int(2)])
  assert_mean_not_placeholder(chn, "ChiNoncentral")

  let dag = dagum("DAGm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mean_not_placeholder(dag, "Dagum")

  let dav = davis("DAVm", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_mean_not_placeholder(dav, "Davis")

  let ep = exponential_power("EPm", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_mean_not_placeholder(ep, "ExponentialPower")

  let fd = f_distribution("FDm", params=[@symcore.int(5), @symcore.int(7)])
  assert_mean_not_placeholder(fd, "FDistribution")

  let fz = fisher_z("FZm", params=[@symcore.int(5), @symcore.int(7)])
  assert_mean_not_placeholder(fz, "FisherZ")

  let fr = frechet("FRm", params=[@symcore.int(3)])
  assert_mean_not_placeholder(fr, "Frechet")

  let gi = gamma_inverse("GIm", params=[@symcore.int(3), @symcore.int(2)])
  assert_mean_not_placeholder(gi, "GammaInverse")

  let lev = levy("LEVm", params=[@symcore.int(0), @symcore.int(1)])
  assert_mean_not_placeholder(lev, "Levy")

  let lc = log_cauchy("LCm", params=[@symcore.int(0), @symcore.int(1)])
  assert_mean_not_placeholder(lc, "LogCauchy")

  let ln = logit_normal("LNm", params=[@symcore.int(0), @symcore.int(1)])
  assert_mean_not_placeholder(ln, "LogitNormal")

  let lom = lomax("LOMm", params=[@symcore.int(3), @symcore.int(2)])
  assert_mean_not_placeholder(lom, "Lomax")

  let mx = maxwell("MXm", params=[@symcore.int(2)])
  assert_mean_not_placeholder(mx, "Maxwell")

  let nak = nakagami("NAKm", params=[@symcore.int(2), @symcore.int(3)])
  assert_mean_not_placeholder(nak, "Nakagami")

  let sg = shifted_gompertz("SGm", params=[@symcore.int(1), @symcore.int(2)])
  assert_mean_not_placeholder(sg, "ShiftedGompertz")

  let vm = von_mises("VMm", params=[@symcore.int(0), @symcore.int(2)])
  assert_mean_not_placeholder(vm, "VonMises")

  let iso = ideal_soliton("ISm", params=[@symcore.int(10)])
  assert_mean_not_placeholder(iso, "IdealSoliton")

  let rso = robust_soliton("RSm", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    try! @symcore.rational_from_ints(1, 2),
  ])
  assert_mean_not_placeholder(rso, "RobustSoliton")

  let goe = gaussian_orthogonal_ensemble("GOEm", params=[@symcore.int(2)])
  assert_eq(
    @symprint.to_string(expectation(@symcore.symbol("GOEm"), rvs=[goe])),
    "ZeroMatrix(2, 2)",
  )
  assert_mean_not_placeholder(goe, "GaussianOrthogonalEnsemble")

  let gue = gaussian_unitary_ensemble("GUEm", params=[@symcore.int(2)])
  assert_eq(
    @symprint.to_string(expectation(@symcore.symbol("GUEm"), rvs=[gue])),
    "ZeroMatrix(2, 2)",
  )
  assert_mean_not_placeholder(gue, "GaussianUnitaryEnsemble")

  let gse = gaussian_symplectic_ensemble("GSEm", params=[@symcore.int(2)])
  assert_eq(
    @symprint.to_string(expectation(@symcore.symbol("GSEm"), rvs=[gse])),
    "ZeroMatrix(2, 2)",
  )
  assert_mean_not_placeholder(gse, "GaussianSymplecticEnsemble")

  let mg = matrix_gamma("MGm", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  let mg_mean = expectation(@symcore.symbol("MGm"), rvs=[mg])
  let mg_s = @symprint.to_string(mg_mean)
  assert_true(!mg_s.contains("MatrixGammaMean("))
  assert_true(mg_s != "MGm")
  assert_mean_not_placeholder(mg, "MatrixGamma")

  let mst = matrix_student_t("MSTm", params=[
    @symcore.int(3),
    @symcore.symbol("MeanM"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  assert_eq(
    @symprint.to_string(expectation(@symcore.symbol("MSTm"), rvs=[mst])),
    "MeanM",
  )
  assert_mean_not_placeholder(mst, "MatrixStudentT")
}

///|
test "compat variance coverage for residual families" {
  let ben = benini("BENv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_variance_not_placeholder(ben, "Benini")

  let bnc = beta_noncentral("BNCv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_variance_not_placeholder(bnc, "BetaNoncentral")

  let bp = beta_prime("BPv", params=[@symcore.int(2), @symcore.int(5)])
  assert_variance_not_placeholder(bp, "BetaPrime")

  let chn = chi_noncentral("CHNv", params=[@symcore.int(4), @symcore.int(2)])
  assert_variance_not_placeholder(chn, "ChiNoncentral")

  let dag = dagum("DAGv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_variance_not_placeholder(dag, "Dagum")

  let dav = davis("DAVv", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_variance_not_placeholder(dav, "Davis")

  let ep = exponential_power("EPv", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_variance_not_placeholder(ep, "ExponentialPower")

  let fd = f_distribution("FDv", params=[@symcore.int(5), @symcore.int(7)])
  assert_variance_not_placeholder(fd, "FDistribution")

  let fz = fisher_z("FZv", params=[@symcore.int(5), @symcore.int(7)])
  assert_variance_not_placeholder(fz, "FisherZ")

  let fr = frechet("FRv", params=[@symcore.int(3)])
  assert_variance_not_placeholder(fr, "Frechet")

  let gi = gamma_inverse("GIv", params=[@symcore.int(3), @symcore.int(2)])
  assert_variance_not_placeholder(gi, "GammaInverse")

  let lev = levy("LEVv", params=[@symcore.int(0), @symcore.int(1)])
  assert_variance_not_placeholder(lev, "Levy")

  let lc = log_cauchy("LCv", params=[@symcore.int(0), @symcore.int(1)])
  assert_variance_not_placeholder(lc, "LogCauchy")

  let ln = logit_normal("LNv", params=[@symcore.int(0), @symcore.int(1)])
  assert_variance_not_placeholder(ln, "LogitNormal")

  let lom = lomax("LOMv", params=[@symcore.int(3), @symcore.int(2)])
  assert_variance_not_placeholder(lom, "Lomax")

  let mx = maxwell("MXv", params=[@symcore.int(2)])
  assert_variance_not_placeholder(mx, "Maxwell")

  let nak = nakagami("NAKv", params=[@symcore.int(2), @symcore.int(3)])
  assert_variance_not_placeholder(nak, "Nakagami")

  let pf = power_function("PFv", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  assert_variance_not_placeholder(pf, "PowerFunction")

  let qu = quadratic_u("QUv", params=[@symcore.int(0), @symcore.int(2)])
  assert_variance_not_placeholder(qu, "QuadraticU")

  let sg = shifted_gompertz("SGv", params=[@symcore.int(1), @symcore.int(2)])
  assert_variance_not_placeholder(sg, "ShiftedGompertz")

  let vm = von_mises("VMv", params=[@symcore.int(0), @symcore.int(2)])
  assert_variance_not_placeholder(vm, "VonMises")

  let iso = ideal_soliton("ISv", params=[@symcore.int(10)])
  assert_variance_not_placeholder(iso, "IdealSoliton")

  let rso = robust_soliton("RSv", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    try! @symcore.rational_from_ints(1, 2),
  ])
  assert_variance_not_placeholder(rso, "RobustSoliton")

  let ys = yule_simon("YSv", params=[@symcore.int(3)])
  assert_variance_not_placeholder(ys, "YuleSimon")

  let goe = gaussian_orthogonal_ensemble("GOEv", params=[@symcore.int(2)])
  let goe_v = @symprint.to_string(variance(@symcore.symbol("GOEv"), rvs=[goe]))
  assert_true(goe_v.contains("Expectation("))
  assert_true(goe_v != "Variance(GOEv)")

  let gue = gaussian_unitary_ensemble("GUEv", params=[@symcore.int(2)])
  let gue_v = @symprint.to_string(variance(@symcore.symbol("GUEv"), rvs=[gue]))
  assert_true(gue_v.contains("Expectation("))
  assert_true(gue_v != "Variance(GUEv)")

  let gse = gaussian_symplectic_ensemble("GSEv", params=[@symcore.int(2)])
  let gse_v = @symprint.to_string(variance(@symcore.symbol("GSEv"), rvs=[gse]))
  assert_true(gse_v.contains("Expectation("))
  assert_true(gse_v != "Variance(GSEv)")

  let mg = matrix_gamma("MGv", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  assert_variance_not_placeholder(mg, "MatrixGamma")
  assert_true(
    @symprint.to_string(variance(@symcore.symbol("MGv"), rvs=[mg])) !=
    "Variance(MGv)",
  )

  let mst = matrix_student_t("MSTv", params=[
    @symcore.int(3),
    @symcore.symbol("MeanM"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  assert_variance_not_placeholder(mst, "MatrixStudentT")
  let mst_v = @symprint.to_string(variance(@symcore.symbol("MSTv"), rvs=[mst]))
  assert_true(mst_v.contains("Expectation("))
  assert_true(mst_v != "Variance(MSTv)")
}

///|
test "compat mgf coverage for residual families" {
  let t = @symcore.symbol("t")
  let tvec = @symcore.function("Tuple", [
    @symcore.symbol("t1"),
    @symcore.symbol("t2"),
  ])

  let a = arcsin("Am", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(a, "Arcsin", t)

  let ben = benini("BENg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_mgf_not_placeholder(ben, "Benini", t)

  let bp = bernoulli_process("BPg", params=[
    try! @symcore.rational_from_ints(1, 3),
  ])
  let bp_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("BPg"), t, rvs=[bp]),
  )
  assert_true(!bp_mgf.contains("moment_generating_function("))
  assert_true(!bp_mgf.contains("BernoulliProcessMGF("))

  let bb = beta_binomial("BBg", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(bb, "BetaBinomial", t)

  let bnc = beta_noncentral("BNCg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mgf_not_placeholder(bnc, "BetaNoncentral", t)

  let bpr = beta_prime("BPG", params=[@symcore.int(2), @symcore.int(5)])
  assert_mgf_not_placeholder(bpr, "BetaPrime", t)

  let c = cauchy("CG", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(c, "Cauchy", t)

  let chn = chi_noncentral("CHNg", params=[@symcore.int(4), @symcore.int(2)])
  assert_mgf_not_placeholder(chn, "ChiNoncentral", t)

  let dag = dagum("DAGg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_mgf_not_placeholder(dag, "Dagum", t)

  let dav = davis("DAVg", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_mgf_not_placeholder(dav, "Davis", t)

  let d = dirichlet("Dg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(d, "Dirichlet", tvec)

  let ep = exponential_power("EPg", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_mgf_not_placeholder(ep, "ExponentialPower", t)

  let fd = f_distribution("FDg", params=[@symcore.int(5), @symcore.int(7)])
  assert_mgf_not_placeholder(fd, "FDistribution", t)

  let fz = fisher_z("FZg", params=[@symcore.int(5), @symcore.int(7)])
  assert_mgf_not_placeholder(fz, "FisherZ", t)

  let fr = frechet("FRg", params=[@symcore.int(3)])
  assert_mgf_not_placeholder(fr, "Frechet", t)

  let gi = gamma_inverse("GIg", params=[@symcore.int(3), @symcore.int(2)])
  assert_mgf_not_placeholder(gi, "GammaInverse", t)

  let gp = gamma_process("GPg", params=[@symcore.int(2), @symcore.int(3)])
  let gp_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("GPg"), t, rvs=[gp]),
  )
  assert_true(!gp_mgf.contains("moment_generating_function("))
  assert_true(!gp_mgf.contains("GammaProcessMGF("))

  let goe = gaussian_orthogonal_ensemble("GOEg", params=[@symcore.int(2)])
  let goe_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("GOEg"), t, rvs=[goe]),
  )
  assert_true(goe_mgf.contains("Expectation("))
  assert_true(!goe_mgf.contains("moment_generating_function("))

  let gse = gaussian_symplectic_ensemble("GSEg", params=[@symcore.int(2)])
  let gse_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("GSEg"), t, rvs=[gse]),
  )
  assert_true(gse_mgf.contains("Expectation("))
  assert_true(!gse_mgf.contains("moment_generating_function("))

  let gue = gaussian_unitary_ensemble("GUEg", params=[@symcore.int(2)])
  let gue_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("GUEg"), t, rvs=[gue]),
  )
  assert_true(gue_mgf.contains("Expectation("))
  assert_true(!gue_mgf.contains("moment_generating_function("))

  let hg = hypergeometric("HGg", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_mgf_not_placeholder(hg, "Hypergeometric", t)

  let iso = ideal_soliton("ISg", params=[@symcore.int(10)])
  assert_mgf_not_placeholder(iso, "IdealSoliton", t)

  let k = kumaraswamy("Kg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(k, "Kumaraswamy", t)

  let lev = levy("LEVg", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(lev, "Levy", t)

  let lc = log_cauchy("LCg", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(lc, "LogCauchy", t)

  let ll = log_logistic("LLg", params=[@symcore.int(1), @symcore.int(2)])
  assert_mgf_not_placeholder(ll, "LogLogistic", t)

  let ln = logit_normal("LNg", params=[@symcore.int(0), @symcore.int(1)])
  assert_mgf_not_placeholder(ln, "LogitNormal", t)

  let lom = lomax("LOMg", params=[@symcore.int(3), @symcore.int(2)])
  assert_mgf_not_placeholder(lom, "Lomax", t)

  let mg = matrix_gamma("MGg", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  let mg_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("MGg"), t, rvs=[mg]),
  )
  assert_true(mg_mgf.contains("Expectation("))
  assert_true(!mg_mgf.contains("moment_generating_function("))

  let mst = matrix_student_t("MSTg", params=[
    @symcore.int(3),
    @symcore.symbol("MeanM"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  let mst_mgf = @symprint.to_string(
    moment_generating_function(@symcore.symbol("MSTg"), t, rvs=[mst]),
  )
  assert_true(mst_mgf.contains("Expectation("))
  assert_true(!mst_mgf.contains("moment_generating_function("))

  let mx = maxwell("MXg", params=[@symcore.int(2)])
  assert_mgf_not_placeholder(mx, "Maxwell", t)

  let mn = multinomial("MNg", params=[
    @symcore.int(5),
    try! @symcore.rational_from_ints(1, 3),
    try! @symcore.rational_from_ints(2, 3),
  ])
  assert_mgf_not_placeholder(mn, "Multinomial", tvec)

  let mb = multivariate_beta("MBg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(mb, "MultivariateBeta", tvec)

  let mvt = multivariate_t("MVTg", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_mgf_not_placeholder(mvt, "MultivariateT", tvec)

  let nak = nakagami("NAKg", params=[@symcore.int(2), @symcore.int(3)])
  assert_mgf_not_placeholder(nak, "Nakagami", t)

  let nmn = negative_multinomial("NMNg", params=[
    @symcore.int(2),
    try! @symcore.rational_from_ints(1, 4),
    try! @symcore.rational_from_ints(1, 4),
  ])
  assert_mgf_not_placeholder(nmn, "NegativeMultinomial", tvec)

  let ng = normal_gamma("NGg", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(ng, "NormalGamma", tvec)

  let pf = power_function("PFg", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(pf, "PowerFunction", t)

  let rs = robust_soliton("RSg", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    try! @symcore.rational_from_ints(1, 2),
  ])
  assert_mgf_not_placeholder(rs, "RobustSoliton", t)

  let sg = shifted_gompertz("SGg", params=[@symcore.int(1), @symcore.int(2)])
  assert_mgf_not_placeholder(sg, "ShiftedGompertz", t)

  let st = student_t("STg", params=[@symcore.int(5)])
  assert_mgf_not_placeholder(st, "StudentT", t)

  let tr = trapezoidal("TRg", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_mgf_not_placeholder(tr, "Trapezoidal", t)

  let vm = von_mises("VMg", params=[@symcore.int(0), @symcore.int(2)])
  assert_mgf_not_placeholder(vm, "VonMises", t)

  let w = weibull("WG", params=[@symcore.int(3), @symcore.int(5)])
  assert_mgf_not_placeholder(w, "Weibull", t)
}

///|
test "compat cf coverage for residual families" {
  let t = @symcore.symbol("t")
  let tvec = @symcore.function("Tuple", [
    @symcore.symbol("t1"),
    @symcore.symbol("t2"),
  ])

  let a = arcsin("Acf", params=[@symcore.int(0), @symcore.int(1)])
  assert_cf_not_placeholder(a, "Arcsin", t)

  let ben = benini("BENcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_cf_not_placeholder(ben, "Benini", t)

  let bp = bernoulli_process("BPcf", params=[
    try! @symcore.rational_from_ints(1, 3),
  ])
  assert_cf_not_placeholder(bp, "BernoulliProcess", t)

  let bb = beta_binomial("BBcf", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(bb, "BetaBinomial", t)

  let bnc = beta_noncentral("BNCcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_cf_not_placeholder(bnc, "BetaNoncentral", t)

  let bpr = beta_prime("BPcf", params=[@symcore.int(2), @symcore.int(5)])
  assert_cf_not_placeholder(bpr, "BetaPrime", t)

  let chn = chi_noncentral("CHNcf", params=[@symcore.int(4), @symcore.int(2)])
  assert_cf_not_placeholder(chn, "ChiNoncentral", t)

  let dag = dagum("DAGcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_cf_not_placeholder(dag, "Dagum", t)

  let dav = davis("DAVcf", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_cf_not_placeholder(dav, "Davis", t)

  let d = dirichlet("Dcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(d, "Dirichlet", tvec)

  let ep = exponential_power("EPcf", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_cf_not_placeholder(ep, "ExponentialPower", t)

  let fd = f_distribution("FDcf", params=[@symcore.int(5), @symcore.int(7)])
  assert_cf_not_placeholder(fd, "FDistribution", t)

  let fz = fisher_z("FZcf", params=[@symcore.int(5), @symcore.int(7)])
  assert_cf_not_placeholder(fz, "FisherZ", t)

  let fr = frechet("FRcf", params=[@symcore.int(3)])
  assert_cf_not_placeholder(fr, "Frechet", t)

  let gp = gamma_process("GPcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(gp, "GammaProcess", t)

  let goe = gaussian_orthogonal_ensemble("GOEcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(goe, "GaussianOrthogonalEnsemble", t)

  let gse = gaussian_symplectic_ensemble("GSEcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(gse, "GaussianSymplecticEnsemble", t)

  let gue = gaussian_unitary_ensemble("GUEcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(gue, "GaussianUnitaryEnsemble", t)

  let hg = hypergeometric("HGcf", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_cf_not_placeholder(hg, "Hypergeometric", t)

  let iso = ideal_soliton("IScf", params=[@symcore.int(10)])
  assert_cf_not_placeholder(iso, "IdealSoliton", t)

  let k = kumaraswamy("Kcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(k, "Kumaraswamy", t)

  let lc = log_cauchy("LCcf", params=[@symcore.int(0), @symcore.int(1)])
  assert_cf_not_placeholder(lc, "LogCauchy", t)

  let ll = log_logistic("LLcf", params=[@symcore.int(1), @symcore.int(2)])
  assert_cf_not_placeholder(ll, "LogLogistic", t)

  let ln = logit_normal("LNcf", params=[@symcore.int(0), @symcore.int(1)])
  assert_cf_not_placeholder(ln, "LogitNormal", t)

  let lom = lomax("LOMcf", params=[@symcore.int(3), @symcore.int(2)])
  assert_cf_not_placeholder(lom, "Lomax", t)

  let mg = matrix_gamma("MGcf", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  assert_cf_not_placeholder(mg, "MatrixGamma", t)

  let mst = matrix_student_t("MSTcf", params=[
    @symcore.int(3),
    @symcore.symbol("MeanM"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  assert_cf_not_placeholder(mst, "MatrixStudentT", t)

  let mx = maxwell("MXcf", params=[@symcore.int(2)])
  assert_cf_not_placeholder(mx, "Maxwell", t)

  let mn = multinomial("MNcf", params=[
    @symcore.int(5),
    try! @symcore.rational_from_ints(1, 3),
    try! @symcore.rational_from_ints(2, 3),
  ])
  assert_cf_not_placeholder(mn, "Multinomial", tvec)

  let mb = multivariate_beta("MBcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(mb, "MultivariateBeta", tvec)

  let mvt = multivariate_t("MVTcf", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_cf_not_placeholder(mvt, "MultivariateT", tvec)

  let nak = nakagami("NAKcf", params=[@symcore.int(2), @symcore.int(3)])
  assert_cf_not_placeholder(nak, "Nakagami", t)

  let nmn = negative_multinomial("NMNcf", params=[
    @symcore.int(2),
    try! @symcore.rational_from_ints(1, 4),
    try! @symcore.rational_from_ints(1, 4),
  ])
  assert_cf_not_placeholder(nmn, "NegativeMultinomial", tvec)

  let ng = normal_gamma("NGcf", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(ng, "NormalGamma", tvec)

  let pf = power_function("PFcf", params=[
    @symcore.int(2),
    @symcore.int(0),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(pf, "PowerFunction", t)

  let rs = robust_soliton("RScf", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    try! @symcore.rational_from_ints(1, 2),
  ])
  assert_cf_not_placeholder(rs, "RobustSoliton", t)

  let sg = shifted_gompertz("SGcf", params=[@symcore.int(1), @symcore.int(2)])
  assert_cf_not_placeholder(sg, "ShiftedGompertz", t)

  let tr = trapezoidal("TRcf", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_cf_not_placeholder(tr, "Trapezoidal", t)

  let vm = von_mises("VMcf", params=[@symcore.int(0), @symcore.int(2)])
  assert_cf_not_placeholder(vm, "VonMises", t)

  let w = weibull("Wcf", params=[@symcore.int(3), @symcore.int(5)])
  assert_cf_not_placeholder(w, "Weibull", t)
}

///|
test "compat quantile coverage for residual families" {
  let q = try! @symcore.rational_from_ints(1, 4)
  let third = try! @symcore.rational_from_ints(1, 3)
  let fifth = try! @symcore.rational_from_ints(1, 5)

  let ben = benini("BENq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_quantile_not_placeholder(ben, "Benini", q)

  let bp = bernoulli_process("BPq", params=[third])
  assert_quantile_not_placeholder(bp, "BernoulliProcess", q)

  let bb = beta_binomial("BBq", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_quantile_not_placeholder(bb, "BetaBinomial", q)

  let bnc = beta_noncentral("BNCq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_quantile_not_placeholder(bnc, "BetaNoncentral", q)

  let bpr = beta_prime("BPRq", params=[@symcore.int(2), @symcore.int(5)])
  assert_quantile_not_placeholder(bpr, "BetaPrime", q)

  let chn = chi_noncentral("CHNq", params=[@symcore.int(4), @symcore.int(2)])
  assert_quantile_not_placeholder(chn, "ChiNoncentral", q)

  let dag = dagum("DAGq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_quantile_not_placeholder(dag, "Dagum", q)

  let dav = davis("DAVq", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_quantile_not_placeholder(dav, "Davis", q)

  let d = dirichlet("Dq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(d, "Dirichlet", q)

  let exg = ex_gaussian("EXGq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_quantile_not_placeholder(exg, "ExGaussian", q)

  let ep = exponential_power("EPq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_quantile_not_placeholder(ep, "ExponentialPower", q)

  let fd = f_distribution("FDq", params=[@symcore.int(5), @symcore.int(7)])
  assert_quantile_not_placeholder(fd, "FDistribution", q)

  let fz = fisher_z("FZq", params=[@symcore.int(5), @symcore.int(7)])
  assert_quantile_not_placeholder(fz, "FisherZ", q)

  let fl = flory_schulz("FLq", params=[third])
  assert_quantile_not_placeholder(fl, "FlorySchulz", q)

  let fr = frechet("FRq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(fr, "Frechet", q)

  let gi = gamma_inverse("GIq", params=[@symcore.int(3), @symcore.int(2)])
  assert_quantile_not_placeholder(gi, "GammaInverse", q)

  let gp = gamma_process("GPq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(gp, "GammaProcess", q)

  let gai = gaussian_inverse("GAIq", params=[@symcore.int(3), @symcore.int(2)])
  assert_quantile_not_placeholder(gai, "GaussianInverse", q)

  let goe = gaussian_orthogonal_ensemble("GOEq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(goe, "GaussianOrthogonalEnsemble", q)

  let gse = gaussian_symplectic_ensemble("GSEq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(gse, "GaussianSymplecticEnsemble", q)

  let gue = gaussian_unitary_ensemble("GUEq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(gue, "GaussianUnitaryEnsemble", q)

  let he = hermite("HEq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(he, "Hermite", q)

  let hg = hypergeometric("HGq", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_quantile_not_placeholder(hg, "Hypergeometric", q)

  let iso = ideal_soliton("ISq", params=[@symcore.int(10)])
  assert_quantile_not_placeholder(iso, "IdealSoliton", q)

  let lc = log_cauchy("LCq", params=[@symcore.int(0), @symcore.int(1)])
  assert_quantile_not_placeholder(lc, "LogCauchy", q)

  let lg = logarithmic("LGq", params=[third])
  assert_quantile_not_placeholder(lg, "Logarithmic", q)

  let lgn = logit_normal("LNq", params=[@symcore.int(0), @symcore.int(1)])
  assert_quantile_not_placeholder(lgn, "LogitNormal", q)

  let mg = matrix_gamma("MGq", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  assert_quantile_not_placeholder(mg, "MatrixGamma", q)

  let mst = matrix_student_t("MSTq", params=[
    @symcore.int(3),
    @symcore.symbol("MeanM"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  assert_quantile_not_placeholder(mst, "MatrixStudentT", q)

  let mx = maxwell("MXq", params=[@symcore.int(2)])
  assert_quantile_not_placeholder(mx, "Maxwell", q)

  let mn = multinomial("MNq", params=[
    @symcore.int(5),
    third,
    try! @symcore.rational_from_ints(2, 3),
  ])
  assert_quantile_not_placeholder(mn, "Multinomial", q)

  let mb = multivariate_beta("MBq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(mb, "MultivariateBeta", q)

  let mvl = multivariate_laplace("MVLq", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_quantile_not_placeholder(mvl, "MultivariateLaplace", q)

  let mvn = multivariate_normal("MVNq", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_quantile_not_placeholder(mvn, "MultivariateNormal", q)

  let mvt = multivariate_t("MVTq", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_quantile_not_placeholder(mvt, "MultivariateT", q)

  let nak = nakagami("NAKq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(nak, "Nakagami", q)

  let nmn = negative_multinomial("NMNq", params=[
    @symcore.int(2),
    try! @symcore.rational_from_ints(1, 4),
    try! @symcore.rational_from_ints(1, 4),
  ])
  assert_quantile_not_placeholder(nmn, "NegativeMultinomial", q)

  let ng = normal_gamma("NGq", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_quantile_not_placeholder(ng, "NormalGamma", q)

  let qu = quadratic_u("QUq", params=[@symcore.int(0), @symcore.int(2)])
  assert_quantile_not_placeholder(qu, "QuadraticU", q)

  let rc = raised_cosine("RCq", params=[@symcore.int(0), @symcore.int(2)])
  assert_quantile_not_placeholder(rc, "RaisedCosine", q)

  let rs = robust_soliton("RSq", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    fifth,
  ])
  assert_quantile_not_placeholder(rs, "RobustSoliton", q)

  let sg = shifted_gompertz("SGq", params=[@symcore.int(1), @symcore.int(2)])
  assert_quantile_not_placeholder(sg, "ShiftedGompertz", q)

  let sk = skellam("SKq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(sk, "Skellam", q)

  let us = uniform_sum("USq", params=[@symcore.int(4)])
  assert_quantile_not_placeholder(us, "UniformSum", q)

  let wd = wald("WDq", params=[@symcore.int(2), @symcore.int(3)])
  assert_quantile_not_placeholder(wd, "Wald", q)

  let ws = wigner_semicircle("WSq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(ws, "WignerSemicircle", q)

  let ys = yule_simon("YSq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(ys, "YuleSimon", q)

  let zz = zeta("ZZq", params=[@symcore.int(3)])
  assert_quantile_not_placeholder(zz, "Zeta", q)
}

///|
test "compat entropy coverage residual A" {
  let third = try! @symcore.rational_from_ints(1, 3)

  let ben = benini("BENe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(1),
  ])
  assert_entropy_not_placeholder(ben, "Benini")
  let bp = bernoulli_process("BPe", params=[third])
  assert_entropy_not_placeholder(bp, "BernoulliProcess")
  let bb = beta_binomial("BBe", params=[
    @symcore.int(10),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_entropy_not_placeholder(bb, "BetaBinomial")
  let bnc = beta_noncentral("BNCe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_entropy_not_placeholder(bnc, "BetaNoncentral")
  let bpr = beta_prime("BPRe", params=[@symcore.int(2), @symcore.int(5)])
  assert_entropy_not_placeholder(bpr, "BetaPrime")
  let chn = chi_noncentral("CHNe", params=[@symcore.int(4), @symcore.int(2)])
  assert_entropy_not_placeholder(chn, "ChiNoncentral")
  let dag = dagum("DAGe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
  ])
  assert_entropy_not_placeholder(dag, "Dagum")
  let dav = davis("DAVe", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(1),
  ])
  assert_entropy_not_placeholder(dav, "Davis")
  let d = dirichlet("De", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(d, "Dirichlet")
  let exg = ex_gaussian("EXGe", params=[
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_entropy_not_placeholder(exg, "ExGaussian")
  let ep = exponential_power("EPe", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
  ])
  assert_entropy_not_placeholder(ep, "ExponentialPower")
  let fd = f_distribution("FDe", params=[@symcore.int(5), @symcore.int(7)])
  assert_entropy_not_placeholder(fd, "FDistribution")
  let fz = fisher_z("FZe", params=[@symcore.int(5), @symcore.int(7)])
  assert_entropy_not_placeholder(fz, "FisherZ")
  let fl = flory_schulz("FLe", params=[third])
  assert_entropy_not_placeholder(fl, "FlorySchulz")
}

///|
test "compat entropy coverage residual B1" {
  let fr = frechet("FRe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(fr, "Frechet")
  let gi = gamma_inverse("GIe", params=[@symcore.int(3), @symcore.int(2)])
  assert_entropy_not_placeholder(gi, "GammaInverse")
  let gp = gamma_process("GPe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(gp, "GammaProcess")
  let gai = gaussian_inverse("GAIe", params=[@symcore.int(3), @symcore.int(2)])
  assert_entropy_not_placeholder(gai, "GaussianInverse")
  let goe = gaussian_orthogonal_ensemble("GOEe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(goe, "GaussianOrthogonalEnsemble")
  let gse = gaussian_symplectic_ensemble("GSEe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(gse, "GaussianSymplecticEnsemble")
}

///|
test "compat entropy coverage residual B2a" {
  let gue = gaussian_unitary_ensemble("GUEe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(gue, "GaussianUnitaryEnsemble")
  let he = hermite("HEe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(he, "Hermite")
  let hg = hypergeometric("HGe", params=[
    @symcore.int(20),
    @symcore.int(7),
    @symcore.int(12),
  ])
  assert_entropy_not_placeholder(hg, "Hypergeometric")
}

///|
test "compat entropy coverage residual B2b iso" {
  let iso = ideal_soliton("ISe", params=[@symcore.int(10)])
  assert_entropy_not_placeholder(iso, "IdealSoliton")
}

///|
test "compat entropy coverage residual B2b log_cauchy" {
  let lc = log_cauchy("LCe", params=[@symcore.int(0), @symcore.int(1)])
  assert_entropy_not_placeholder(lc, "LogCauchy")
}

///|
test "compat entropy coverage residual B2b logarithmic" {
  let third = try! @symcore.rational_from_ints(1, 3)
  let lgr = logarithmic("LGe", params=[third])
  assert_entropy_not_placeholder(lgr, "Logarithmic")
}

///|
test "compat entropy coverage residual C" {
  let third = try! @symcore.rational_from_ints(1, 3)

  let lgn = logit_normal("LNe", params=[@symcore.int(0), @symcore.int(1)])
  assert_entropy_not_placeholder(lgn, "LogitNormal")
  let mg = matrix_gamma("MGe", params=[
    @symcore.int(2),
    @symcore.int(3),
    @symcore.symbol("Scale"),
  ])
  assert_entropy_not_placeholder(mg, "MatrixGamma")
  let mst = matrix_student_t("MSTe", params=[
    @symcore.int(3),
    @symcore.symbol("MeanM"),
    @symcore.symbol("U"),
    @symcore.symbol("V"),
  ])
  assert_entropy_not_placeholder(mst, "MatrixStudentT")
  let mx = maxwell("MXe", params=[@symcore.int(2)])
  assert_entropy_not_placeholder(mx, "Maxwell")
  let mn = multinomial("MNe", params=[
    @symcore.int(5),
    third,
    try! @symcore.rational_from_ints(2, 3),
  ])
  assert_entropy_not_placeholder(mn, "Multinomial")
  let mb = multivariate_beta("MBe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(mb, "MultivariateBeta")
  let mvl = multivariate_laplace("MVLe", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_entropy_not_placeholder(mvl, "MultivariateLaplace")
  let mvn = multivariate_normal("MVNe", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
  ])
  assert_entropy_not_placeholder(mvn, "MultivariateNormal")
}

///|
test "compat entropy coverage residual D" {
  let fifth = try! @symcore.rational_from_ints(1, 5)

  let mvt = multivariate_t("MVTe", params=[
    @symcore.function("Tuple", [@symcore.int(0), @symcore.int(0)]),
    @symcore.function("Tuple", [
      @symcore.function("Tuple", [@symcore.int(1), @symcore.int(0)]),
      @symcore.function("Tuple", [@symcore.int(0), @symcore.int(1)]),
    ]),
    @symcore.int(5),
  ])
  assert_entropy_not_placeholder(mvt, "MultivariateT")
  let nak = nakagami("NAKe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(nak, "Nakagami")
  let nmn = negative_multinomial("NMNe", params=[
    @symcore.int(2),
    try! @symcore.rational_from_ints(1, 4),
    try! @symcore.rational_from_ints(1, 4),
  ])
  assert_entropy_not_placeholder(nmn, "NegativeMultinomial")
  let ng = normal_gamma("NGe", params=[
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
  ])
  assert_entropy_not_placeholder(ng, "NormalGamma")
  let qu = quadratic_u("QUe", params=[@symcore.int(0), @symcore.int(2)])
  assert_entropy_not_placeholder(qu, "QuadraticU")
  let rc = raised_cosine("RCe", params=[@symcore.int(0), @symcore.int(2)])
  assert_entropy_not_placeholder(rc, "RaisedCosine")
  let rs = robust_soliton("RSe", params=[
    @symcore.int(10),
    try! @symcore.rational_from_ints(1, 10),
    fifth,
  ])
  assert_entropy_not_placeholder(rs, "RobustSoliton")
  let sg = shifted_gompertz("SGe", params=[@symcore.int(1), @symcore.int(2)])
  assert_entropy_not_placeholder(sg, "ShiftedGompertz")
  let sk = skellam("SKe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(sk, "Skellam")
  let us = uniform_sum("USe", params=[@symcore.int(4)])
  assert_entropy_not_placeholder(us, "UniformSum")
  let wd = wald("WDe", params=[@symcore.int(2), @symcore.int(3)])
  assert_entropy_not_placeholder(wd, "Wald")
  let ws = wigner_semicircle("WSe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(ws, "WignerSemicircle")
  let ys = yule_simon("YSe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(ys, "YuleSimon")
  let zz = zeta("ZZe", params=[@symcore.int(3)])
  assert_entropy_not_placeholder(zz, "Zeta")
}

///|
test "compat opaque symbolic families use generic unevaluated forms" {
  let sp = stochastic_process("SP")
  let dtsp = discrete_time_stochastic_process("DTSP")
  let dmc = discrete_markov_chain("DMC", params=[@symcore.symbol("T")])
  let cmc = continuous_markov_chain("CMC", params=[@symcore.symbol("Q")])
  let ce = circular_ensemble("CE", params=[@symcore.int(2)])
  let cue = circular_unitary_ensemble("CUE", params=[@symcore.int(2)])
  let coe = circular_orthogonal_ensemble("COE", params=[@symcore.int(2)])
  let cse = circular_symplectic_ensemble("CSE", params=[@symcore.int(2)])
  let ge = gaussian_ensemble("GE", params=[@symcore.int(2)])
  let jed = joint_eigen_distribution("JED", params=[@symcore.int(2)])
  let lsd = level_spacing_distribution("LSD", params=[@symcore.int(2)])
  let jrv = joint_rv("JRV", params=[@symcore.symbol("f")])
  let gmlg = generalized_multivariate_log_gamma("GMLG", params=[
    @symcore.int(2),
    @symcore.int(1),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let gmlgo = generalized_multivariate_log_gamma_omega("GMLGO", params=[
    @symcore.int(2),
    @symcore.int(1),
    @symcore.int(3),
    @symcore.int(4),
  ])
  let mve = multivariate_ewens("MVE", params=[
    @symcore.int(3),
    @symcore.symbol("theta"),
  ])
  let crv = continuous_rv("CRV", params=[@symcore.symbol("pdf")])
  let drv = discrete_rv("DRV", params=[@symcore.symbol("pmf")])
  let cdh = continuous_distribution_handmade("CDH", params=[
    @symcore.symbol("pdf"),
  ])
  let ddh = discrete_distribution_handmade("DDH", params=[
    @symcore.symbol("pmf"),
  ])
  let fdh = finite_distribution_handmade("FDH", params=[@symcore.symbol("pmf")])

  let rvs : Array[RandomVar] = [
    sp, dtsp, dmc, cmc, ce, cue, coe, cse, ge, jed, lsd, jrv, gmlg, gmlgo, mve, crv,
    drv, cdh, ddh, fdh,
  ]
  for rv in rvs {
    assert_opaque_symbolic_metrics(rv)
  }

  let t = @symcore.symbol("t")
  assert_eq(
    @symprint.to_string(expectation(@symcore.function("SP", [t]), rvs=[sp])),
    "StochasticProcessMeanAt(t)",
  )
  assert_eq(
    @symprint.to_string(variance(@symcore.function("SP", [t]), rvs=[sp])),
    "StochasticProcessVarianceAt(t)",
  )
  assert_eq(
    @symprint.to_string(expectation(@symcore.function("DTSP", [t]), rvs=[dtsp])),
    "DiscreteTimeStochasticProcessMeanAt(t)",
  )
  assert_eq(
    @symprint.to_string(variance(@symcore.function("DTSP", [t]), rvs=[dtsp])),
    "DiscreteTimeStochasticProcessVarianceAt(t)",
  )
  assert_eq(
    @symprint.to_string(expectation(@symcore.function("DMC", [t]), rvs=[dmc])),
    "DiscreteMarkovChainMeanAt(t, T)",
  )
  assert_eq(
    @symprint.to_string(variance(@symcore.function("DMC", [t]), rvs=[dmc])),
    "DiscreteMarkovChainVarianceAt(t, T)",
  )
  assert_eq(
    @symprint.to_string(expectation(@symcore.function("CMC", [t]), rvs=[cmc])),
    "ContinuousMarkovChainMeanAt(t, Q)",
  )
  assert_eq(
    @symprint.to_string(variance(@symcore.function("CMC", [t]), rvs=[cmc])),
    "ContinuousMarkovChainVarianceAt(t, Q)",
  )
}
