///|
test "polys ring-series worker uses sibling constant-term semantics" {
  assert_eq(
    remove_spaces(sympy_normalize(rs_atan_ring_series([1, 1], 4))),
    "x**3/12-x**2/4+x/2+pi/4",
  )
}

///|
test "polys ring-series worker binds literal series symbols as data" {
  let symbol = @symcore.Expr::Symbol("q'quoted")
  let expression = @symcore.function("sin", [symbol])
  assert_eq(
    rs_series_expr(expression, "q'quoted", 4),
    "-1/6*q'quoted**3 + q'quoted",
  )
}

///|
test "polys ring-series worker recovers after a strict algorithm error" {
  let rejected = try {
    ignore(rs_log_ring_series([0, 1], 4))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(rs_diff_ring_series([1, 2, 3]), "6*x + 2")
}
