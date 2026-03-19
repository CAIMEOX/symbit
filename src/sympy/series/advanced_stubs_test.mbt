///|
test "symseries gruntz parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.mul([
    @symcore.function("sin", [x]),
    @symcore.pow(x, @symcore.int(-1)),
  ])
  let ours = gruntz(expr, x, @symcore.int(0))
  let sympy = gruntz_str(expr, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries gruntz growth parity" {
  let x = @symcore.symbol("x")

  let exp_pos = @symcore.function("exp", [x])
  let ours_exp_pos = gruntz(exp_pos, x, @symcore.symbol("oo"))
  let sympy_exp_pos = gruntz_str(
    exp_pos,
    "x",
    @symcore.symbol("oo"),
  )
  assert_eq(
    normalize_series_expr(ours_exp_pos),
    normalize_series_str(sympy_exp_pos),
  )

  let exp_neg = @symcore.function("exp", [@symcore.mul([@symcore.int(-1), x])])
  let ours_exp_neg = gruntz(exp_neg, x, @symcore.symbol("oo"))
  let sympy_exp_neg = gruntz_str(
    exp_neg,
    "x",
    @symcore.symbol("oo"),
  )
  assert_eq(
    normalize_series_expr(ours_exp_neg),
    normalize_series_str(sympy_exp_neg),
  )

  let pole = @symcore.pow(x, @symcore.int(-1))
  let ours_pole = gruntz(pole, x, @symcore.int(0), dir="-")
  let sympy_pole = gruntz_str(pole, "x", @symcore.int(0), dir="-")
  assert_eq(normalize_series_expr(ours_pole), normalize_series_str(sympy_pole))
}

///|
test "symseries residue parity" {
  let x = @symcore.symbol("x")
  let expr = @symcore.pow(x, @symcore.int(-1))
  let ours = residue(expr, x, @symcore.int(0))
  let sympy = residue_str(expr, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours), normalize_series_str(sympy))
}

///|
test "symseries residue parity higher-order poles" {
  let x = @symcore.symbol("x")
  let expr1 = @symcore.pow(x, @symcore.int(-2))
  let ours1 = residue(expr1, x, @symcore.int(0))
  let sympy1 = residue_str(expr1, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours1), normalize_series_str(sympy1))

  let expr2 = @symcore.mul([
    @symcore.add([x, @symcore.int(1)]),
    @symcore.pow(x, @symcore.int(-2)),
  ])
  let ours2 = residue(expr2, x, @symcore.int(0))
  let sympy2 = residue_str(expr2, "x", @symcore.int(0))
  assert_eq(normalize_series_expr(ours2), normalize_series_str(sympy2))
}

///|
test "symseries acceleration parity" {
  let k = @symcore.symbol("k")
  let denom = @symcore.add([k, @symcore.int(1)])
  let expr = @symcore.pow(denom, @symcore.int(-1))
  let ours_r = richardson(expr, k, 1, 2)
  let sympy_r = richardson_str(expr, "k", 1, 2)
  assert_eq(normalize_series_expr(ours_r), normalize_series_str(sympy_r))
  let ours_s = shanks(expr, k, 1, m=2)
  let sympy_s = shanks_str(expr, "k", 1, m=2)
  assert_eq(normalize_series_expr(ours_s), normalize_series_str(sympy_s))
}
