///|
fn euler_expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn euler_expr_rat(num : Int, den : Int) -> Expr raise {
  @symcore.rational_from_ints(num, den)
}

///|
fn euler_expr_symbol(name : String) -> Expr {
  Symbol(name)
}

///|
fn euler_expr_func(name : String, args : Array[Expr]) -> Expr {
  @symcore.function(name, args)
}

///|
fn euler_assert_expr_equal(ours : Expr, oracle_str : String) -> Unit raise {
  let ours_norm = sympy_normalize(@symprint.pretty_string(ours))
  let oracle_norm = sympy_normalize(oracle_str)
  guard ours_norm == oracle_norm else {
    println("expr mismatch: ours=\{ours_norm} oracle=\{oracle_norm}")
    fail("expr mismatch")
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
  let oracle = euler_equations_str(lagrangian, [xt], [t])
  assert_eq(eqs.length(), oracle.length())
  for i in 0..<eqs.length() {
    euler_assert_expr_equal(eqs[i], oracle[i])
  }
}
