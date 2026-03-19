///|
fn expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn assert_expr_equal(ours : Expr, oracle_str : String) -> Unit raise {
  let ours_norm : Result[String, Error] = try? @sympy_calculus.sympy_normalize(
    @symprint.to_string(ours),
  )
  let oracle_norm : Result[String, Error] = try? @sympy_calculus.sympy_normalize(
    oracle_str,
  )
  match (ours_norm, oracle_norm) {
    (Ok(a), Ok(b)) => {
      guard a == b else {
        println("expr mismatch: ours=\{a} oracle=\{b}")
        fail("expr mismatch")
      }
    }
    (Err(e), _) => fail("normalize ours failed: \{e}")
    (_, Err(e)) => fail("normalize oracle failed: \{e}")
  }
}

///|
fn assert_expr_equal_str(ours : Expr, oracle : String) -> Unit raise {
  let ours_str = @symprint.to_string(ours)
  guard ours_str == oracle else {
    println("str mismatch: ours=\{ours_str} oracle=\{oracle}")
    fail("str mismatch")
  }
}

///|
test "accum_bounds: construct/delta/mid" {
  let b = accum_bounds(expr_int(1), expr_int(2))
  assert_expr_equal(b, "AccumBounds(1, 2)")
  let delta = match accum_delta(b) {
    Some(v) => v
    None => fail("delta none")
  }
  let delta_oracle = @sympy_calculus.accum_delta(expr_int(1), expr_int(2))
  assert_expr_equal(delta, delta_oracle)
  let mid = match accum_mid(b) {
    Some(v) => v
    None => fail("mid none")
  }
  let mid_oracle = @sympy_calculus.accum_mid(expr_int(1), expr_int(2))
  assert_expr_equal(mid, mid_oracle)
  let collapsed = accum_bounds(expr_int(1), expr_int(1))
  assert_expr_equal_str(collapsed, "1")
}

///|
test "accum_bounds: add/sub/neg" {
  let a = accum_bounds(expr_int(1), expr_int(2))
  let b = accum_bounds(expr_int(2), expr_int(3))
  let add = accum_add(a, b)
  let add_oracle = @sympy_calculus.accum_add(
    expr_int(1),
    expr_int(2),
    expr_int(2),
    expr_int(3),
  )
  assert_expr_equal(add, add_oracle)
  let sub = accum_sub(b, a)
  let sub_oracle = @sympy_calculus.accum_sub(
    expr_int(2),
    expr_int(3),
    expr_int(1),
    expr_int(2),
  )
  assert_expr_equal(sub, sub_oracle)
  let neg = accum_neg(a)
  assert_expr_equal(neg, "AccumBounds(-2, -1)")
}

///|
test "accum_bounds: mul/div/pow/abs" {
  let a = accum_bounds(expr_int(1), expr_int(2))
  let b = accum_bounds(expr_int(2), expr_int(3))
  let mul = accum_mul(a, b)
  let mul_oracle = @sympy_calculus.accum_mul(
    expr_int(1),
    expr_int(2),
    expr_int(2),
    expr_int(3),
  )
  assert_expr_equal(mul, mul_oracle)
  let div = accum_div(b, a)
  let div_oracle = @sympy_calculus.accum_div(
    expr_int(2),
    expr_int(3),
    expr_int(1),
    expr_int(2),
  )
  assert_expr_equal(div, div_oracle)
  let pow = accum_pow(a, expr_int(2))
  let pow_oracle = @sympy_calculus.accum_pow(
    expr_int(1),
    expr_int(2),
    expr_int(2),
  )
  assert_expr_equal(pow, pow_oracle)
  let abs = accum_abs(accum_bounds(expr_int(-2), expr_int(1)))
  let abs_oracle_res : Result[String, Error] = try? @sympy_calculus.accum_abs(
    expr_int(-2),
    expr_int(1),
  )
  let abs_oracle = match abs_oracle_res {
    Ok(v) => v
    Err(e) => fail("accum_abs oracle error: \{e}")
  }
  assert_expr_equal(abs, abs_oracle)
}
