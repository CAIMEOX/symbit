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
test "symseries gruntz growth parity" {
  let x = @symcore.symbol("x")

  let exp_pos = @symcore.function("exp", [x])
  let ours_exp_pos = try! gruntz(exp_pos, x, @symcore.symbol("oo"))
  let sympy_exp_pos = try! @sympy_series.gruntz_str(
    exp_pos,
    "x",
    @symcore.symbol("oo"),
  )
  assert_eq(
    normalize_series_expr(ours_exp_pos),
    normalize_series_str(sympy_exp_pos),
  )

  let exp_neg = @symcore.function("exp", [@symcore.mul([@symcore.int(-1), x])])
  let ours_exp_neg = try! gruntz(exp_neg, x, @symcore.symbol("oo"))
  let sympy_exp_neg = try! @sympy_series.gruntz_str(
    exp_neg,
    "x",
    @symcore.symbol("oo"),
  )
  assert_eq(
    normalize_series_expr(ours_exp_neg),
    normalize_series_str(sympy_exp_neg),
  )

  let pole = @symcore.pow(x, @symcore.int(-1))
  let ours_pole = try! gruntz(pole, x, @symcore.int(0), dir="-")
  let sympy_pole = try! @sympy_series.gruntz_str(
    pole,
    "x",
    @symcore.int(0),
    dir="-",
  )
  assert_eq(normalize_series_expr(ours_pole), normalize_series_str(sympy_pole))
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
test "symseries residue parity higher-order poles" {
  let x = @symcore.symbol("x")
  let expr1 = @symcore.pow(x, @symcore.int(-2))
  let ours1 = try! residue(expr1, x, @symcore.int(0))
  let sympy1 = try! @sympy_series.residue_str(expr1, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours1), normalize_series_str(sympy1))

  let expr2 = @symcore.mul([
    @symcore.add([x, @symcore.int(1)]),
    @symcore.pow(x, @symcore.int(-2)),
  ])
  let ours2 = try! residue(expr2, x, @symcore.int(0))
  let sympy2 = try! @sympy_series.residue_str(expr2, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours2), normalize_series_str(sympy2))
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
