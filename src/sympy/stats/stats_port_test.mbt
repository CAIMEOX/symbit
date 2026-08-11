///|
fn expr_str(expr : @symcore.Expr) -> String {
  @symprint.pretty_string(expr)
}

///|
fn compact_expr_str(value : String) -> String {
  value.replace_all(old=" ", new="")
}

///|
fn expr_equiv(ours : @symcore.Expr, oracle_expr : String) -> Bool {
  let ours_str = expr_str(ours)
  compact_expr_str(ours_str) == compact_expr_str(oracle_expr)
}

///|
test "stage1 wrappers smoke" {
  let x = @symcore.Expr::Symbol("X")
  let e = eq(x, @symcore.int(1))
  inspect(expr_str(probability(e)), content="Probability(Eq(X, 1))")
  inspect(expr_str(expectation(x)), content="Expectation(X)")
  inspect(expr_str(variance(x)), content="Variance(X)")
  inspect(
    expr_str(covariance(x, @symcore.Expr::Symbol("Y"))),
    content="Covariance(X, Y)",
  )
}

///|
test "stage2 finite die parity" {
  let x = die("X", sides=6)
  let event = eq(@symcore.Expr::Symbol("X"), @symcore.int(3))
  let ours = probability(event, rv=x)
  assert_true(expr_equiv(ours, "1/6"))
  let event2 = le(@symcore.Expr::Symbol("X"), @symcore.int(2))
  let ours2 = probability(event2, rv=x)
  assert_true(expr_equiv(ours2, "1/3"))
}

///|
test "stage2 finite bernoulli mean variance parity" {
  let p = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(3))
  let x = bernoulli("X", p)
  let sx = @symcore.Expr::Symbol("X")
  let ours_e = expectation(sx, rvs=[x])
  assert_true(expr_equiv(ours_e, "1/3"))
  let ours_v = variance(sx, rvs=[x])
  assert_true(expr_equiv(ours_v, "2/9"))
}

///|
test "stage2 discrete uniform expectation" {
  let x = discrete_uniform("X", [
    @symcore.int(1),
    @symcore.int(3),
    @symcore.int(5),
  ])
  let ours = expectation(@symcore.Expr::Symbol("X"), rvs=[x])
  assert_true(expr_equiv(ours, "3"))
}

///|
test "stage3 symbolic wrappers keep canonical form" {
  let x = @symcore.Expr::Symbol("X")
  let y = @symcore.Expr::Symbol("Y")
  let event = and_event([ge(x, @symcore.int(0)), le(x, @symcore.int(2))])
  inspect(
    expr_str(probability(event)),
    content="Probability(And(X >= 0, X <= 2))",
  )
  inspect(
    expr_str(expectation(@symcore.add([x, y]))),
    content="Expectation(X + Y)",
  )
}

///|
test "stage4 binomial parity" {
  let n = @symcore.int(5)
  let p = @symcore.rational_from_ints(1, 3)
  let x = binomial("X", n, p)
  let sx = @symcore.Expr::Symbol("X")
  let ours_mean = expectation(sx, rvs=[x])
  assert_true(expr_equiv(ours_mean, "5/3"))
  let ours_var = variance(sx, rvs=[x])
  assert_true(expr_equiv(ours_var, "10/9"))
  let event = eq(sx, @symcore.int(2))
  let ours_prob = probability(event, rv=x)
  assert_true(expr_equiv(ours_prob, "80/243"))
}

///|
test "stage4 geometric and negbin parity" {
  let p = @symcore.rational_from_ints(1, 2)
  let g = geometric("G", p)
  let event = le(@symcore.Expr::Symbol("G"), @symcore.int(3))
  let ours = probability(event, rv=g)
  assert_true(expr_equiv(ours, "7/8"))
  let nb = negative_binomial("K", @symcore.int(3), p)
  let event2 = eq(@symcore.Expr::Symbol("K"), @symcore.int(2))
  let ours2 = probability(event2, rv=nb)
  assert_true(expr_equiv(ours2, "3/16"))
}

///|
test "stage5 normal and exponential parity" {
  let n01 = normal("X", @symcore.int(0), @symcore.int(1))
  let x = @symcore.Expr::Symbol("x")
  let ours_pdf = density(n01, x)
  let pdf_s = compact_expr_str(expr_str(ours_pdf))
  assert_true(pdf_s.contains("exp("))
  assert_true(pdf_s.contains("x**2"))
  assert_true(pdf_s.contains("pi"))
  let event = le(@symcore.Expr::Symbol("X"), @symcore.int(0))
  let ours_p = probability(event, rv=n01)
  assert_true(expr_equiv(ours_p, "1/2"))

  let e = exponential("Y", @symcore.int(2))
  let y = @symcore.Expr::Symbol("y")
  let ours_cdf = cdf(e, y)
  let cdf_s = compact_expr_str(expr_str(ours_cdf))
  assert_true(cdf_s.contains("1-exp(-2*y)"))
  assert_true(cdf_s.contains("y<0"))
}

///|
test "stage5 gamma mean variance parity" {
  let g = gamma_dist("G", @symcore.int(3), @symcore.int(2))
  let sg = @symcore.Expr::Symbol("G")
  let ours_e = expectation(sg, rvs=[g])
  assert_true(expr_equiv(ours_e, "6"))
  let ours_v = variance(sg, rvs=[g])
  assert_true(expr_equiv(ours_v, "12"))
}

///|
test "stage6 joint independent parity" {
  let x = die("X", sides=6)
  let y = die("Y", sides=6)
  let j = joint_independent("J", [x, y])
  let event = and_event([
    eq(@symcore.Expr::Symbol("X"), @symcore.int(1)),
    eq(@symcore.Expr::Symbol("Y"), @symcore.int(1)),
  ])
  let ours = probability(event, rv=j)
  assert_true(expr_equiv(ours, "1/36"))
  let cov = covariance(@symcore.Expr::Symbol("X"), @symcore.Expr::Symbol("Y"), rvs=[
    x, y,
  ])
  inspect(expr_str(cov), content="0")
}

///|
test "stage7 compound and variance_prop" {
  let half = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  let d = die("A", sides=6)
  let b = bernoulli("B", half)
  let z = compound_rv("Z", [(half, d), (half, b)])
  let sz = @symcore.Expr::Symbol("Z")
  let mean_z = expectation(sz, rvs=[z])
  assert_eq(compact_expr_str(expr_str(mean_z)), "2")
  let var_z = variance(sz, rvs=[z])
  assert_eq(compact_expr_str(expr_str(var_z)), "23/6")

  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.add([
    @symcore.mul([@symcore.int(2), x]),
    @symcore.mul([@symcore.int(3), y]),
  ])
  let vars : Map[String, @symcore.Expr] = {
    "x": @symcore.Expr::Symbol("Vx"),
    "y": @symcore.Expr::Symbol("Vy"),
  }
  let covs : Map[String, @symcore.Expr] = Map([])
  covs[cov_key("x", "y")] = @symcore.Expr::Symbol("Cxy")
  let propagated = variance_prop(expr, vars, covariances=covs)
  assert_eq(expr_str(propagated), "4*Vx + 9*Vy + 12*Cxy")
}

///|
test "stage8 process and matrix starter parity" {
  let n = poisson_process("N", @symcore.int(1))
  let t = @symcore.Expr::Symbol("t")
  let ours = process_mean_at(n, t)
  match ours {
    Some(v) => assert_true(expr_equiv(v, "t"))
    None => fail("missing process mean")
  }
  let w = wiener_process("W")
  match process_variance_at(w, t) {
    Some(v) => assert_true(expr_equiv(v, "t"))
    None => fail("missing process variance")
  }

  let sigma = stats_matrix_literal([
    [@symcore.int(1), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(1)],
  ])
  let xmat = stats_matrix_literal([
    [@symcore.int(2), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(2)],
  ])
  let wrv = wishart_rv("S", @symcore.int(5), sigma)
  let dens = matrix_density(wrv, xmat)
  match dens {
    Some(v) => {
      assert_true(expr_str(v).contains("Determinant"))
      assert_true(expr_str(v).contains("Trace"))
      assert_true(!expr_str(v).contains("WishartDensity("))
    }
    None => fail("missing wishart density")
  }
}
