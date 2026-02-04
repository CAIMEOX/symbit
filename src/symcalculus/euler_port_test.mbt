///|
fn euler_expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn euler_expr_rat(num : Int, den : Int) -> Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn euler_expr_symbol(name : String) -> Expr {
  @symcore.symbol(name)
}

///|
fn euler_expr_func(name : String, args : Array[Expr]) -> Expr {
  @symcore.function(name, args)
}

///|
fn euler_assert_expr_equal(ours : Expr, oracle_str : String) -> Unit raise {
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
test "euler_equations: harmonic oscillator" {
  let t = euler_expr_symbol("t")
  let xt = euler_expr_func("x", [t])
  let dxt = diff(xt, t)
  let half = euler_expr_rat(1, 2)
  let term1 = @symcore.mul([half, @symcore.pow(dxt, euler_expr_int(2))])
  let term2 = @symcore.mul([half, @symcore.pow(xt, euler_expr_int(2))])
  let lagrangian = term1 - term2
  let eqs = euler_equations(lagrangian, [xt], [t])
  let oracle = try! @sympy_calculus.euler_equations_str(lagrangian, [xt], [t])
  guard eqs.length() == oracle.length() else { fail("eq length mismatch") }
  for i in 0..<eqs.length() {
    try! euler_assert_expr_equal(eqs[i], oracle[i])
  }
}
