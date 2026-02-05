///|
fn assert_oracle(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(e) => raise e
  }
}

///|
test "elementary exp/log simplifications" {
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let exp0 = exp(zero)
  let log1 = log(one)
  assert_eq(@symprint.to_string(exp0), "1")
  assert_eq(@symprint.to_string(log1), "0")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(exp0), "1"),
  )
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(log1), "0"),
  )
}

///|
test "elementary trig simplifications" {
  let zero = @symcore.int(0)
  let s0 = sin(zero)
  let c0 = cos(zero)
  let t0 = tan(zero)
  assert_eq(@symprint.to_string(s0), "0")
  assert_eq(@symprint.to_string(c0), "1")
  assert_eq(@symprint.to_string(t0), "0")
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(s0), "0"))
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(c0), "1"))
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(t0), "0"))
}

///|
test "elementary sqrt/abs/sign" {
  let minus_two = @symcore.int(-2)
  let abs2 = abs(minus_two)
  let sgn = sign(minus_two)
  let s0 = sqrt(@symcore.int(0))
  let s1 = sqrt(@symcore.int(1))
  assert_eq(@symprint.to_string(abs2), "2")
  assert_eq(@symprint.to_string(sgn), "-1")
  assert_eq(@symprint.to_string(s0), "0")
  assert_eq(@symprint.to_string(s1), "1")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(abs2), "2"),
  )
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(sgn), "-1"),
  )
}

///|
test "elementary floor/ceiling/frac" {
  let three = @symcore.int(3)
  let f = floor(three)
  let c = ceiling(three)
  let r = frac(three)
  assert_eq(@symprint.to_string(f), "3")
  assert_eq(@symprint.to_string(c), "3")
  assert_eq(@symprint.to_string(r), "0")
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(f), "3"))
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(c), "3"))
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(r), "0"))
}

///|
test "elementary Min/Max numeric" {
  let m = min([@symcore.int(3), @symcore.int(-1), @symcore.int(2)])
  let n = max([@symcore.int(3), @symcore.int(-1), @symcore.int(2)])
  assert_eq(@symprint.to_string(m), "-1")
  assert_eq(@symprint.to_string(n), "3")
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(m), "-1"))
  assert_oracle(try? @sympy_functions.expr_str_eq(@symprint.to_string(n), "3"))
}

///|
test "piecewise basic simplification" {
  let x = @symcore.symbol("x")
  let cases : Array[PiecewiseCase] = [
    { expr: @symcore.int(1), cond: @symlogic.bool_true() },
    { expr: x, cond: @symlogic.bool_symbol("c") },
  ]
  let pw = piecewise(cases)
  assert_eq(@symprint.to_string(pw), "1")
}
