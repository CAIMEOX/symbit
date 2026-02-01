///|
test "sympy oracle: sympy_call_str expand" {
  let res = sympy_call_str("sympy.expand", [OracleArg::Str("(x + 1)**2")])
  inspect(res, content="x**2 + 2*x + 1")
}

///|
test "sympy oracle: resultant_str" {
  let res = sympy_resultant_str("x**2 + 1", "x - 1", "x")
  inspect(res, content="2")
}

///|
test "sympy oracle: gf2 factor_list_str" {
  let res = sympy_factor_list_str("x**6 + x**3 + 1", modulus=2)
  guard res.contains("x") else { fail("expected factor_list_str output") }
}

///|
test "sympy oracle: groebner_str" {
  let res = sympy_groebner_str(["x*y - 1", "x - y"], order="lex")
  guard res.contains("x") else { fail("expected groebner_str output") }
}

///|
test "sympy oracle: expr_equal" {
  let ok = sympy_expr_equal("x**2 - 1", "(x - 1)*(x + 1)")
  inspect(ok, content="true")
}
