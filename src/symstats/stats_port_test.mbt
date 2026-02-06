///|
fn expr_str(expr : @symcore.Expr) -> String {
  @symprint.to_string(expr)
}

///|
fn event_str(event : Event) -> String {
  expr_str(event_to_expr(event))
}

///|
fn expr_equiv(ours : @symcore.Expr, oracle_expr : String) -> Bool {
  let ours_str = expr_str(ours)
  let res : Result[Bool, Error] = try? @sympy_stats.stats_expr_equiv(
    ours_str,
    oracle_expr,
  )
  match res {
    Ok(ok) => ok
    Err(_) => false
  }
}

///|
fn oracle_prob_unary(rv_name : String, rv_decl : String, event : Event) -> String {
  let query = "(lambda \{rv_name}: P(\{event_str(event)}))(\{rv_decl})"
  let res : Result[String, Error] = try? @sympy_stats.stats_eval_str(query)
  match res {
    Ok(v) => v
    Err(_) => "__oracle_error__"
  }
}

///|
fn oracle_expect_unary(rv_name : String, rv_decl : String, expr : @symcore.Expr) -> String {
  let query = "(lambda \{rv_name}: E(\{expr_str(expr)}))(\{rv_decl})"
  let res : Result[String, Error] = try? @sympy_stats.stats_eval_str(query)
  match res {
    Ok(v) => v
    Err(_) => "__oracle_error__"
  }
}

///|
fn oracle_variance_unary(rv_name : String, rv_decl : String) -> String {
  let query = "(lambda \{rv_name}: variance(\{rv_name}))(\{rv_decl})"
  let res : Result[String, Error] = try? @sympy_stats.stats_eval_str(query)
  match res {
    Ok(v) => v
    Err(_) => "__oracle_error__"
  }
}

///|
test "stage1 wrappers smoke" {
  let x = @symcore.symbol("X")
  let e = eq(x, @symcore.int(1))
  inspect(expr_str(probability(e)), content="Probability(Eq(X, 1))")
  inspect(expr_str(expectation(x)), content="Expectation(X)")
  inspect(expr_str(variance(x)), content="Variance(X)")
  inspect(expr_str(covariance(x, @symcore.symbol("Y"))), content="Covariance(X, Y)")
}

///|
test "stage2 finite die parity" {
  let x = die("X", sides=6)
  let event = eq(@symcore.symbol("X"), @symcore.int(3))
  let ours = probability(event, rv=x)
  let oracle = oracle_prob_unary("X", "Die('X', 6)", event)
  assert_true(expr_equiv(ours, oracle))
  let event2 = le(@symcore.symbol("X"), @symcore.int(2))
  let ours2 = probability(event2, rv=x)
  let oracle2 = oracle_prob_unary("X", "Die('X', 6)", event2)
  assert_true(expr_equiv(ours2, oracle2))
}

///|
test "stage2 finite bernoulli mean variance parity" {
  let p = try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(3))
  let x = bernoulli("X", p)
  let sx = @symcore.symbol("X")
  let ours_e = expectation(sx, rvs=[x])
  let oracle_e = oracle_expect_unary("X", "Bernoulli('X', Rational(1, 3))", sx)
  assert_true(expr_equiv(ours_e, oracle_e))
  let ours_v = variance(sx, rvs=[x])
  let oracle_v = oracle_variance_unary("X", "Bernoulli('X', Rational(1, 3))")
  assert_true(expr_equiv(ours_v, oracle_v))
}

///|
test "stage2 discrete uniform expectation" {
  let x = discrete_uniform("X", [@symcore.int(1), @symcore.int(3), @symcore.int(5)])
  let ours = expectation(@symcore.symbol("X"), rvs=[x])
  let oracle = oracle_expect_unary(
    "X",
    "DiscreteUniform('X', [1, 3, 5])",
    @symcore.symbol("X"),
  )
  assert_true(expr_equiv(ours, oracle))
}

///|
test "stage3 symbolic wrappers keep canonical form" {
  let x = @symcore.symbol("X")
  let y = @symcore.symbol("Y")
  let event = and_event([ge(x, @symcore.int(0)), le(x, @symcore.int(2))])
  inspect(
    expr_str(probability(event)),
    content="Probability(And(Ge(X, 0), Le(X, 2)))",
  )
  inspect(expr_str(expectation(@symcore.add([x, y]))), content="Expectation((X + Y))")
}

///|
test "stage4 binomial parity" {
  let n = @symcore.int(5)
  let p = try! @symcore.rational_from_ints(1, 3)
  let x = binomial("X", n, p)
  let sx = @symcore.symbol("X")
  let ours_mean = expectation(sx, rvs=[x])
  let oracle_mean = oracle_expect_unary("X", "Binomial('X', 5, Rational(1, 3))", sx)
  assert_true(expr_equiv(ours_mean, oracle_mean))
  let ours_var = variance(sx, rvs=[x])
  let oracle_var = oracle_variance_unary("X", "Binomial('X', 5, Rational(1, 3))")
  assert_true(expr_equiv(ours_var, oracle_var))
  let event = eq(sx, @symcore.int(2))
  let ours_prob = probability(event, rv=x)
  let oracle_prob = oracle_prob_unary("X", "Binomial('X', 5, Rational(1, 3))", event)
  assert_true(expr_equiv(ours_prob, oracle_prob))
}

///|
test "stage4 geometric and negbin parity" {
  let p = try! @symcore.rational_from_ints(1, 2)
  let g = geometric("G", p)
  let event = le(@symcore.symbol("G"), @symcore.int(3))
  let ours = probability(event, rv=g)
  let oracle = oracle_prob_unary("G", "Geometric('G', Rational(1, 2))", event)
  assert_true(expr_equiv(ours, oracle))
  let nb = negative_binomial("K", @symcore.int(3), p)
  let event2 = eq(@symcore.symbol("K"), @symcore.int(2))
  let ours2 = probability(event2, rv=nb)
  let oracle2 = oracle_prob_unary(
    "K",
    "NegativeBinomial('K', 3, Rational(1, 2))",
    event2,
  )
  assert_true(expr_equiv(ours2, oracle2))
}

///|
test "stage5 normal and exponential parity" {
  let n01 = normal("X", @symcore.int(0), @symcore.int(1))
  let x = @symcore.symbol("x")
  let ours_pdf = density(n01, x)
  let oracle_pdf = try! @sympy_stats.stats_eval_str(
    "(lambda X, x: density(X)(x))(Normal('X', 0, 1), x)",
  )
  assert_true(expr_equiv(ours_pdf, oracle_pdf))
  let event = le(@symcore.symbol("X"), @symcore.int(0))
  let ours_p = probability(event, rv=n01)
  let oracle_p = oracle_prob_unary("X", "Normal('X', 0, 1)", event)
  assert_true(expr_equiv(ours_p, oracle_p))

  let e = exponential("Y", @symcore.int(2))
  let y = @symcore.symbol("y")
  let ours_cdf = cdf(e, y)
  let oracle_cdf = try! @sympy_stats.stats_eval_str(
    "(lambda Y, y: cdf(Y)(y))(Exponential('Y', 2), y)",
  )
  assert_true(expr_equiv(ours_cdf, oracle_cdf))
}

///|
test "stage5 gamma mean variance parity" {
  let g = gamma_dist("G", @symcore.int(3), @symcore.int(2))
  let sg = @symcore.symbol("G")
  let ours_e = expectation(sg, rvs=[g])
  let oracle_e = oracle_expect_unary("G", "Gamma('G', 3, 2)", sg)
  assert_true(expr_equiv(ours_e, oracle_e))
  let ours_v = variance(sg, rvs=[g])
  let oracle_v = oracle_variance_unary("G", "Gamma('G', 3, 2)")
  assert_true(expr_equiv(ours_v, oracle_v))
}

///|
test "stage6 joint independent parity" {
  let x = die("X", sides=6)
  let y = die("Y", sides=6)
  let j = joint_independent("J", [x, y])
  let event = and_event([
    eq(@symcore.symbol("X"), @symcore.int(1)),
    eq(@symcore.symbol("Y"), @symcore.int(1)),
  ])
  let ours = probability(event, rv=j)
  let oracle = try! @sympy_stats.stats_eval_str(
    "(lambda X, Y: P(Eq(X, 1) & Eq(Y, 1)))(Die('X', 6), Die('Y', 6))",
  )
  assert_true(expr_equiv(ours, oracle))
  let cov = covariance(@symcore.symbol("X"), @symcore.symbol("Y"), rvs=[x, y])
  inspect(expr_str(cov), content="0")
}

///|
test "stage7 compound and variance_prop" {
  let half = try! @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  let d = die("A", sides=6)
  let b = bernoulli("B", half)
  let z = compound_rv("Z", [(half, d), (half, b)])
  let sz = @symcore.symbol("Z")
  let mean_z = expectation(sz, rvs=[z])
  assert_true(try! @sympy_stats.stats_expr_equiv(expr_str(mean_z), "2"))
  let var_z = variance(sz, rvs=[z])
  assert_true(try! @sympy_stats.stats_expr_equiv(expr_str(var_z), "23/6"))

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.add([
    @symcore.mul([@symcore.int(2), x]),
    @symcore.mul([@symcore.int(3), y]),
  ])
  let vars : Map[String, @symcore.Expr] = {
    "x": @symcore.symbol("Vx"),
    "y": @symcore.symbol("Vy"),
  }
  let covs : Map[String, @symcore.Expr] = {}
  covs[cov_key("x", "y")] = @symcore.symbol("Cxy")
  let propagated = variance_prop(expr, vars, covariances=covs)
  assert_eq(expr_str(propagated), "4*Vx + 9*Vy + 12*Cxy")
}

///|
test "stage8 process and matrix starter parity" {
  let n = poisson_process("N", @symcore.int(1))
  let t = @symcore.symbol("t")
  let ours = process_mean_at(n, t)
  match ours {
    Some(v) => {
      let oracle = try! @sympy_stats.stats_eval_str(
        "(lambda N, t: E(N(t)))(PoissonProcess('N', 1), t)",
      )
      assert_true(expr_equiv(v, oracle))
    }
    None => fail("missing process mean")
  }
  let w = wiener_process("W")
  match process_variance_at(w, t) {
    Some(v) => {
      let oracle = try! @sympy_stats.stats_eval_str(
        "(lambda W, t: variance(W(t)))(WienerProcess('W'), t)",
      )
      assert_true(expr_equiv(v, oracle))
    }
    None => fail("missing process variance")
  }

  let wrv = wishart_rv("S", @symcore.int(4), @symcore.symbol("Sigma"))
  let dens = matrix_density(wrv, @symcore.symbol("X"))
  match dens {
    Some(v) => inspect(expr_str(v), content="WishartDensity(X, 4, Sigma)")
    None => fail("missing wishart density")
  }
}
