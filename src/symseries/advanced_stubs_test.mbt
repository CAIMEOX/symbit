///|
test "symseries gruntz parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.mul([
    @symcore.function("sin", [x]),
    @symcore.pow(x, @symcore.int(-1)),
  ])
  let ours = try! gruntz(expr, x, @symcore.int(0))
  let sympy = try! @sympy_series.gruntz_str(expr, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries residue parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.pow(x, @symcore.int(-1))
  let ours = try! residue(expr, x, @symcore.int(0))
  let sympy = try! @sympy_series.residue_str(expr, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries acceleration parity" {
  let k = @symcore.symbol("k")
  let denom = @symcore.add([k, @symcore.int(1)])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let ours_r = try! richardson(expr, k, 1, 2)
  let sympy_r = try! @sympy_series.richardson_str(expr, "k", 1, 2)
  assert_eq(normalize_series_expr(ours_r), normalize_series_str(sympy_r))
  let ours_s = try! shanks(expr, k, 1, m=2)
  let sympy_s = try! @sympy_series.shanks_str(expr, "k", 1, m=2)
  assert_eq(normalize_series_expr(ours_s), normalize_series_str(sympy_s))
}
