///|
fn normalize_series_expr(expr : @symcore.Expr) -> String {
  let s = @symprint.to_string(expr)
  try! @sympy_series.sympy_normalize_str(s)
}

///|
fn normalize_series_str(s : String) -> String {
  try! @sympy_series.sympy_normalize_str(s)
}

///|
test "symseries polynomial series parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.add([@symcore.int(1), x, @symcore.pow(x, @symcore.int(2))])
  let ours = try! series(expr, x~, n=4)
  let sympy = try! @sympy_series.series_str(expr, "x", @symcore.int(0), 4)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries rational series parity" {
  let x = @symcore.symbol("x")
  let denom = @symcore.add([
    @symcore.int(1),
    @symcore.mul([@symcore.int(-1), x]),
  ])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let ours = try! series(expr, x~, n=5)
  let sympy = try! @sympy_series.series_str(expr, "x", @symcore.int(0), 5)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries constant series parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.int(2)
  let ours = try! series(expr, x~, n=3)
  let sympy = try! @sympy_series.series_str(expr, "x", @symcore.int(0), 3)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries series nonzero dir parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.function("tan", [x])
  let ours = try! series(expr, x~, x0=@symcore.int(2), n=4, dir="-")
  let sympy = try! @sympy_series.series_str(
    expr,
    "x",
    @symcore.int(2),
    4,
    dir="-",
  )
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries series multivar parity" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.function("exp", [@symcore.add([x, y])])
  let ours = try! series(expr, x~, x0=@symcore.int(0), n=3)
  let sympy = try! @sympy_series.series_str(expr, "x", @symcore.int(0), 3)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}
