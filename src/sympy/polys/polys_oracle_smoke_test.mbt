///|
test "sympy oracle: sympy_call_string expand" {
  let res = sympy_call_string("sympy.expand", [Str("(x + 1)**2")])
  inspect(res, content="x**2 + 2*x + 1")
}

///|
test "sympy oracle: sympy_call_string serializes every OracleArg shape" {
  assert_eq(sympy_call_string("sympy.Tuple", [Null]), "(None,)")
  assert_eq(sympy_call_string("sympy.sympify", [Bool(true)]), "True")
  assert_eq(sympy_call_string("sympy.sympify", [StrList(["a", "b"])]), "[a, b]")
  assert_eq(sympy_call_string("sympy.sympify", [IntList([3, 4])]), "[3, 4]")
  assert_eq(
    sympy_call_string("sympy.sympify", [
      List([Null, Str("z"), Int(5), Bool(false)]),
    ]),
    "[None, z, 5, False]",
  )
  assert_eq(
    sympy_call_string("sympy.sympify", [
      Dict({ "outer": Dict({ "value": Int(2) }), "flag": Bool(false) }),
    ]),
    "{flag: False, outer: {value: 2}}",
  )
  assert_eq(
    sympy_call_string("sympy.sympify", [Str("a + b")], kwargs={
      "locals": Dict({ "a": Int(2), "b": Int(3) }),
    }),
    "5",
  )
}

///|
test "sympy oracle: sympy_call_string keeps implicit sympy path contract" {
  assert_eq(sympy_call_string("expand", [Str("(x + 1)**2")]), "x**2 + 2*x + 1")
  assert_eq(
    sympy_call_string("polys.polytools.cancel", [Str("(x**2 - 1)/(x - 1)")]),
    "x + 1",
  )
  // The legacy helper prints Poly through as_expr(), not Poly.__str__().
  assert_eq(sympy_call_string("sympy.Poly", [Str("x**2 + 1")]), "x**2 + 1")
}

///|
test "sympy oracle: resultant_str" {
  let x = @symcore.Expr::Symbol("x")
  let p = (x ^ @symcore.int(2)) + @symcore.int(1)
  let q = x - @symcore.int(1)
  let res = resultant(p, q, x="x")
  inspect(res, content="2")
}

///|
test "sympy oracle: gf2 factor_list_str" {
  let x = @symcore.Expr::Symbol("x")
  let expr = (x ^ @symcore.int(6)) + (x ^ @symcore.int(3)) + @symcore.int(1)
  let res = factor_list(expr, modulus=2)
  inspect(res, content="(1, [(x**6 + x**3 + 1, 1)])")
}

///|
test "sympy oracle: groebner_str" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let f1 = x * y - @symcore.int(1)
  let f2 = x - @symcore.int(1) * y
  let res = groebner([f1, f2], order="lex")
  inspect(res, content="x - y | y**2 - 1")
}

///|
test "sympy oracle: expr_equal" {
  let ok = expr_equal("x**2 - 1", "(x - 1)*(x + 1)")
  assert_true(ok)
}
