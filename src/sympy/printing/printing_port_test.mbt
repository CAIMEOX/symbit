///|
test "printing text and latex front doors match sympy" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.pow(x, @symcore.int(2)) + @symcore.int(1)
  assert_eq(@symprint.sstr(expr), printing_call("sstr", expr))
  assert_eq(@symprint.sstrrepr(expr), printing_call("sstrrepr", expr))
  assert_eq(@symprint.srepr(expr), printing_call("srepr", expr))
  assert_eq(@symprint.latex(expr), printing_call("latex", expr))
  assert_eq(@symprint.print_latex(expr), printing_call("latex", expr))
}

///|
test "printing code front doors match stable sympy scalar emitters" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.function("sin", [x]) + @symcore.int(1)
  assert_eq(@symprint.pycode(expr), printing_call("pycode", expr))
  assert_eq(@symprint.rcode(expr), printing_call("rcode", expr))
  assert_eq(
    @symprint.mathematica_code(expr),
    printing_call("mathematica_code", expr),
  )
}
