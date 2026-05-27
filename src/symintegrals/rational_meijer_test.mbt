///|
test "symintegrals rationaltools public helpers cover simple rational descriptors" {
  let x = @symcore.Expr::Symbol("x")
  let t = @symcore.Expr::Symbol("t")
  guard ratint_ratpart(@symcore.int(1), x + @symcore.int(1), "x") is Some(parts) else {
    fail("expected rational/log split")
  }
  assert_true(@symcore.compare_expr(parts.0, @symcore.int(0)) == 0)
  let reciprocal = (x + @symcore.int(1)) ^ @symcore.int(-1)
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(parts.1 - reciprocal),
      @symcore.int(0),
    ) ==
    0,
  )

  let atan_value = log_to_atan(x, @symcore.int(1))
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(atan_value - @symcore.int(2) * @symelem.atan(x)),
      @symcore.int(0),
    ) ==
    0,
  )

  guard log_to_real(x + t, @symcore.int(-2) * t + @symcore.int(1), x, t)
    is Some(real_value) else {
    fail("expected real log conversion")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(
        real_value -
        @symcore.rational_from_ints(1, 2) *
        @symelem.log(x + @symcore.rational_from_ints(1, 2)),
      ),
      @symcore.int(0),
    ) ==
    0,
  )
}

///|
test "symintegrals meijer public helpers delegate to local special integrator" {
  let x = @symcore.Expr::Symbol("x")
  guard meijerint_indefinite(@symelem.sin(x) * (x ^ @symcore.int(-1)), x)
    is Some(si_value) else {
    fail("expected sine integral result")
  }
  assert_true(
    @symcore.compare_expr(
      @symsimplify.simplify(si_value - @symspec.si(x)),
      @symcore.int(0),
    ) ==
    0,
  )
}
