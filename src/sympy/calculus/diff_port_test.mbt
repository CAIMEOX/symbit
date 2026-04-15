///|
test "diff tan and gamma" {
  let x = @symcore.Expr::Symbol("x")
  let tanx = @symcore.function("tan", [x])
  let gammax = @symcore.function("gamma", [x])
  let dt = diff(tanx, x)
  let dg = diff(gammax, x)
  assert_eq(@symprint.pretty_string(dt), "sec(x)**2")
  assert_eq(@symprint.pretty_string(dg), "gamma(x)*digamma(x)")
}

///|
test "diff named apply heads preserve explicit elementary rules" {
  let x = @symcore.Expr::Symbol("x")
  let rate = @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_exact_parts(
      @symnum.BigRational::one(),
      @symnum.BigRational::one(),
      prec=100,
    ),
  )
  let expr = @symcore.function("exp", [@symcore.mul([rate, x])])
  let deriv = diff(expr, x)
  let env : Map[String, @symcore.Expr] = {}
  env["x"] = @symcore.Expr::Float(@symcore.Float::from_rational(1N, 10N, 120))
  match @symcore.evalf(@symcore.subst(deriv, env), prec=120) {
    @symcore.Expr::Float(value) => assert_true(value.is_finite())
    @symcore.Expr::ComplexFloat(value) => assert_true(value.is_finite())
    _ => fail("expected finite numeric derivative value")
  }
}
