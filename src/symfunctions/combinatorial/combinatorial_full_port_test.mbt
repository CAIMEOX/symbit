///|
fn assert_oracle_full(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(e) => raise e
  }
}

///|
fn check_expr(
  label : String,
  expr : @symcore.Expr,
  expected : String,
) -> Unit raise {
  let ours = @symprint.to_string(expr)
  guard ours == expected else {
    println("mismatch [\{label}]: ours=\{ours} expected=\{expected}")
    fail("expr mismatch")
  }
  assert_oracle_full(try? @sympy_functions.expr_str_eq(ours, expected))
}

///|
test "combinatorial full parity (wrappers)" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  check_expr("factorial", factorial(x), "factorial(x)")
  check_expr("factorial2", factorial2(x), "factorial2(x)")
  check_expr("subfactorial", subfactorial(x), "subfactorial(x)")
  check_expr("rf", rf(x, y), "rf(x, y)")
  check_expr("ff", ff(x, y), "ff(x, y)")
  check_expr("rising", rising_factorial(x, y), "RisingFactorial(x, y)")
  check_expr("falling", falling_factorial(x, y), "FallingFactorial(x, y)")
  check_expr("binomial", binomial(x, y), "binomial(x, y)")
  check_expr("carmichael", carmichael(x), "carmichael(x)")
  check_expr("fibonacci", fibonacci(x), "fibonacci(x)")
  check_expr("lucas", lucas(x), "lucas(x)")
  check_expr("tribonacci", tribonacci(x), "tribonacci(x)")
  check_expr("harmonic", harmonic(x), "harmonic(x)")
  check_expr("bernoulli", bernoulli(x), "bernoulli(x)")
  check_expr("bell", bell(x), "bell(x)")
  check_expr("euler", euler(x), "euler(x)")
  check_expr("catalan", catalan(x), "catalan(x)")
  check_expr("genocchi", genocchi(x), "genocchi(x)")
  check_expr("andre", andre(x), "andre(x)")
  check_expr("partition", partition(x), "partition(x)")
  check_expr("divisor_sigma", divisor_sigma(x), "divisor_sigma(x, 1)")
  check_expr("udivisor_sigma", udivisor_sigma(x), "udivisor_sigma(x, 1)")
  check_expr("legendre_symbol", legendre_symbol(x, y), "legendre_symbol(x, y)")
  check_expr("jacobi_symbol", jacobi_symbol(x, y), "jacobi_symbol(x, y)")
  check_expr(
    "kronecker_symbol",
    kronecker_symbol(x, y),
    "kronecker_symbol(x, y)",
  )
  check_expr("mobius", mobius(x), "mobius(x)")
  check_expr("primenu", primenu(x), "primenu(x)")
  check_expr("primeomega", primeomega(x), "primeomega(x)")
  check_expr("totient", totient(x), "totient(x)")
  check_expr("reduced_totient", reduced_totient(x), "reduced_totient(x)")
  check_expr("primepi", primepi(x), "primepi(x)")
  check_expr("motzkin", motzkin(@symcore.int(4)), "motzkin(4)")
}
