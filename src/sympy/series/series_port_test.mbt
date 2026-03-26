///|
fn normalize_series_expr(expr : @symcore.Expr) -> String raise {
  let s = @symprint.to_string(expr)
  sympy_normalize_str(s)
}

///|
fn normalize_series_str(s : String) -> String raise {
  sympy_normalize_str(s)
}

///|
test "symseries polynomial series parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([@symcore.int(1), x, @symcore.pow(x, @symcore.int(2))])
  let ours = series(expr, x~, n=4)
  let sympy = series_str(expr, "x", @symcore.int(0), 4)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries rational series parity" {
  let x = @symcore.Expr::Symbol("x")
  let denom = @symcore.add([
    @symcore.int(1),
    @symcore.mul([@symcore.int(-1), x]),
  ])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let ours = series(expr, x~, n=5)
  let sympy = series_str(expr, "x", @symcore.int(0), 5)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries constant series parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.int(2)
  let ours = series(expr, x~, n=3)
  let sympy = series_str(expr, "x", @symcore.int(0), 3)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries series nonzero dir parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function("tan", [x])
  let ours = series(expr, x~, x0=@symcore.int(2), n=4, dir="-")
  let sympy = series_str(expr, "x", @symcore.int(2), 4, dir="-")
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries series multivar parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.function("exp", [@symcore.add([x, y])])
  let ours = series(expr, x~, x0=@symcore.int(0), n=3)
  let sympy = series_str(expr, "x", @symcore.int(0), 3)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries hyperbolic series parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function("tanh", [@symcore.add([x, @symcore.int(1)])])
  let ours = series(expr, x~, x0=@symcore.int(0), n=5)
  let sympy = series_str(expr, "x", @symcore.int(0), 5)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries fractional power nonzero parity" {
  let x = @symcore.Expr::Symbol("x")
  let half = @symcore.rational_from_ints(1, 2)
  let expr = @symcore.pow(x, half)
  let ours = series(expr, x~, x0=@symcore.int(1), n=4)
  let sympy = series_str(expr, "x", @symcore.int(1), 4)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries atan series parity" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function("atan", [x])
  let ours = series(expr, x~, x0=@symcore.int(0), n=7)
  let sympy = series_str(expr, "x", @symcore.int(0), 7)
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}
