///|
fn expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn assert_expr_equal(ours : Expr, oracle_str : String) -> Unit raise {
  let ours_norm = sympy_normalize(@symprint.pretty_string(ours))
  let oracle_norm = sympy_normalize(oracle_str)
  guard ours_norm == oracle_norm else {
    println("expr mismatch: ours=\{ours_norm} oracle=\{oracle_norm}")
    fail("expr mismatch")
  }
}

///|
fn assert_expr_equal_str(ours : Expr, oracle : String) -> Unit raise {
  let ours_str = @symprint.pretty_string(ours)
  guard ours_str == oracle else {
    println("str mismatch: ours=\{ours_str} oracle=\{oracle}")
    fail("str mismatch")
  }
}

///|
test "accum_bounds: construct/delta/mid" {
  let b = accum_bounds(expr_int(1), expr_int(2))
  assert_expr_equal(b, "AccumBounds(1, 2)")
  let delta = match calc_accum_delta(b) {
    Some(v) => v
    None => fail("delta none")
  }
  let delta_oracle = accum_delta(expr_int(1), expr_int(2))
  assert_expr_equal(delta, delta_oracle)
  let mid = match calc_accum_mid(b) {
    Some(v) => v
    None => fail("mid none")
  }
  let mid_oracle = accum_mid(expr_int(1), expr_int(2))
  assert_expr_equal(mid, mid_oracle)
  let collapsed = accum_bounds(expr_int(1), expr_int(1))
  assert_expr_equal_str(collapsed, "1")
}

///|
test "accum_bounds: add/sub/neg" {
  let a = accum_bounds(expr_int(1), expr_int(2))
  let b = accum_bounds(expr_int(2), expr_int(3))
  let add = calc_accum_add(a, b)
  let add_oracle = accum_add(expr_int(1), expr_int(2), expr_int(2), expr_int(3))
  assert_expr_equal(add, add_oracle)
  let sub = calc_accum_sub(b, a)
  let sub_oracle = accum_sub(expr_int(2), expr_int(3), expr_int(1), expr_int(2))
  assert_expr_equal(sub, sub_oracle)
  let neg = accum_neg(a)
  assert_expr_equal(neg, "AccumBounds(-2, -1)")
}

///|
test "accum_bounds: mul/div/pow/abs" {
  let a = accum_bounds(expr_int(1), expr_int(2))
  let b = accum_bounds(expr_int(2), expr_int(3))
  let mul = calc_accum_mul(a, b)
  let mul_oracle = accum_mul(expr_int(1), expr_int(2), expr_int(2), expr_int(3))
  assert_expr_equal(mul, mul_oracle)
  let div = calc_accum_div(b, a)
  let div_oracle = accum_div(expr_int(2), expr_int(3), expr_int(1), expr_int(2))
  assert_expr_equal(div, div_oracle)
  let pow = calc_accum_pow(a, expr_int(2))
  let pow_oracle = accum_pow(expr_int(1), expr_int(2), expr_int(2))
  assert_expr_equal(pow, pow_oracle)
  let abs = calc_accum_abs(accum_bounds(expr_int(-2), expr_int(1)))
  let abs_oracle = accum_abs(expr_int(-2), expr_int(1))
  assert_expr_equal(abs, abs_oracle)
}
