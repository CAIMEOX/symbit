///|
fn fd_br(num : Int, den : Int) -> BigRational {
  try! BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
}

///|
fn fd_br_int(n : Int) -> BigRational {
  BigRational::from_int(n)
}

///|
fn fd_expr_int(n : Int) -> Expr {
  @symcore.int(n)
}

///|
fn fd_weights_level_repr(level : Array[BigRational]) -> String {
  let parts = level.map(v => v.to_string()).join(", ")
  "[\{parts}]"
}

///|
fn fd_weights_repr(weights : Array[Array[Array[BigRational]]]) -> String {
  let parts : Array[String] = Array::new()
  for level in weights {
    let inner : Array[String] = Array::new()
    for row in level {
      inner.push(fd_weights_level_repr(row))
    }
    let joined = inner.join(", ")
    parts.push("[\{joined}]")
  }
  let outer = parts.join(", ")
  "[\{outer}]"
}

///|
fn fd_strip_spaces(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
fn fd_assert_expr_equal(ours : Expr, oracle_str : String) -> Unit raise {
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
test "finite_diff_weights: small grid" {
  let x_list = [fd_br(-1, 2), fd_br(1, 2), fd_br(3, 2), fd_br(5, 2)]
  let weights = try! finite_diff_weights(1, x_list, x0=fd_br_int(0))
  let ours = fd_strip_spaces(fd_weights_repr(weights))
  let oracle = fd_strip_spaces(
    try! @sympy_calculus.finite_diff_weights_str(1, x_list, x0=fd_br_int(0)),
  )
  guard ours == oracle else {
    println("weights mismatch: ours=\{ours} oracle=\{oracle}")
    fail("weights mismatch")
  }
}

///|
test "apply_finite_diff: quadratic" {
  let x_list = [fd_br_int(-1), fd_br_int(0), fd_br_int(1)]
  let y_list = [fd_expr_int(1), fd_expr_int(0), fd_expr_int(1)]
  let ours = try! apply_finite_diff(2, x_list, y_list, x0=fd_br_int(0))
  let oracle = try! @sympy_calculus.apply_finite_diff_str(
    2,
    x_list,
    y_list,
    x0=fd_br_int(0),
  )
  try! fd_assert_expr_equal(ours, oracle)
}
