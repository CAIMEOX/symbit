///|
test "symstats characteristic_function expressions evaluate through complex evalf" {
  let rv = cauchy("X", params=[@symcore.int(1), @symcore.int(2)])
  let cf = characteristic_function(random_symbol(rv), @symcore.int(1), rvs=[rv])
  let numeric = @symcore.evalf(cf, prec=100)
  match numeric {
    @symcore.Expr::ComplexFloat(z) => {
      assert_true(z.is_finite())
      assert_true(z.real_part().format(dps=10).has_prefix("0.073121"))
      assert_true(z.imag_part().format(dps=10).has_prefix("0.113880"))
    }
    _ => fail("expected complex float characteristic function value")
  }
}
