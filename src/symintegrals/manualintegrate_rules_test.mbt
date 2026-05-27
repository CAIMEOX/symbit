///|
test "symintegrals manual rule helpers produce evaluable steps" {
  let x = @symcore.Expr::Symbol("x")
  let info_const = integral_info(@symcore.int(3), x)
  guard constant_rule(info_const) is Some(const_step) else {
    fail("expected constant rule")
  }
  guard const_step.eval() is Some(const_value) else {
    fail("expected constant rule value")
  }
  assert_true(@symcore.compare_expr(const_value, @symcore.int(3) * x) == 0)

  let info_power = integral_info(x ^ @symcore.int(2), x)
  guard power_rule(info_power) is Some(power_step) else {
    fail("expected power rule")
  }
  guard power_step.eval() is Some(power_value) else {
    fail("expected power rule value")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        power_value - @symcore.rational_from_ints(1, 3) * (x ^ @symcore.int(3)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )

  let generic = integral_steps(@symelem.exp(x), x)
  assert_true(!generic.contains_dont_know())
}

///|
test "symintegrals manual substitution helpers differentiate and substitute" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let tan_deriv = manual_diff(@symelem.tan(x), x)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(tan_deriv - (@symelem.sec(x) ^ @symcore.int(2))),
      @symcore.int(0),
    ) ==
    0,
  )
  assert_true(
    @symcore.compare_expr(
      manual_subs(x + y, x, @symcore.int(2)),
      y + @symcore.int(2),
    ) ==
    0,
  )
  let wilds = make_wilds(x)
  assert_true(wilds.contains("a"))
}
