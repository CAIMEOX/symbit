///|
test "symseries limit_seq parity" {
  let n = @symcore.symbol("n")
  let num = @symcore.add([
    @symcore.mul([@symcore.int(5), @symcore.pow(n, @symcore.int(3))]),
    @symcore.mul([@symcore.int(3), @symcore.pow(n, @symcore.int(2))]),
    @symcore.int(4),
  ])
  let den = @symcore.add([
    @symcore.mul([@symcore.int(3), @symcore.pow(n, @symcore.int(3))]),
    @symcore.mul([@symcore.int(4), n]),
    @symcore.int(-5),
  ])
  let expr = @symcore.mul([num, @symcore.pow(den, @symcore.int(-1))])
  let ours = try! limit_seq(expr, n~)
  let sympy = try! @sympy_series.limit_seq_str(expr, "n")
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries difference_delta parity" {
  let n = @symcore.symbol("n")
  let expr = @symcore.pow(n, @symcore.int(2))
  let ours = try! difference_delta(expr, n~, step=2)
  let sympy = try! @sympy_series.difference_delta_str(expr, "n", step=2)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}
