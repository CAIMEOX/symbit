///|
/// Compatibility API for broader SymPy stats coverage.

///|
fn symbolic_family(dist : String) -> String {
  match dist {
    "BetaBinomial" |
    "Hypergeometric" |
    "IdealSoliton" |
    "RobustSoliton" |
    "FiniteDistributionHandmade" |
    "FlorySchulz" |
    "Hermite" |
    "Logarithmic" |
    "Skellam" |
    "YuleSimon" |
    "Zeta" |
    "DiscreteRV" |
    "DiscreteDistributionHandmade" |
    "Multinomial" |
    "NegativeMultinomial" => "D"
    "JointRV" |
    "Dirichlet" |
    "GeneralizedMultivariateLogGamma" |
    "GeneralizedMultivariateLogGammaOmega" |
    "MultivariateBeta" |
    "MultivariateEwens" |
    "MultivariateT" |
    "NormalGamma" |
    "MultivariateNormal" |
    "MultivariateLaplace" => "J"
    "StochasticProcess" |
    "DiscreteTimeStochasticProcess" |
    "DiscreteMarkovChain" |
    "ContinuousMarkovChain" |
    "BernoulliProcess" |
    "GammaProcess" => "P"
    "JointEigenDistribution" |
    "level_spacing_distribution" |
    "MatrixGamma" |
    "MatrixStudentT" |
    "CircularEnsemble" |
    "CircularUnitaryEnsemble" |
    "CircularOrthogonalEnsemble" |
    "CircularSymplecticEnsemble" |
    "GaussianEnsemble" |
    "GaussianUnitaryEnsemble" |
    "GaussianOrthogonalEnsemble" |
    "GaussianSymplecticEnsemble" => "M"
    _ => "C"
  }
}

///|
fn symbolic_rv(name : String, dist : String, params : Array[@symcore.Expr]) -> RandomVar {
  let tag = "\{symbolic_family(dist)}:\{dist}"
  random_var(name, RVKind::Symbolic(tag~, params~))
}

///|
pub fn p(event : Event, rv? : RandomVar) -> @symcore.Expr {
  match rv {
    Some(v) => probability(event, rv=v)
    None => probability(event)
  }
}

///|
pub fn e(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  expectation(expr, rvs~)
}

///|
pub fn h(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  entropy(expr, rvs~)
}

///|
pub fn given(expr : @symcore.Expr, condition : Event) -> @symcore.Expr {
  @symcore.function("given", [expr, event_to_expr(condition)])
}

///|
pub fn where_(condition : Event) -> @symcore.Expr {
  @symcore.function("where", [event_to_expr(condition)])
}

///|
pub fn sample(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("sample", [expr])
}

///|
pub fn sample_iter(expr : @symcore.Expr, n? : Int = 1) -> Array[@symcore.Expr] {
  if n <= 0 {
    return []
  }
  Array::make(n, expr)
}

///|
pub fn sample_stochastic_process(
  proc : RandomVar,
  t0 : @symcore.Expr,
  t1 : @symcore.Expr,
  n? : Int = 2,
) -> @symcore.Expr {
  @symcore.function("sample_stochastic_process", [
    @symcore.symbol(proc.name),
    t0,
    t1,
    @symcore.int(n),
  ])
}

///|
pub fn median(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  quantile(expr, try! @symcore.rational_from_ints(1, 2), rvs~)
}

///|
fn resolve_rv(expr : @symcore.Expr, rvs : Array[RandomVar]) -> RandomVar? {
  if rvs.length() == 1 {
    return Some(rvs[0])
  }
  match expr {
    @symcore.Expr::Symbol(name) => {
      for rv in rvs {
        if rv.name == name {
          return Some(rv)
        }
      }
      None
    }
    _ => None
  }
}

///|
fn symbolic_metric_with_head(
  name : String,
  suffix : String,
  head : @symcore.Expr,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = [head]
  for p in params {
    args.push(p)
  }
  @symcore.function("\{name}\{suffix}", args)
}

///|
fn symbolic_metric_no_head(
  name : String,
  suffix : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  @symcore.function("\{name}\{suffix}", params)
}

///|
fn compat_tuple_expr(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Tuple", [a, b])
}

///|
fn compat_tuple_items(expr : @symcore.Expr) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Function("Tuple", items) => Some(items)
    _ => None
  }
}

///|
fn compat_tuple2(expr : @symcore.Expr) -> (@symcore.Expr, @symcore.Expr)? {
  match compat_tuple_items(expr) {
    Some(items) if items.length() == 2 => Some((items[0], items[1]))
    _ => None
  }
}

///|
fn compat_matrix2x2(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr, @symcore.Expr)? {
  match compat_tuple_items(expr) {
    Some(rows) if rows.length() == 2 =>
      match (compat_tuple_items(rows[0]), compat_tuple_items(rows[1])) {
        (Some(r0), Some(r1)) if r0.length() == 2 && r1.length() == 2 =>
          Some((r0[0], r0[1], r1[0], r1[1]))
        _ => None
      }
    _ => None
  }
}

///|
fn compat_dot2(
  a1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b1 : @symcore.Expr,
  b2 : @symcore.Expr,
) -> @symcore.Expr {
  eval_arith(@symcore.add([
    eval_arith(@symcore.mul([a1, b1])),
    eval_arith(@symcore.mul([a2, b2])),
  ]))
}

///|
fn compat_quad2(
  s00 : @symcore.Expr,
  s01 : @symcore.Expr,
  s10 : @symcore.Expr,
  s11 : @symcore.Expr,
  t1 : @symcore.Expr,
  t2 : @symcore.Expr,
) -> @symcore.Expr {
  eval_arith(@symcore.add([
    eval_arith(@symcore.mul([s00, @symcore.pow(t1, @symcore.int(2))])),
    eval_arith(@symcore.mul([eval_arith(@symcore.add([s01, s10])), t1, t2])),
    eval_arith(@symcore.mul([s11, @symcore.pow(t2, @symcore.int(2))])),
  ]))
}

///|
fn compat_piecewise2(
  v1 : @symcore.Expr,
  c1 : @symcore.Expr,
  v2 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Piecewise", [
    compat_tuple_expr(v1, c1),
    compat_tuple_expr(v2, @symcore.symbol("True")),
  ])
}

///|
fn compat_piecewise3(
  v1 : @symcore.Expr,
  c1 : @symcore.Expr,
  v2 : @symcore.Expr,
  c2 : @symcore.Expr,
  v3 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Piecewise", [
    compat_tuple_expr(v1, c1),
    compat_tuple_expr(v2, c2),
    compat_tuple_expr(v3, @symcore.symbol("True")),
  ])
}

///|
fn compat_use_generic_unevaluated(name : String) -> Bool {
  symbolic_opaque_stats_name(name)
}

///|
fn mgf_of_rv(rv : RandomVar, t : @symcore.Expr) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(items) => {
      let terms : Array[@symcore.Expr] = Array::new()
      for item in items {
        let (value, p) = item
        terms.push(eval_arith(@symcore.mul([expr_from_big_rational(p), @symcore.function("exp", [eval_arith(@symcore.mul([t, value]))])])))
      }
      Some(eval_arith(@symcore.add(terms)))
    }
    RVKind::Binomial(n~, p~) => {
      let inside = eval_arith(@symcore.add([@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])]), @symcore.mul([p, @symcore.function("exp", [t])])]))
      Some(eval_arith(@symcore.pow(inside, n)))
    }
    RVKind::Poisson(rate~) => {
      let inner = eval_arith(@symcore.add([@symcore.function("exp", [t]), @symcore.int(-1)]))
      Some(eval_arith(@symcore.function("exp", [eval_arith(@symcore.mul([rate, inner]))])))
    }
    RVKind::Geometric(p~) => {
      let et = @symcore.function("exp", [t])
      let numer = eval_arith(@symcore.mul([p, et]))
      let denom = eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), @symcore.mul([eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])])), et])])]))
      Some(eval_arith(@symcore.mul([numer, @symcore.pow(denom, @symcore.int(-1))])))
    }
    RVKind::NegativeBinomial(r~, p~) => {
      let et = @symcore.function("exp", [t])
      let denom = eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), @symcore.mul([eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), p])])), et])])]))
      Some(eval_arith(@symcore.pow(eval_arith(@symcore.mul([p, @symcore.pow(denom, @symcore.int(-1))])), r)))
    }
    RVKind::Normal(mu~, sigma~) => {
      let t2 = @symcore.pow(t, @symcore.int(2))
      let quad = eval_arith(@symcore.mul([@symcore.int(1), @symcore.pow(@symcore.int(2), @symcore.int(-1)), @symcore.pow(sigma, @symcore.int(2)), t2]))
      Some(eval_arith(@symcore.function("exp", [eval_arith(@symcore.add([eval_arith(@symcore.mul([mu, t])), quad]))])))
    }
    RVKind::Exponential(rate~) => {
      let denom = eval_arith(@symcore.add([rate, @symcore.mul([@symcore.int(-1), t])]))
      Some(eval_arith(@symcore.mul([rate, @symcore.pow(denom, @symcore.int(-1))])))
    }
    RVKind::Gamma(shape~, scale~) => {
      let inner = eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), @symcore.mul([scale, t])])]))
      Some(eval_arith(@symcore.pow(inner, @symcore.mul([@symcore.int(-1), shape]))))
    }
    RVKind::Symbolic(tag~, params~) => {
      let name = symbolic_tag_name(tag)
      if compat_use_generic_unevaluated(name) {
        return Some(@symcore.function("moment_generating_function", [@symcore.symbol(rv.name), t]))
      }
      match generated_mgf(name, params, t) {
        Some(v) => Some(v)
        None =>
          match name {
            "MultivariateNormal" if params.length() >= 2 =>
              match (compat_tuple2(params[0]), compat_matrix2x2(params[1]), compat_tuple2(t)) {
                (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let lin = compat_dot2(t1, t2, mu1, mu2)
                  let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                  Some(eval_arith(@symcore.function("exp", [
                    eval_arith(@symcore.add([
                      lin,
                      eval_arith(@symcore.mul([half, quad])),
                    ])),
                  ])))
                }
                _ => Some(symbolic_metric_with_head(name, "MGF", t, params))
              }
            "MultivariateLaplace" if params.length() >= 2 =>
              match (compat_tuple2(params[0]), compat_matrix2x2(params[1]), compat_tuple2(t)) {
                (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let lin = compat_dot2(t1, t2, mu1, mu2)
                  let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                  let denom = eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), eval_arith(@symcore.mul([half, quad]))]),
                  ]))
                  Some(eval_arith(@symcore.mul([
                    @symcore.function("exp", [lin]),
                    @symcore.pow(denom, @symcore.int(-1)),
                  ])))
                }
                _ => Some(symbolic_metric_with_head(name, "MGF", t, params))
              }
            "Uniform" if params.length() == 2 => {
              let a = params[0]
              let b = params[1]
              let numer = eval_arith(@symcore.add([
                @symcore.function("exp", [eval_arith(@symcore.mul([t, b]))]),
                @symcore.mul([@symcore.int(-1), @symcore.function("exp", [eval_arith(@symcore.mul([t, a]))])]),
              ]))
              let denom = eval_arith(@symcore.mul([t, eval_arith(@symcore.add([b, @symcore.mul([@symcore.int(-1), a])]))]))
              Some(eval_arith(@symcore.mul([numer, @symcore.pow(denom, @symcore.int(-1))])))
            }
            "Laplace" if params.length() == 2 => {
              let mu = params[0]
              let b = params[1]
              let num = @symcore.function("exp", [eval_arith(@symcore.mul([mu, t]))])
              let den = eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), @symcore.mul([@symcore.pow(b, @symcore.int(2)), @symcore.pow(t, @symcore.int(2))])])]))
              Some(eval_arith(@symcore.mul([num, @symcore.pow(den, @symcore.int(-1))])))
            }
            "LogNormal" if params.length() == 2 => {
              // LogNormal has no elementary closed form MGF.
              Some(symbolic_metric_with_head(name, "MGF", t, params))
            }
            _ => Some(symbolic_metric_with_head(name, "MGF", t, params))
          }
      }
    }
    _ => None
  }
}

///|
pub fn characteristic_function(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match rv.kind {
        RVKind::Symbolic(tag~, params~) => {
          let name = symbolic_tag_name(tag)
          if compat_use_generic_unevaluated(name) {
            return @symcore.function("characteristic_function", [@symcore.symbol(rv.name), t])
          }
          let special =
            match name {
              "Cauchy" if params.length() == 2 =>
                Some(eval_arith(@symcore.function("exp", [
                  eval_arith(@symcore.add([
                    eval_arith(@symcore.mul([@symcore.symbol("I"), params[0], t])),
                    @symcore.mul([
                      @symcore.int(-1),
                      params[1],
                      @symcore.function("Abs", [t]),
                    ]),
                  ])),
                ])))
              "StudentT" if params.length() == 1 => {
                let nu = params[0]
                let half = try! @symcore.rational_from_ints(1, 2)
                let nu_half = eval_arith(@symcore.mul([half, nu]))
                let arg = eval_arith(@symcore.mul([
                  @symcore.function("sqrt", [nu]),
                  @symcore.function("Abs", [t]),
                ]))
                let core = eval_arith(@symcore.mul([
                  @symcore.pow(
                    @symcore.int(2),
                    eval_arith(@symcore.add([
                      @symcore.int(1),
                      @symcore.mul([@symcore.int(-1), nu_half]),
                    ])),
                  ),
                  @symcore.pow(arg, nu_half),
                  @symcore.function("besselk", [nu_half, arg]),
                  @symcore.pow(@symcore.function("gamma", [nu_half]), @symcore.int(-1)),
                ]))
                Some(@symcore.function("Piecewise", [
                  compat_tuple_expr(@symcore.int(1), @symcore.function("Eq", [t, @symcore.int(0)])),
                  compat_tuple_expr(core, @symcore.symbol("True")),
                ]))
              }
              "MultivariateNormal" if params.length() >= 2 =>
                match (compat_tuple2(params[0]), compat_matrix2x2(params[1]), compat_tuple2(t)) {
                  (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                    let half = try! @symcore.rational_from_ints(1, 2)
                    let lin = compat_dot2(t1, t2, mu1, mu2)
                    let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                    Some(eval_arith(@symcore.function("exp", [
                      eval_arith(@symcore.add([
                        eval_arith(@symcore.mul([@symcore.symbol("I"), lin])),
                        @symcore.mul([@symcore.int(-1), half, quad]),
                      ])),
                    ])))
                  }
                  _ => None
                }
              "MultivariateLaplace" if params.length() >= 2 =>
                match (compat_tuple2(params[0]), compat_matrix2x2(params[1]), compat_tuple2(t)) {
                  (Some((mu1, mu2)), Some((s00, s01, s10, s11)), Some((t1, t2))) => {
                    let half = try! @symcore.rational_from_ints(1, 2)
                    let lin = compat_dot2(t1, t2, mu1, mu2)
                    let quad = compat_quad2(s00, s01, s10, s11, t1, t2)
                    let denom = eval_arith(@symcore.add([
                      @symcore.int(1),
                      eval_arith(@symcore.mul([half, quad])),
                    ]))
                    Some(eval_arith(@symcore.mul([
                      @symcore.function("exp", [eval_arith(@symcore.mul([@symcore.symbol("I"), lin]))]),
                      @symcore.pow(denom, @symcore.int(-1)),
                    ])))
                  }
                  _ => None
                }
              _ => None
            }
          match special {
            Some(v) => v
            None =>
              match generated_cf(name, params, t) {
                Some(v) => v
                None =>
                  match mgf_of_rv(rv, eval_arith(@symcore.mul([@symcore.symbol("I"), t]))) {
                    Some(v) => v
                    None => symbolic_metric_with_head(name, "CF", t, params)
                  }
              }
          }
        }
        _ =>
          match mgf_of_rv(rv, eval_arith(@symcore.mul([@symcore.symbol("I"), t]))) {
            Some(v) => v
            None => @symcore.function("characteristic_function", [expr, t])
          }
      }
    None => @symcore.function("characteristic_function", [expr, t])
  }
}

///|
pub fn pspace(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("pspace", [expr])
}

///|
pub fn skewness(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  let c3 = central_moment(expr, 3, rvs~)
  let s = std(expr, rvs~)
  eval_arith(@symcore.mul([c3, @symcore.pow(s, @symcore.int(-3))]))
}

///|
pub fn kurtosis(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  let c4 = central_moment(expr, 4, rvs~)
  let v = variance(expr, rvs~)
  eval_arith(@symcore.mul([c4, @symcore.pow(v, @symcore.int(-2))]))
}

///|
pub fn entropy(expr : @symcore.Expr, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match rv.kind {
        RVKind::Finite(items) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for item in items {
            let (_, p) = item
            let pe = expr_from_big_rational(p)
            if @symcore.compare_expr(pe, @symcore.int(0)) != 0 {
              terms.push(eval_arith(@symcore.mul([@symcore.int(-1), pe, @symcore.function("log", [pe])])))
            }
          }
          eval_arith(@symcore.add(terms))
        }
        RVKind::Normal(mu~, sigma~) => {
          ignore(mu)
          eval_arith(@symcore.function("log", [
            eval_arith(@symcore.mul([
              sigma,
              @symcore.function("sqrt", [eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi"), @symcore.symbol("E")]))]),
            ])),
          ]))
        }
        RVKind::Exponential(rate~) =>
          eval_arith(@symcore.add([
            @symcore.int(1),
            @symcore.mul([@symcore.int(-1), @symcore.function("log", [rate])]),
          ]))
        RVKind::Gamma(shape~, scale~) =>
          eval_arith(@symcore.add([
            shape,
            @symcore.function("log", [eval_arith(@symcore.mul([scale, @symcore.function("gamma", [shape])]))]),
            @symcore.mul([@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), shape])]), @symcore.function("digamma", [shape])]),
          ]))
        RVKind::Symbolic(tag~, params~) => {
          let name = symbolic_tag_name(tag)
          if compat_use_generic_unevaluated(name) {
            return @symcore.function("entropy", [@symcore.symbol(rv.name)])
          }
          match generated_entropy(name, params) {
            Some(v) => v
            None =>
              match name {
                "Dirichlet" | "MultivariateBeta" if params.length() >= 2 => {
                  let alpha_sum = eval_arith(@symcore.add(params))
                  let log_beta_terms : Array[@symcore.Expr] = Array::new()
                  let sum_terms : Array[@symcore.Expr] = Array::new()
                  for a in params {
                    log_beta_terms.push(@symcore.function("log", [@symcore.function("gamma", [a])]))
                    sum_terms.push(eval_arith(@symcore.mul([
                      eval_arith(@symcore.add([a, @symcore.int(-1)])),
                      @symcore.function("digamma", [a]),
                    ])))
                  }
                  let log_beta = eval_arith(@symcore.add([
                    eval_arith(@symcore.add(log_beta_terms)),
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.function("log", [@symcore.function("gamma", [alpha_sum])]),
                    ]),
                  ]))
                  let dim = @symcore.int(params.length())
                  eval_arith(@symcore.add([
                    log_beta,
                    eval_arith(@symcore.mul([
                      eval_arith(@symcore.add([alpha_sum, @symcore.mul([@symcore.int(-1), dim])])),
                      @symcore.function("digamma", [alpha_sum]),
                    ])),
                    @symcore.mul([
                      @symcore.int(-1),
                      eval_arith(@symcore.add(sum_terms)),
                    ]),
                  ]))
                }
                "MultivariateNormal" if params.length() >= 2 =>
                  match compat_matrix2x2(params[1]) {
                    Some((s00, s01, s10, s11)) => {
                      let half = try! @symcore.rational_from_ints(1, 2)
                      let det = eval_arith(@symcore.add([
                        eval_arith(@symcore.mul([s00, s11])),
                        eval_arith(@symcore.mul([@symcore.int(-1), s01, s10])),
                      ]))
                      let base = eval_arith(@symcore.pow(
                        eval_arith(@symcore.mul([
                          @symcore.int(2),
                          @symcore.symbol("pi"),
                          @symcore.symbol("E"),
                        ])),
                        @symcore.int(2),
                      ))
                      eval_arith(@symcore.mul([
                        half,
                        @symcore.function("log", [eval_arith(@symcore.mul([base, det]))]),
                      ]))
                    }
                    None => symbolic_metric_no_head(name, "Entropy", params)
                  }
                "Uniform" if params.length() == 2 =>
                  eval_arith(@symcore.function("log", [eval_arith(@symcore.add([params[1], @symcore.mul([@symcore.int(-1), params[0]])]))]))
                "Exponential" if params.length() == 1 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), @symcore.function("log", [params[0]])]),
                  ]))
                "ChiSquared" if params.length() == 1 => {
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let shape = eval_arith(@symcore.mul([half, params[0]]))
                  eval_arith(@symcore.add([
                    shape,
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      @symcore.int(2),
                      @symcore.function("gamma", [shape]),
                    ]))]),
                    @symcore.mul([
                      eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), shape])])),
                      @symcore.function("digamma", [shape]),
                    ]),
                  ]))
                }
                "Chi" if params.length() == 1 => {
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let shape = eval_arith(@symcore.mul([half, params[0]]))
                  eval_arith(@symcore.add([
                    @symcore.function("log", [@symcore.function("gamma", [shape])]),
                    shape,
                    @symcore.mul([
                      @symcore.int(-1),
                      half,
                      eval_arith(@symcore.add([params[0], @symcore.int(-1)])),
                      @symcore.function("digamma", [shape]),
                    ]),
                    @symcore.mul([
                      try! @symcore.rational_from_ints(-1, 2),
                      @symcore.function("log", [@symcore.int(2)]),
                    ]),
                  ]))
                }
                "Erlang" if params.length() == 2 => {
                  let k = params[0]
                  let lamda = params[1]
                  eval_arith(@symcore.add([
                    k,
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      @symcore.function("gamma", [k]),
                      @symcore.pow(lamda, @symcore.int(-1)),
                    ]))]),
                    @symcore.mul([
                      @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), k])]),
                      @symcore.function("digamma", [k]),
                    ]),
                  ]))
                }
                "Laplace" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.function("log", [eval_arith(@symcore.mul([@symcore.int(2), params[1]]))]),
                  ]))
                "Beta" if params.length() == 2 => {
                  let a = params[0]
                  let b = params[1]
                  eval_arith(@symcore.add([
                    @symcore.function("log", [@symcore.function("beta", [a, b])]),
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.add([a, @symcore.int(-1)]),
                      @symcore.function("digamma", [a]),
                    ]),
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.add([b, @symcore.int(-1)]),
                      @symcore.function("digamma", [b]),
                    ]),
                    @symcore.mul([
                      @symcore.add([a, b, @symcore.int(-2)]),
                      @symcore.function("digamma", [@symcore.add([a, b])]),
                    ]),
                  ]))
                }
                "Cauchy" if params.length() == 2 =>
                  eval_arith(@symcore.function("log", [eval_arith(@symcore.mul([
                    @symcore.int(4),
                    @symcore.symbol("pi"),
                    params[1],
                  ]))]))
                "Logistic" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    @symcore.int(2),
                    @symcore.function("log", [params[1]]),
                  ]))
                "Rayleigh" if params.length() == 1 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.mul([
                      try! @symcore.rational_from_ints(1, 2),
                      @symcore.symbol("EulerGamma"),
                    ]),
                    @symcore.function("log", [params[0]]),
                    @symcore.mul([
                      try! @symcore.rational_from_ints(-1, 2),
                      @symcore.function("log", [@symcore.int(2)]),
                    ]),
                  ]))
                "Weibull" if params.length() == 2 => {
                  let lam = params[0]
                  let k = params[1]
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.function("log", [eval_arith(@symcore.mul([lam, @symcore.pow(k, @symcore.int(-1))]))]),
                    @symcore.mul([
                      @symcore.symbol("EulerGamma"),
                      @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), @symcore.pow(k, @symcore.int(-1))])]),
                    ]),
                  ]))
                }
                "Gumbel" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.symbol("EulerGamma"),
                    @symcore.function("log", [params[0]]),
                  ]))
                "LogNormal" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    params[0],
                    try! @symcore.rational_from_ints(1, 2),
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      params[1],
                      @symcore.function("sqrt", [eval_arith(@symcore.mul([
                        @symcore.int(2),
                        @symcore.symbol("pi"),
                      ]))]),
                    ]))]),
                  ]))
                "Pareto" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.pow(params[1], @symcore.int(-1)),
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      params[0],
                      @symcore.pow(params[1], @symcore.int(-1)),
                    ]))]),
                  ]))
                "Levy" if params.length() == 2 => {
                  let c = params[1]
                  eval_arith(@symcore.add([
                    try! @symcore.rational_from_ints(1, 2),
                    @symcore.mul([
                      try! @symcore.rational_from_ints(3, 2),
                      @symcore.symbol("EulerGamma"),
                    ]),
                    @symcore.mul([
                      try! @symcore.rational_from_ints(1, 2),
                      @symcore.function("log", [eval_arith(@symcore.mul([
                        @symcore.int(16),
                        @symcore.symbol("pi"),
                        @symcore.pow(c, @symcore.int(2)),
                      ]))]),
                    ]),
                  ]))
                }
                "Gompertz" if params.length() == 2 => {
                  let b = params[0]
                  let eta = params[1]
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.function("log", [eval_arith(@symcore.mul([b, eta]))]),
                    ]),
                    @symcore.mul([
                      @symcore.function("exp", [eta]),
                      @symcore.function("Ei", [eval_arith(@symcore.mul([@symcore.int(-1), eta]))]),
                    ]),
                  ]))
                }
                "Lomax" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.pow(params[0], @symcore.int(-1)),
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      params[1],
                      @symcore.pow(params[0], @symcore.int(-1)),
                    ]))]),
                  ]))
                "Triangular" if params.length() == 3 =>
                  eval_arith(@symcore.add([
                    try! @symcore.rational_from_ints(1, 2),
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      try! @symcore.rational_from_ints(1, 2),
                      eval_arith(@symcore.add([params[1], @symcore.mul([@symcore.int(-1), params[0]])])),
                    ]))]),
                  ]))
                "PowerFunction" if params.length() == 3 =>
                  eval_arith(@symcore.add([
                    @symcore.int(1),
                    @symcore.mul([@symcore.int(-1), @symcore.pow(params[0], @symcore.int(-1))]),
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      eval_arith(@symcore.add([params[2], @symcore.mul([@symcore.int(-1), params[1]])])),
                      @symcore.pow(params[0], @symcore.int(-1)),
                    ]))]),
                  ]))
                "Arcsin" if params.length() == 0 =>
                  @symcore.function("log", [eval_arith(@symcore.mul([
                    @symcore.symbol("pi"),
                    try! @symcore.rational_from_ints(1, 4),
                  ]))])
                "Arcsin" if params.length() == 2 =>
                  @symcore.function("log", [eval_arith(@symcore.mul([
                    @symcore.symbol("pi"),
                    try! @symcore.rational_from_ints(1, 4),
                    eval_arith(@symcore.add([params[1], @symcore.mul([@symcore.int(-1), params[0]])])),
                  ]))])
                "StudentT" if params.length() == 1 => {
                  let nu = params[0]
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let nu_half = eval_arith(@symcore.mul([half, nu]))
                  let nu1_half = eval_arith(@symcore.mul([half, @symcore.add([nu, @symcore.int(1)])]))
                  eval_arith(@symcore.add([
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      @symcore.function("sqrt", [nu]),
                      @symcore.function("beta", [nu_half, half]),
                    ]))]),
                    @symcore.mul([
                      nu1_half,
                      eval_arith(@symcore.add([
                        @symcore.function("digamma", [nu1_half]),
                        @symcore.mul([@symcore.int(-1), @symcore.function("digamma", [nu_half])]),
                      ])),
                    ]),
                  ]))
                }
                "VonMises" if params.length() == 2 => {
                  let kappa = params[1]
                  let i0 = @symcore.function("besseli", [@symcore.int(0), kappa])
                  let i1 = @symcore.function("besseli", [@symcore.int(1), kappa])
                  eval_arith(@symcore.add([
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      @symcore.int(2),
                      @symcore.symbol("pi"),
                      i0,
                    ]))]),
                    @symcore.mul([
                      @symcore.int(-1),
                      kappa,
                      i1,
                      @symcore.pow(i0, @symcore.int(-1)),
                    ]),
                  ]))
                }
                "Trapezoidal" if params.length() == 4 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let d = params[3]
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let span = eval_arith(@symcore.add([d, c, @symcore.mul([@symcore.int(-1), b]), @symcore.mul([@symcore.int(-1), a])]))
                  let edge = eval_arith(@symcore.add([
                    eval_arith(@symcore.add([b, @symcore.mul([@symcore.int(-1), a])])),
                    eval_arith(@symcore.add([d, @symcore.mul([@symcore.int(-1), c])])),
                  ]))
                  eval_arith(@symcore.add([
                    @symcore.function("log", [eval_arith(@symcore.mul([
                      half,
                      span,
                    ]))]),
                    eval_arith(@symcore.mul([
                      half,
                      edge,
                      @symcore.pow(span, @symcore.int(-1)),
                    ])),
                  ]))
                }
                "Moyal" if params.length() == 2 => @symcore.symbol("oo")
                _ => symbolic_metric_no_head(name, "Entropy", params)
              }
          }
        }
        _ => @symcore.function("entropy", [expr])
      }
    None => @symcore.function("entropy", [expr])
  }
}

///|
pub fn dependent(a : RandomVar, b : RandomVar) -> Bool {
  !assume_independent(a, b)
}

///|
pub fn independent(a : RandomVar, b : RandomVar) -> Bool {
  assume_independent(a, b)
}

///|
fn collect_symbols(expr : @symcore.Expr, out : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => out[name] = true
    _ =>
      for child in @symcore.children(expr) {
        collect_symbols(child, out)
      }
  }
}

///|
pub fn random_symbols(expr : @symcore.Expr) -> Array[String] {
  let seen : Map[String, Bool] = {}
  collect_symbols(expr, seen)
  let out : Array[String] = Array::new()
  for key, _ in seen {
    out.push(key)
  }
  out.sort()
  out
}

///|
pub fn correlation(
  a : @symcore.Expr,
  b : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  let cov = covariance(a, b, rvs~)
  let sa = std(a, rvs~)
  let sb = std(b, rvs~)
  eval_arith(@symcore.mul([cov, @symcore.pow(sa, @symcore.int(-1)), @symcore.pow(sb, @symcore.int(-1))]))
}

///|
pub fn factorial_moment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  let factors : Array[@symcore.Expr] = Array::new()
  for i in 0..<n {
    factors.push(eval_arith(@symcore.add([expr, @symcore.int(-i)])))
  }
  let falling =
    if factors.is_empty() {
      @symcore.int(1)
    } else {
      eval_arith(@symcore.mul(factors))
    }
  if !rvs.is_empty() {
    expectation(falling, rvs~)
  } else {
    @symcore.function("factorial_moment", [expr, @symcore.int(n)])
  }
}

///|
pub fn cmoment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  central_moment(expr, n, rvs~)
}

///|
pub fn sampling_density(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("sampling_density", [expr])
}

///|
pub fn moment_generating_function(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match mgf_of_rv(rv, t) {
        Some(v) => v
        None => @symcore.function("moment_generating_function", [expr, t])
      }
    None => @symcore.function("moment_generating_function", [expr, t])
  }
}

///|
pub fn smoment(
  expr : @symcore.Expr,
  n : Int,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  if !rvs.is_empty() {
    let c = central_moment(expr, n, rvs~)
    let s = std(expr, rvs~)
    eval_arith(@symcore.mul([c, @symcore.pow(s, @symcore.int(-n))]))
  } else {
    @symcore.function("smoment", [expr, @symcore.int(n)])
  }
}

///|
pub fn quantile(
  expr : @symcore.Expr,
  q : @symcore.Expr,
  rvs? : Array[RandomVar] = [],
) -> @symcore.Expr {
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match rv.kind {
        RVKind::Exponential(rate~) =>
          eval_arith(@symcore.mul([@symcore.int(-1), @symcore.function("log", [eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])]))]), @symcore.pow(rate, @symcore.int(-1))]))
        RVKind::Normal(mu~, sigma~) =>
          eval_arith(@symcore.add([
            mu,
            eval_arith(@symcore.mul([
              sigma,
              @symcore.function("sqrt", [@symcore.int(2)]),
              @symcore.function("erfinv", [eval_arith(@symcore.add([eval_arith(@symcore.mul([@symcore.int(2), q])), @symcore.int(-1)]))]),
            ])),
          ]))
        RVKind::Symbolic(tag~, params~) => {
          let name = symbolic_tag_name(tag)
          if compat_use_generic_unevaluated(name) {
            return @symcore.function("quantile", [@symcore.symbol(rv.name), q])
          }
          match generated_quantile(name, params, q) {
            Some(v) => v
            None =>
              match name {
                "Arcsin" if params.length() == 0 =>
                  compat_piecewise2(
                    @symcore.pow(
                      @symcore.function("sin", [eval_arith(@symcore.mul([
                        @symcore.symbol("pi"),
                        q,
                        try! @symcore.rational_from_ints(1, 2),
                      ]))]),
                      @symcore.int(2),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Arcsin" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.add([
                      params[0],
                      @symcore.mul([
                        eval_arith(@symcore.add([params[1], @symcore.mul([@symcore.int(-1), params[0]])])),
                        @symcore.pow(
                          @symcore.function("sin", [eval_arith(@symcore.mul([
                            @symcore.symbol("pi"),
                            q,
                            try! @symcore.rational_from_ints(1, 2),
                          ]))]),
                          @symcore.int(2),
                        ),
                      ]),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Beta" if params.length() == 2 =>
                  compat_piecewise2(
                    @symcore.function("betaincinv", [params[0], params[1], q]),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Kumaraswamy" if params.length() == 2 =>
                  compat_piecewise2(
                    @symcore.pow(
                      eval_arith(@symcore.add([
                        @symcore.int(1),
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.pow(
                            eval_arith(@symcore.add([
                              @symcore.int(1),
                              @symcore.mul([@symcore.int(-1), q]),
                            ])),
                            @symcore.pow(params[1], @symcore.int(-1)),
                          ),
                        ]),
                      ])),
                      @symcore.pow(params[0], @symcore.int(-1)),
                    ),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Chi" if params.length() == 1 =>
                  compat_piecewise2(
                    @symcore.function("sqrt", [eval_arith(@symcore.mul([
                      @symcore.int(2),
                      @symcore.function("gammaincinv", [
                        eval_arith(@symcore.mul([
                          try! @symcore.rational_from_ints(1, 2),
                          params[0],
                        ])),
                        q,
                      ]),
                    ]))]),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "ChiSquared" if params.length() == 1 =>
                  compat_piecewise2(
                    eval_arith(@symcore.mul([
                      @symcore.int(2),
                      @symcore.function("gammaincinv", [
                        eval_arith(@symcore.mul([
                          try! @symcore.rational_from_ints(1, 2),
                          params[0],
                        ])),
                        q,
                      ]),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Erlang" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.mul([
                      @symcore.function("gammaincinv", [params[0], q]),
                      @symcore.pow(params[1], @symcore.int(-1)),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Uniform" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    params[0],
                    eval_arith(@symcore.mul([
                      q,
                      eval_arith(
                        @symcore.add([params[1], @symcore.mul([@symcore.int(-1), params[0]])]),
                      ),
                    ])),
                  ]))
                "Cauchy" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.add([
                      params[0],
                      @symcore.mul([
                        params[1],
                        @symcore.function("tan", [eval_arith(@symcore.mul([
                          @symcore.symbol("pi"),
                          eval_arith(@symcore.add([q, try! @symcore.rational_from_ints(-1, 2)])),
                        ]))]),
                      ]),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Rayleigh" if params.length() == 1 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.function("sqrt", [eval_arith(@symcore.mul([
                      @symcore.int(-2),
                      @symcore.function("log", [eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])]))]),
                    ]))]),
                  ]))
                "Laplace" if params.length() == 2 => {
                  let mu = params[0]
                  let b = params[1]
                  let left = eval_arith(@symcore.add([
                    mu,
                    @symcore.mul([
                      b,
                      @symcore.function("log", [eval_arith(@symcore.mul([@symcore.int(2), q]))]),
                    ]),
                  ]))
                  let right = eval_arith(@symcore.add([
                    mu,
                    @symcore.mul([
                      @symcore.int(-1),
                      b,
                      @symcore.function("log", [eval_arith(@symcore.mul([
                        @symcore.int(2),
                        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])]),
                      ]))]),
                    ]),
                  ]))
                  compat_piecewise3(
                    left,
                    @symcore.function("Le", [q, try! @symcore.rational_from_ints(1, 2)]),
                    right,
                    @symcore.function("Le", [q, @symcore.int(1)]),
                    @symcore.symbol("nan"),
                  )
                }
                "Weibull" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.pow(
                      eval_arith(@symcore.mul([
                        @symcore.int(-1),
                        @symcore.function("log", [eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])]))]),
                      ])),
                      @symcore.pow(params[1], @symcore.int(-1)),
                    ),
                  ]))
                "Gumbel" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    params[1],
                    @symcore.mul([
                      @symcore.int(-1),
                      params[0],
                      @symcore.function("log", [
                        eval_arith(@symcore.mul([
                          @symcore.int(-1),
                          @symcore.function("log", [q]),
                        ])),
                      ]),
                    ]),
                  ]))
                "Moyal" if params.length() == 2 =>
                  eval_arith(@symcore.add([
                    params[0],
                    @symcore.mul([
                      @symcore.int(-2),
                      params[1],
                      @symcore.function("log", [eval_arith(@symcore.mul([
                        @symcore.function("sqrt", [@symcore.int(2)]),
                        @symcore.function("erfcinv", [q]),
                      ]))]),
                    ]),
                  ]))
                "PowerFunction" if params.length() == 3 =>
                  eval_arith(@symcore.add([
                    params[1],
                    @symcore.mul([
                      @symcore.add([params[2], @symcore.mul([@symcore.int(-1), params[1]])]),
                      @symcore.pow(q, @symcore.pow(params[0], @symcore.int(-1))),
                    ]),
                  ]))
                "Triangular" if params.length() == 3 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let span = eval_arith(@symcore.add([b, @symcore.mul([@symcore.int(-1), a])]))
                  let left = eval_arith(@symcore.add([
                    a,
                    @symcore.function("sqrt", [eval_arith(@symcore.mul([
                      q,
                      span,
                      eval_arith(@symcore.add([c, @symcore.mul([@symcore.int(-1), a])])),
                    ]))]),
                  ]))
                  let right = eval_arith(@symcore.add([
                    b,
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.function("sqrt", [eval_arith(@symcore.mul([
                        @symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])]),
                        span,
                        eval_arith(@symcore.add([b, @symcore.mul([@symcore.int(-1), c])])),
                      ]))]),
                    ]),
                  ]))
                  let pivot = eval_arith(@symcore.mul([
                    eval_arith(@symcore.add([c, @symcore.mul([@symcore.int(-1), a])])),
                    @symcore.pow(span, @symcore.int(-1)),
                  ]))
                  compat_piecewise3(
                    left,
                    @symcore.function("Le", [q, pivot]),
                    right,
                    @symcore.function("Le", [q, @symcore.int(1)]),
                    @symcore.symbol("nan"),
                  )
                }
                "Trapezoidal" if params.length() == 4 => {
                  let a = params[0]
                  let b = params[1]
                  let c = params[2]
                  let d = params[3]
                  let span = eval_arith(@symcore.add([d, c, @symcore.mul([@symcore.int(-1), b]), @symcore.mul([@symcore.int(-1), a])]))
                  let ql = eval_arith(@symcore.mul([
                    eval_arith(@symcore.add([b, @symcore.mul([@symcore.int(-1), a])])),
                    @symcore.pow(span, @symcore.int(-1)),
                  ]))
                  let qr = eval_arith(@symcore.mul([
                    eval_arith(@symcore.add([@symcore.mul([@symcore.int(2), c]), @symcore.mul([@symcore.int(-1), a]), @symcore.mul([@symcore.int(-1), b])])),
                    @symcore.pow(span, @symcore.int(-1)),
                  ]))
                  let left = eval_arith(@symcore.add([
                    a,
                    @symcore.function("sqrt", [eval_arith(@symcore.mul([
                      q,
                      eval_arith(@symcore.add([b, @symcore.mul([@symcore.int(-1), a])])),
                      span,
                    ]))]),
                  ]))
                  let mid = eval_arith(@symcore.mul([
                    try! @symcore.rational_from_ints(1, 2),
                    eval_arith(@symcore.add([
                      eval_arith(@symcore.mul([q, span])),
                      a,
                      b,
                    ])),
                  ]))
                  let right = eval_arith(@symcore.add([
                    d,
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.function("sqrt", [eval_arith(@symcore.mul([
                        eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])])),
                        eval_arith(@symcore.add([d, @symcore.mul([@symcore.int(-1), c])])),
                        span,
                      ]))]),
                    ]),
                  ]))
                  @symcore.function("Piecewise", [
                    compat_tuple_expr(left, @symcore.function("Le", [q, ql])),
                    compat_tuple_expr(mid, @symcore.function("Le", [q, qr])),
                    compat_tuple_expr(right, @symcore.function("Le", [q, @symcore.int(1)])),
                    compat_tuple_expr(@symcore.symbol("nan"), @symcore.symbol("True")),
                  ])
                }
                "VonMises" if params.length() == 2 => {
                  let mu = params[0]
                  let kappa = params[1]
                  let x_var = @symcore.symbol("_x")
                  let integral_term = @symcore.function("Integral", [
                    @symcore.function("exp", [eval_arith(@symcore.mul([
                      kappa,
                      @symcore.function("cos", [eval_arith(@symcore.add([
                        x_var,
                        @symcore.mul([@symcore.int(-1), mu]),
                      ]))]),
                    ]))]),
                    @symcore.function("Tuple", [x_var, @symcore.int(0), x_var]),
                  ])
                  let target = eval_arith(@symcore.mul([
                    @symcore.int(2),
                    @symcore.symbol("pi"),
                    q,
                    @symcore.function("besseli", [@symcore.int(0), kappa]),
                  ]))
                  let condset = @symcore.function("ConditionSet", [
                    x_var,
                    @symcore.function("Eq", [eval_arith(@symcore.add([
                      integral_term,
                      @symcore.mul([@symcore.int(-1), target]),
                    ])), @symcore.int(0)]),
                    @symcore.function("Interval", [
                      @symcore.int(0),
                      eval_arith(@symcore.mul([@symcore.int(2), @symcore.symbol("pi")])),
                    ]),
                  ])
                  compat_piecewise2(
                    condset,
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                }
                "StudentT" if params.length() == 1 => {
                  let nu = params[0]
                  let half = try! @symcore.rational_from_ints(1, 2)
                  let a = eval_arith(@symcore.mul([half, nu]))
                  let left_beta = @symcore.function("betaincinv", [a, half, eval_arith(@symcore.mul([@symcore.int(2), q]))])
                  let right_beta = @symcore.function("betaincinv", [a, half, eval_arith(@symcore.mul([
                    @symcore.int(2),
                    eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])])),
                  ]))])
                  let left = eval_arith(@symcore.mul([
                    @symcore.int(-1),
                    @symcore.function("sqrt", [eval_arith(@symcore.mul([
                      nu,
                      eval_arith(@symcore.add([
                        @symcore.pow(left_beta, @symcore.int(-1)),
                        @symcore.int(-1),
                      ])),
                    ]))]),
                  ]))
                  let right = eval_arith(@symcore.function("sqrt", [eval_arith(@symcore.mul([
                    nu,
                    eval_arith(@symcore.add([
                      @symcore.pow(right_beta, @symcore.int(-1)),
                      @symcore.int(-1),
                    ])),
                  ]))]))
                  @symcore.function("Piecewise", [
                    compat_tuple_expr(left, @symcore.function("Lt", [q, half])),
                    compat_tuple_expr(@symcore.int(0), @symcore.function("Eq", [q, half])),
                    compat_tuple_expr(right, @symcore.function("Le", [q, @symcore.int(1)])),
                    compat_tuple_expr(@symcore.symbol("nan"), @symcore.symbol("True")),
                  ])
                }
                "BoundedPareto" if params.length() == 3 =>
                  compat_piecewise2(
                    eval_arith(@symcore.mul([
                      params[1],
                      @symcore.pow(
                        eval_arith(@symcore.add([
                          @symcore.int(1),
                          @symcore.mul([
                            @symcore.int(-1),
                            q,
                            eval_arith(@symcore.add([
                              @symcore.int(1),
                              @symcore.mul([
                                @symcore.int(-1),
                                @symcore.pow(
                                  eval_arith(@symcore.mul([
                                    params[1],
                                    @symcore.pow(params[2], @symcore.int(-1)),
                                  ])),
                                  params[0],
                                ),
                              ]),
                            ])),
                          ]),
                        ])),
                        eval_arith(@symcore.mul([
                          @symcore.int(-1),
                          @symcore.pow(params[0], @symcore.int(-1)),
                        ])),
                      ),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Pareto" if params.length() == 2 =>
                  eval_arith(@symcore.mul([
                    params[0],
                    @symcore.pow(eval_arith(@symcore.add([@symcore.int(1), @symcore.mul([@symcore.int(-1), q])])), @symcore.mul([@symcore.int(-1), @symcore.pow(params[1], @symcore.int(-1))])),
                  ]))
                "Lomax" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.mul([
                      params[1],
                      eval_arith(@symcore.add([
                        @symcore.pow(
                          eval_arith(@symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), q]),
                          ])),
                          @symcore.mul([
                            @symcore.int(-1),
                            @symcore.pow(params[0], @symcore.int(-1)),
                          ]),
                        ),
                        @symcore.int(-1),
                      ])),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Reciprocal" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.mul([
                      params[0],
                      @symcore.pow(
                        eval_arith(@symcore.mul([
                          params[1],
                          @symcore.pow(params[0], @symcore.int(-1)),
                        ])),
                        q,
                      ),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Gompertz" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.mul([
                      @symcore.pow(params[0], @symcore.int(-1)),
                      @symcore.function("log", [eval_arith(@symcore.add([
                        @symcore.int(1),
                        @symcore.mul([
                          @symcore.int(-1),
                          @symcore.function("log", [eval_arith(@symcore.add([
                            @symcore.int(1),
                            @symcore.mul([@symcore.int(-1), q]),
                          ]))]),
                          @symcore.pow(params[1], @symcore.int(-1)),
                        ]),
                      ]))]),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "Levy" if params.length() == 2 =>
                  compat_piecewise2(
                    eval_arith(@symcore.add([
                      params[0],
                      @symcore.mul([
                        params[1],
                        @symcore.pow(eval_arith(@symcore.mul([
                          @symcore.int(2),
                          @symcore.pow(@symcore.function("erfcinv", [q]), @symcore.int(2)),
                        ])), @symcore.int(-1)),
                      ]),
                    ])),
                    @symcore.function("And", [
                      @symcore.function("Ge", [q, @symcore.int(0)]),
                      @symcore.function("Le", [q, @symcore.int(1)]),
                    ]),
                    @symcore.symbol("nan"),
                  )
                "LogNormal" if params.length() == 2 =>
                  eval_arith(@symcore.function("exp", [
                    eval_arith(@symcore.add([
                      params[0],
                      eval_arith(@symcore.mul([
                        params[1],
                        @symcore.function("sqrt", [@symcore.int(2)]),
                        @symcore.function("erfinv", [eval_arith(@symcore.add([eval_arith(@symcore.mul([@symcore.int(2), q])), @symcore.int(-1)]))]),
                      ])),
                    ])),
                  ]))
                _ => symbolic_metric_with_head(name, "Quantile", q, params)
              }
          }
        }
        _ => @symcore.function("quantile", [expr, q])
      }
    None => @symcore.function("quantile", [expr, q])
  }
}

///|
pub fn coskewness(a : @symcore.Expr, b : @symcore.Expr, c : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("coskewness", [a, b, c])
}

///|
pub fn marginal_distribution(expr : @symcore.Expr, vars : Array[@symcore.Expr]) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = [expr]
  for v in vars {
    args.push(v)
  }
  @symcore.function("marginal_distribution", args)
}

///|
pub fn generator_matrix_of(obj : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("GeneratorMatrixOf", [obj])
}

///|
pub fn transition_matrix_of(obj : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("TransitionMatrixOf", [obj])
}

///|
pub fn stochastic_state_space_of(obj : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("StochasticStateSpaceOf", [obj])
}

///|
fn finite_central_moment(rv : RandomVar, n : Int) -> @symcore.Expr? {
  match rv.kind {
    RVKind::Finite(items) =>
      match finite_expectation(rv) {
        Some(mu) => {
          let terms : Array[@symcore.Expr] = Array::new()
          for item in items {
            let (value, p) = item
            let centered = eval_arith(@symcore.add([value, @symcore.mul([@symcore.int(-1), mu])]))
            terms.push(eval_arith(@symcore.mul([expr_from_big_rational(p), @symcore.pow(centered, @symcore.int(n))])))
          }
          Some(eval_arith(@symcore.add(terms)))
        }
        None => None
      }
    _ => None
  }
}

///|
pub fn central_moment(expr : @symcore.Expr, n : Int, rvs? : Array[RandomVar] = []) -> @symcore.Expr {
  match resolve_rv(expr, rvs) {
    Some(rv) =>
      match finite_central_moment(rv, n) {
        Some(v) => return v
        None => ()
      }
    None => ()
  }
  let mu = expectation(expr, rvs~)
  let centered = eval_arith(@symcore.add([expr, @symcore.mul([@symcore.int(-1), mu])]))
  expectation(@symcore.pow(centered, @symcore.int(n)), rvs~)
}

///|
pub fn expectation_matrix(exprs : Array[@symcore.Expr], rvs? : Array[RandomVar] = []) -> Array[@symcore.Expr] {
  exprs.map(e0 => expectation(e0, rvs~))
}

///|
pub fn variance_matrix(exprs : Array[@symcore.Expr], rvs? : Array[RandomVar] = []) -> Array[Array[@symcore.Expr]] {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<exprs.length() {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<exprs.length() {
      row.push(covariance(exprs[i], exprs[j], rvs~))
    }
    out.push(row)
  }
  out
}

///|
pub fn cross_covariance_matrix(
  xs : Array[@symcore.Expr],
  ys : Array[@symcore.Expr],
  rvs? : Array[RandomVar] = [],
) -> Array[Array[@symcore.Expr]] {
  let out : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<xs.length() {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<ys.length() {
      row.push(covariance(xs[i], ys[j], rvs~))
    }
    out.push(row)
  }
  out
}

///|
pub fn joint_eigen_distribution(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "JointEigenDistribution", params)
}

///|
pub fn level_spacing_distribution(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "level_spacing_distribution", params)
}

///|
pub fn matrix_gamma(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MatrixGamma", params)
}

///|
pub fn matrix_student_t(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MatrixStudentT", params)
}

///|
pub fn gamma(name : String, shape : @symcore.Expr, scale : @symcore.Expr) -> RandomVar {
  gamma_dist(name, shape, scale)
}

///|
pub fn wishart(name : String, df : @symcore.Expr, scale : @symcore.Expr) -> RandomVar {
  wishart_rv(name, df, scale)
}

///|
pub fn matrix_normal(
  name : String,
  mean : @symcore.Expr,
  rowcov : @symcore.Expr,
  colcov : @symcore.Expr,
) -> RandomVar {
  matrix_normal_rv(name, mean, rowcov, colcov)
}

///|
pub fn beta_binomial(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "BetaBinomial", params)
}

///|
pub fn hypergeometric(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Hypergeometric", params)
}

///|
pub fn rademacher(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  ignore(params)
  let half = try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  finite_rv(
    name,
    [
      (@symcore.int(-1), half),
      (@symcore.int(1), half),
    ],
  )
}

///|
pub fn ideal_soliton(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "IdealSoliton", params)
}

///|
pub fn robust_soliton(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "RobustSoliton", params)
}

///|
pub fn finite_distribution_handmade(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "FiniteDistributionHandmade", params)
}

///|
pub fn continuous_rv(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ContinuousRV", params)
}

///|
pub fn arcsin(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Arcsin", params)
}

///|
pub fn benini(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Benini", params)
}

///|
pub fn beta(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Beta", params)
}

///|
pub fn beta_noncentral(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "BetaNoncentral", params)
}

///|
pub fn beta_prime(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "BetaPrime", params)
}

///|
pub fn bounded_pareto(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "BoundedPareto", params)
}

///|
pub fn cauchy(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Cauchy", params)
}

///|
pub fn chi(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Chi", params)
}

///|
pub fn chi_noncentral(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ChiNoncentral", params)
}

///|
pub fn chi_squared(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ChiSquared", params)
}

///|
pub fn dagum(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Dagum", params)
}

///|
pub fn davis(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Davis", params)
}

///|
pub fn erlang(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Erlang", params)
}

///|
pub fn ex_gaussian(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ExGaussian", params)
}

///|
pub fn exponential_power(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ExponentialPower", params)
}

///|
pub fn f_distribution(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "FDistribution", params)
}

///|
pub fn fisher_z(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "FisherZ", params)
}

///|
pub fn frechet(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Frechet", params)
}

///|
pub fn gamma_inverse(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GammaInverse", params)
}

///|
pub fn gompertz(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Gompertz", params)
}

///|
pub fn gumbel(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Gumbel", params)
}

///|
pub fn kumaraswamy(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Kumaraswamy", params)
}

///|
pub fn laplace(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Laplace", params)
}

///|
pub fn levy(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Levy", params)
}

///|
pub fn logistic(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Logistic", params)
}

///|
pub fn log_cauchy(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "LogCauchy", params)
}

///|
pub fn log_logistic(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "LogLogistic", params)
}

///|
pub fn logit_normal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "LogitNormal", params)
}

///|
pub fn log_normal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "LogNormal", params)
}

///|
pub fn lomax(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Lomax", params)
}

///|
pub fn moyal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Moyal", params)
}

///|
pub fn maxwell(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Maxwell", params)
}

///|
pub fn nakagami(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Nakagami", params)
}

///|
pub fn gaussian_inverse(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GaussianInverse", params)
}

///|
pub fn pareto(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Pareto", params)
}

///|
pub fn power_function(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "PowerFunction", params)
}

///|
pub fn quadratic_u(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "QuadraticU", params)
}

///|
pub fn raised_cosine(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "RaisedCosine", params)
}

///|
pub fn rayleigh(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Rayleigh", params)
}

///|
pub fn reciprocal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Reciprocal", params)
}

///|
pub fn student_t(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "StudentT", params)
}

///|
pub fn shifted_gompertz(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ShiftedGompertz", params)
}

///|
pub fn trapezoidal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Trapezoidal", params)
}

///|
pub fn triangular(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Triangular", params)
}

///|
pub fn uniform(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Uniform", params)
}

///|
pub fn uniform_sum(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "UniformSum", params)
}

///|
pub fn von_mises(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "VonMises", params)
}

///|
pub fn wald(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Wald", params)
}

///|
pub fn weibull(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Weibull", params)
}

///|
pub fn wigner_semicircle(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "WignerSemicircle", params)
}

///|
pub fn continuous_distribution_handmade(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ContinuousDistributionHandmade", params)
}

///|
pub fn flory_schulz(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "FlorySchulz", params)
}

///|
pub fn hermite(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Hermite", params)
}

///|
pub fn logarithmic(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Logarithmic", params)
}

///|
pub fn skellam(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Skellam", params)
}

///|
pub fn yule_simon(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "YuleSimon", params)
}

///|
pub fn zeta(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Zeta", params)
}

///|
pub fn discrete_rv(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "DiscreteRV", params)
}

///|
pub fn discrete_distribution_handmade(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "DiscreteDistributionHandmade", params)
}

///|
pub fn joint_rv(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "JointRV", params)
}

///|
pub fn dirichlet(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Dirichlet", params)
}

///|
pub fn generalized_multivariate_log_gamma(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GeneralizedMultivariateLogGamma", params)
}

///|
pub fn generalized_multivariate_log_gamma_omega(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GeneralizedMultivariateLogGammaOmega", params)
}

///|
pub fn multinomial(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "Multinomial", params)
}

///|
pub fn multivariate_beta(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MultivariateBeta", params)
}

///|
pub fn multivariate_ewens(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MultivariateEwens", params)
}

///|
pub fn multivariate_t(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MultivariateT", params)
}

///|
pub fn negative_multinomial(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "NegativeMultinomial", params)
}

///|
pub fn normal_gamma(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "NormalGamma", params)
}

///|
pub fn multivariate_normal(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MultivariateNormal", params)
}

///|
pub fn multivariate_laplace(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "MultivariateLaplace", params)
}

///|
pub fn stochastic_process(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "StochasticProcess", params)
}

///|
pub fn discrete_time_stochastic_process(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "DiscreteTimeStochasticProcess", params)
}

///|
pub fn discrete_markov_chain(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "DiscreteMarkovChain", params)
}

///|
pub fn continuous_markov_chain(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "ContinuousMarkovChain", params)
}

///|
pub fn bernoulli_process(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "BernoulliProcess", params)
}

///|
pub fn gamma_process(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GammaProcess", params)
}

///|
pub fn circular_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "CircularEnsemble", params)
}

///|
pub fn circular_unitary_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "CircularUnitaryEnsemble", params)
}

///|
pub fn circular_orthogonal_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "CircularOrthogonalEnsemble", params)
}

///|
pub fn circular_symplectic_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "CircularSymplecticEnsemble", params)
}

///|
pub fn gaussian_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GaussianEnsemble", params)
}

///|
pub fn gaussian_unitary_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GaussianUnitaryEnsemble", params)
}

///|
pub fn gaussian_orthogonal_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GaussianOrthogonalEnsemble", params)
}

///|
pub fn gaussian_symplectic_ensemble(name : String, params? : Array[@symcore.Expr] = []) -> RandomVar {
  symbolic_rv(name, "GaussianSymplecticEnsemble", params)
}
