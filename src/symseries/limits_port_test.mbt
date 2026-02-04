///|
fn normalize_limit_expr(expr : @symcore.Expr) -> String {
  let s = @symprint.to_string(expr)
  try! @sympy_series.sympy_normalize_str(s)
}

///|
fn normalize_limit_str(s : String) -> String {
  try! @sympy_series.sympy_normalize_str(s)
}

///|
test "symseries limit finite point" {
  let x = @symcore.symbol("x")
  let expr = @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(1)])
  let ours = try! limit(expr, x, @symcore.int(0))
  let sympy = try! @sympy_series.limit_str(expr, "x", @symcore.int(0))
  assert_eq(normalize_limit_expr(ours), normalize_limit_str(sympy))
}

///|
test "symseries limit infinity rational" {
  let x = @symcore.symbol("x")
  let num = @symcore.add([
    @symcore.mul([@symcore.int(2), @symcore.pow(x, @symcore.int(2))]),
    @symcore.int(1),
  ])
  let den = @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(1)])
  let expr = @symcore.mul([num, @symcore.pow(den, @symcore.int(-1))])
  let ours = try! limit(expr, x, @symcore.symbol("oo"))
  let sympy = try! @sympy_series.limit_str(expr, "x", @symcore.symbol("oo"))
  assert_eq(normalize_limit_expr(ours), normalize_limit_str(sympy))
}

///|
test "symseries limit infinity zero" {
  let x = @symcore.symbol("x")
  let expr = @symcore.mul([@symcore.int(1), @symcore.pow(x, @symcore.int(-1))])
  let ours = try! limit(expr, x, @symcore.symbol("oo"))
  let sympy = try! @sympy_series.limit_str(expr, "x", @symcore.symbol("oo"))
  assert_eq(normalize_limit_expr(ours), normalize_limit_str(sympy))
}

///|
test "symseries Limit struct doit" {
  let x = @symcore.symbol("x")
  let expr = @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(1)])
  let lim = Limit::{ expr, variable: x, point: @symcore.int(0), dir: "+" }
  let ours = try! lim.doit()
  let sympy = try! @sympy_series.limit_str(expr, "x", @symcore.int(0))
  assert_eq(normalize_limit_expr(ours), normalize_limit_str(sympy))
}

///|
test "symseries limit direction parity" {
  let x = @symcore.symbol("x")
  let denom = @symcore.add([x, @symcore.int(-1)])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let ours = try! limit(expr, x, @symcore.int(1), dir="-")
  let sympy = try! @sympy_series.limit_str(expr, "x", @symcore.int(1), dir="-")
  assert_eq(normalize_limit_expr(ours), normalize_limit_str(sympy))
}
