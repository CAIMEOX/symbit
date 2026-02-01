///|
test "sympy oracle: sympy_call_string expand" {
  let res = sympy_call_string("sympy.expand", [OracleArg::Str("(x + 1)**2")])
  inspect(res, content="x**2 + 2*x + 1")
}

///|
test "sympy oracle: resultant_str" {
  let res = resultant("x**2 + 1", "x - 1", x="x")
  inspect(res, content="2")
}

///|
test "sympy oracle: gf2 factor_list_str" {
  let res = factor_list("x**6 + x**3 + 1", modulus=2)
  inspect(res, content="(1, [(x**6 + x**3 + 1, 1)])")
}

///|
test "sympy oracle: groebner_str" {
  let res = groebner(["x*y - 1", "x - y"], order="lex")
  inspect(res, content="x - y | y**2 - 1")
}

///|
test "sympy oracle: expr_equal" {
  let ok = expr_equal("x**2 - 1", "(x - 1)*(x + 1)")
  assert_true(ok)
}
