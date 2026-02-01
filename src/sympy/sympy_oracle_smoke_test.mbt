///|
test "sympy oracle: sympy_call_string expand" {
  let res = sympy_call_string("sympy.expand", [OracleArg::Str("(x + 1)**2")])
  inspect(res, content="x**2 + 2*x + 1")
}

///|
test "sympy oracle: resultant_str" {
  let x = @symcore.symbol("x")
  let p = @symcore.add([@symcore.pow(x, @symcore.int(2)), @symcore.int(1)])
  let q = @symcore.add([x, @symcore.int(-1)])
  let res = resultant(p, q, x="x")
  inspect(res, content="2")
}

///|
test "sympy oracle: gf2 factor_list_str" {
  let x = @symcore.symbol("x")
  let expr = @symcore.add([
    @symcore.pow(x, @symcore.int(6)),
    @symcore.pow(x, @symcore.int(3)),
    @symcore.int(1),
  ])
  let res = factor_list(expr, modulus=2)
  inspect(res, content="(1, [(x**6 + x**3 + 1, 1)])")
}

///|
test "sympy oracle: groebner_str" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f1 = @symcore.add([
    @symcore.mul([x, y]),
    @symcore.int(-1),
  ])
  let f2 = @symcore.add([x, @symcore.mul([@symcore.int(-1), y])])
  let res = groebner([f1, f2], order="lex")
  inspect(res, content="x - y | y**2 - 1")
}

///|
test "sympy oracle: expr_equal" {
  let ok = expr_equal("x**2 - 1", "(x - 1)*(x + 1)")
  assert_true(ok)
}
