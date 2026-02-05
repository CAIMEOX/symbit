///|
fn assert_oracle(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(e) => raise e
  }
}

///|
test "combinatorial factorials" {
  let f5 = factorial(@symcore.int(5))
  let f2 = factorial2(@symcore.int(7))
  let sf5 = subfactorial(@symcore.int(5))
  let b52 = binomial(@symcore.int(5), @symcore.int(2))
  let rf34 = rf(@symcore.int(3), @symcore.int(4))
  let ff63 = ff(@symcore.int(6), @symcore.int(3))
  assert_eq(@symprint.to_string(f5), "120")
  assert_eq(@symprint.to_string(f2), "105")
  assert_eq(@symprint.to_string(sf5), "44")
  assert_eq(@symprint.to_string(b52), "10")
  assert_eq(@symprint.to_string(rf34), "360")
  assert_eq(@symprint.to_string(ff63), "120")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(f5), "factorial(5)"),
  )
  assert_oracle(
    try? @sympy_functions.expr_str_eq(
      @symprint.to_string(b52),
      "binomial(5, 2)",
    ),
  )
}

///|
test "combinatorial numbers" {
  let fib10 = fibonacci(@symcore.int(10))
  let luc5 = lucas(@symcore.int(5))
  let tri6 = tribonacci(@symcore.int(6))
  let h3 = harmonic(@symcore.int(3))
  let b4 = bernoulli(@symcore.int(4))
  assert_eq(@symprint.to_string(fib10), "55")
  assert_eq(@symprint.to_string(luc5), "11")
  assert_eq(@symprint.to_string(tri6), "13")
  assert_eq(@symprint.to_string(h3), "11/6")
  assert_eq(@symprint.to_string(b4), "-1/30")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(
      @symprint.to_string(fib10),
      "fibonacci(10)",
    ),
  )
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(h3), "harmonic(3)"),
  )
}

///|
test "combinatorial number theory wrappers" {
  let tot = totient(@symcore.int(10))
  let pp = primepi(@symcore.int(10))
  let mu = mobius(@symcore.int(10))
  let sigma = divisor_sigma(@symcore.int(6))
  let leg = legendre_symbol(@symcore.int(3), @symcore.int(5))
  assert_eq(@symprint.to_string(tot), "4")
  assert_eq(@symprint.to_string(pp), "4")
  assert_eq(@symprint.to_string(mu), "1")
  assert_eq(@symprint.to_string(sigma), "12")
  assert_eq(@symprint.to_string(leg), "-1")
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(tot), "totient(10)"),
  )
  assert_oracle(
    try? @sympy_functions.expr_str_eq(@symprint.to_string(pp), "primepi(10)"),
  )
}
