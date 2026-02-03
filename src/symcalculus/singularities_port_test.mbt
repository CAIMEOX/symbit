///|
fn sing_expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn sing_expr_symbol(name : String) -> Expr {
  @symcore.symbol(name)
}

///|
fn sing_expr_equal(ours : Expr, oracle_str : String) -> Unit raise {
  let ours_norm : Result[String, Error] = try? @sympy_calculus.sympy_normalize(
    @symprint.to_string(ours),
  )
  let oracle_norm : Result[String, Error] = try? @sympy_calculus.sympy_normalize(oracle_str)
  match (ours_norm, oracle_norm) {
    (Ok(a), Ok(b)) => {
      guard a == b else {
        println("singularities mismatch: ours=\{a} oracle=\{b}")
        fail("singularities mismatch")
      }
    }
    (Err(e), _) => fail("normalize ours failed: \{e}")
    (_, Err(e)) => fail("normalize oracle failed: \{e}")
  }
}

///|
test "singularities: simple pole" {
  let x = sing_expr_symbol("x")
  let expr = @symcore.pow(@symcore.add([x, sing_expr_int(1)]), sing_expr_int(-1))
  let ours = singularities(expr, x)
  let oracle = try! @sympy_calculus.singularities_str(expr, x)
  try! sing_expr_equal(ours, oracle)
}

///|
test "singularities: log" {
  let x = sing_expr_symbol("x")
  let expr = @symcore.function("log", [x])
  let ours = singularities(expr, x)
  let oracle = try! @sympy_calculus.singularities_str(expr, x)
  try! sing_expr_equal(ours, oracle)
}

///|
test "singularities: none" {
  let x = sing_expr_symbol("x")
  let expr = @symcore.add([
    @symcore.pow(x, sing_expr_int(2)),
    sing_expr_int(1),
  ])
  let ours = singularities(expr, x)
  let oracle = try! @sympy_calculus.singularities_str(expr, x)
  try! sing_expr_equal(ours, oracle)
}
