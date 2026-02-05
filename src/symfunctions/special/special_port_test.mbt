///|
fn assert_oracle(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(e) => raise e
  }
}

///|
test "special gamma/erf basics" {
  let g5 = gamma(@symcore.int(5))
  let e0 = erf(@symcore.int(0))
  assert_eq(@symprint.to_string(g5), "24")
  assert_eq(@symprint.to_string(e0), "0")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(g5), "gamma(5)"),
  )
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(e0), "erf(0)"),
  )
}

///|
test "special zeta wrapper" {
  let x = @symcore.symbol("x")
  let z = zeta(x)
  assert_eq(@symprint.to_string(z), "zeta(x)")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(z), "zeta(x)"),
  )
}
