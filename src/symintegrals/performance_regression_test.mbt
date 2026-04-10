///|
fn x() -> Expr {
  @symcore.Expr::Symbol("x")
}

///|
fn t() -> Expr {
  @symcore.Expr::Symbol("t")
}

///|
fn s() -> Expr {
  @symcore.Expr::Symbol("s")
}

///|
fn perf_div(lhs : Expr, rhs : Expr) -> Expr {
  @symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))])
}

///|
fn perf_linear_factor(i : Int) -> Expr {
  x() - @symcore.int(i)
}

///|
fn perf_product_linear_factors(start : Int, count : Int) -> Expr {
  let mut expr = @symcore.int(1)
  for i in start..<(start + count) {
    expr = expr * perf_linear_factor(i)
  }
  expr
}

///|
fn perf_expr_equal(lhs : Expr, rhs : Expr) -> Bool {
  @symsimplify.simplify(lhs + @symcore.int(-1) * rhs) == @symcore.int(0)
}

///|
test "integrals exact polynomial antiderivative benchmark family" {
  let integrand = @symsimplify.numer_expand(perf_product_linear_factors(1, 8))
  let result = integrate(integrand, limits=[integral_limit([x()])])
  assert_true(perf_expr_equal(@symcalculus.diff(result, x()), integrand))
}

///|
test "laplace shifted exponential polynomial benchmark family" {
  let expr = @symelem.exp(@symcore.int(-2) * t()) *
    ((t() ^ @symcore.int(6)) + @symcore.int(3) * t() + @symcore.int(1))
  let shifted = s() + @symcore.int(2)
  let expected = perf_div(
    @symcore.int(720),
    shifted ^ @symcore.int(7),
  ) +
    perf_div(@symcore.int(3), shifted ^ @symcore.int(2)) +
    perf_div(@symcore.int(1), shifted)
  assert_true(
    perf_expr_equal(
      laplace_transform_eval(expr, t(), s(), noconds=true),
      expected,
    ),
  )
}
