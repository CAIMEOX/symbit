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
  inspect(
    @symcore.compare_expr(deriv, @symcore.function("cos", [x])),
    content="0",
  )
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

///|
test "symcalculus diff applies chain rule to undefined functions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let xi = @symcore.Expr::Symbol("_xi0")
  let expr = @symcore.applied_undefined_function("F", [
    @symcore.add([
      @symcore.pow(x, @symcore.int(2)),
      @symcore.pow(y, @symcore.int(2)),
    ]),
  ])
  let inner = @symcore.add([
    @symcore.pow(x, @symcore.int(2)),
    @symcore.pow(y, @symcore.int(2)),
  ])
  let expected_x = @symcore.mul([
    @symcore.int(2),
    x,
    @symcore.Expr::Subs(
      derivative_expr(@symcore.applied_undefined_function("F", [xi]), [xi]),
      xi,
      inner,
    ),
  ])
  let expected_y = @symcore.mul([
    @symcore.int(2),
    y,
    @symcore.Expr::Subs(
      derivative_expr(@symcore.applied_undefined_function("F", [xi]), [xi]),
      xi,
      inner,
    ),
  ])
  inspect(
    @symcore.compare_expr(diff(expr, x), expected_x),
    content="0",
  )
  inspect(
    @symcore.compare_expr(diff(expr, y), expected_y),
    content="0",
  )
}

///|
test "symcalculus diff evaluates Subs of derivative placeholders by chain rule" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let xi = @symcore.Expr::Symbol("_xi0")
  let inner = @symcore.add([@symcore.mul([a, x]), @symcore.mul([b, y])])
  let subs_deriv = @symcore.Expr::Subs(
    derivative_expr(@symcore.applied_undefined_function("F", [xi]), [xi]),
    xi,
    inner,
  )
  let expected_dx = @symcore.mul([
    a,
    @symcore.Expr::Subs(
      derivative_expr(@symcore.applied_undefined_function("F", [xi]), [xi, @symcore.int(2)]),
      xi,
      inner,
    ),
  ])
  let expected_dy = @symcore.mul([
    b,
    @symcore.Expr::Subs(
      derivative_expr(@symcore.applied_undefined_function("F", [xi]), [xi, @symcore.int(2)]),
      xi,
      inner,
    ),
  ])
  inspect(@symcore.compare_expr(diff(subs_deriv, x), expected_dx), content="0")
  inspect(@symcore.compare_expr(diff(subs_deriv, y), expected_dy), content="0")
}

///|
test "symcalculus diff applies explicit sqrt derivative" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function(
    "sqrt",
    [
      @symcore.add([
        @symcore.pow(x, @symcore.int(2)),
        @symcore.int(1),
      ]),
    ],
  )
  let expected = @symcore.mul([
    @symcore.int(2),
    x,
    @symcore.pow(
      @symcore.mul([
        @symcore.int(2),
        @symcore.function(
          "sqrt",
          [
            @symcore.add([
              @symcore.pow(x, @symcore.int(2)),
              @symcore.int(1),
            ]),
          ],
        ),
      ]),
      @symcore.int(-1),
    ),
  ])
  inspect(
    @symcore.compare_expr(diff(expr, x), expected),
    content="0",
  )
}
