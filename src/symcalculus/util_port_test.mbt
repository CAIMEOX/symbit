///|
fn util_expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn util_expr_symbol(name : String) -> Expr {
  @symcore.symbol(name)
}

///|
fn util_expr_func(name : String, args : Array[Expr]) -> Expr {
  @symcore.function(name, args)
}

///|
fn util_assert_period(ours : Expr?, oracle_str : String) -> Unit raise {
  let ours_str = match ours {
    Some(v) => @symprint.to_string(v)
    None => "None"
  }
  if ours_str == "None" || oracle_str == "None" {
    guard ours_str == oracle_str else {
      println("periodicity mismatch: ours=\{ours_str} oracle=\{oracle_str}")
      fail("periodicity mismatch")
    }
  } else {
    let oracle_norm : Result[String, Error] = try? @sympy_calculus.sympy_normalize(oracle_str)
    let ours_norm : Result[String, Error] = try? @sympy_calculus.sympy_normalize(ours_str)
    match (ours_norm, oracle_norm) {
      (Ok(a), Ok(b)) => {
        guard a == b else {
          println("periodicity mismatch: ours=\{a} oracle=\{b}")
          fail("periodicity mismatch")
        }
      }
      (Err(e), _) => fail("normalize ours failed: \{e}")
      (_, Err(e)) => fail("normalize oracle failed: \{e}")
    }
  }
}

///|
fn util_oracle_periodicity(expr : Expr, sym : Expr, label : String) -> String raise {
  try @sympy_calculus.periodicity_str(expr, sym) catch {
    err => fail("oracle periodicity \{label} error: \{err}")
  } noraise {
    v => v
  }
}

///|
test "periodicity: trig linear" {
  let x = util_expr_symbol("x")
  let expr1 = util_expr_func("sin", [@symcore.mul([util_expr_int(2), x])])
  let expr2 = util_expr_func("cos", [x])
  let expr3 = util_expr_func("tan", [@symcore.mul([util_expr_int(3), x])])
  let p1 = periodicity(expr1, x)
  let p2 = periodicity(expr2, x)
  let p3 = periodicity(expr3, x)
  let o1 = try! util_oracle_periodicity(expr1, x, "expr1")
  let o2 = try! util_oracle_periodicity(expr2, x, "expr2")
  let o3 = try! util_oracle_periodicity(expr3, x, "expr3")
  try! util_assert_period(p1, o1)
  try! util_assert_period(p2, o2)
  try! util_assert_period(p3, o3)
}

///|
test "periodicity: none" {
  let x = util_expr_symbol("x")
  let expr = util_expr_func("exp", [x])
  let p = periodicity(expr, x)
  let o = try! util_oracle_periodicity(expr, x, "exp")
  try! util_assert_period(p, o)
}
