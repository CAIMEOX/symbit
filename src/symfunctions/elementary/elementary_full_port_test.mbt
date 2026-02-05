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
  let oracle : Result[Bool, Error] = try? @sympy_functions.expr_str_eq(
    ours, expected,
  )
  match oracle {
    Ok(true) => ()
    Ok(false) => {
      println("oracle mismatch [\{label}]: ours=\{ours} expected=\{expected}")
      fail("oracle mismatch")
    }
    Err(e) => raise e
  }
}

///|
test "elementary full parity (core)" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  check_expr("sqrt", sqrt(x), "sqrt(x)")
  check_expr("root", root(x, y), "root(x, y)")
  check_expr("real_root", real_root(x, y), "real_root(x, y)")
  check_expr("cbrt", cbrt(x), "cbrt(x)")
  check_expr("min", min([x, y]), "Min(x, y)")
  check_expr("max", max([x, y]), "Max(x, y)")
  check_expr("id", id(x), "x")
  check_expr("rem", rem(x, y), "Rem(x, y)")
  check_expr("re", re(x), "re(x)")
  check_expr("im", im(x), "im(x)")
  check_expr("sign", sign(x), "sign(x)")
  check_expr("abs", abs(x), "Abs(x)")
  check_expr("conjugate", conjugate(x), "conjugate(x)")
  check_expr("arg", arg(x), "arg(x)")
  check_expr("polar_lift", polar_lift(x), "polar_lift(x)")
  check_expr(
    "periodic_argument",
    periodic_argument(x, y),
    "periodic_argument(x, y)",
  )
  check_expr(
    "unbranched_argument",
    unbranched_argument(x),
    "unbranched_argument(x)",
  )
  check_expr(
    "principal_branch",
    principal_branch(x, y),
    "principal_branch(x, y)",
  )
  check_expr("transpose", transpose(x), "transpose(x)")
  check_expr("adjoint", adjoint(x), "adjoint(x)")
  let pol = polarify(x)
  assert_eq(@symprint.to_string(pol), "polarify(x)")
  check_expr("unpolarify", unpolarify(x), "unpolarify(x)")
  check_expr("sin", sin(x), "sin(x)")
  check_expr("cos", cos(x), "cos(x)")
  check_expr("tan", tan(x), "tan(x)")
  check_expr("sec", sec(x), "sec(x)")
  check_expr("csc", csc(x), "csc(x)")
  check_expr("cot", cot(x), "cot(x)")
  check_expr("sinc", sinc(x), "sinc(x)")
  check_expr("asin", asin(x), "asin(x)")
  check_expr("acos", acos(x), "acos(x)")
  check_expr("atan", atan(x), "atan(x)")
  check_expr("asec", asec(x), "asec(x)")
  check_expr("acsc", acsc(x), "acsc(x)")
  check_expr("acot", acot(x), "acot(x)")
  check_expr("atan2", atan2(y, x), "atan2(y, x)")
  check_expr("exp_polar", exp_polar(x), "exp_polar(x)")
  check_expr("exp", exp(x), "exp(x)")
  check_expr("log", log(x), "log(x)")
  check_expr("ln", ln(x), "log(x)")
  check_expr("lambert_w", lambert_w(x), "LambertW(x)")
  check_expr("sinh", sinh(x), "sinh(x)")
  check_expr("cosh", cosh(x), "cosh(x)")
  check_expr("tanh", tanh(x), "tanh(x)")
  check_expr("coth", coth(x), "coth(x)")
  check_expr("sech", sech(x), "sech(x)")
  check_expr("csch", csch(x), "csch(x)")
  check_expr("asinh", asinh(x), "asinh(x)")
  check_expr("acosh", acosh(x), "acosh(x)")
  check_expr("atanh", atanh(x), "atanh(x)")
  check_expr("acoth", acoth(x), "acoth(x)")
  check_expr("asech", asech(x), "asech(x)")
  check_expr("acsch", acsch(x), "acsch(x)")
  check_expr("floor", floor(x), "floor(x)")
  check_expr("ceiling", ceiling(x), "ceiling(x)")
  check_expr("frac", frac(x), "frac(x)")

  // Piecewise parity needs custom encoding; we only assert construction here.
  let pw = piecewise([{ expr: x, cond: @symlogic.bool_symbol("c") }])
  assert_eq(@symprint.to_string(pw), "Piecewise(x, c, NaN(), True)")
}
