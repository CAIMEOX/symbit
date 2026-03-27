///|
fn exact_complex_rate_expr(
  real_num : Int,
  real_den : Int,
  imag_num : Int,
  imag_den : Int,
  prec? : Int = 90,
) -> @symcore.Expr {
  let real = @symnum.BigRational::from_ints(real_num, real_den) catch {
    _ => @symnum.BigRational::zero()
  }
  let imag = @symnum.BigRational::from_ints(imag_num, imag_den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_exact_parts(real, imag, prec~),
  )
}

///|
test "symcalculus diff handles named apply heads structurally" {
  let x = @symcore.Expr::Symbol("x")
  let deriv = diff(@symcore.function("sin", [x]), x)
  inspect(@symcore.compare_expr(deriv, @symcore.function("cos", [x])), content="0")
}

///|
test "symcalculus diff of complex exponential evaluates at numeric points" {
  let x = @symcore.Expr::Symbol("x")
  let rate = exact_complex_rate_expr(1, 1, 1, 1, prec=100)
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
