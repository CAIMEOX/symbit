///|
test "convert: to_expr roundtrip over ZZ" {
  let x = @symcore.Expr::Symbol("x")
  let expr = (x ^ @symcore.int(3)) + @symcore.int(2) * x + @symcore.int(1)
  let poly = PolyBuilder::new(["x"], ZZ).from_expr(expr)
  let ours = poly.to_string()
  assert_true(expr_equal(ours, @symprint.pretty_string(expr)))
}

///|
test "convert: to_expr roundtrip over QQ with ordering" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.rational_from_ints(1, 2) * (x ^ @symcore.int(2)) +
    @symcore.rational_from_ints(3, 4) * y +
    @symcore.int(1)
  let poly = PolyBuilder::new(["x", "y"], QQ).order(Lex).from_expr(expr)
  let ours = poly.to_string()
  assert_true(expr_equal(ours, @symprint.pretty_string(expr)))
}

///|
test "convert: to_string matches SymPy poly_expr over GF" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.rational_from_ints(3, 2) * x +
    @symcore.rational_from_ints(1, 3)
  let poly = PolyBuilder::new(["x"], GF(5)).from_expr(expr)
  let ours = sympy_normalize(poly.to_string()).trim().to_owned()
  let c1 = mod_rational(3, 2, 5)
  let c0 = mod_rational(1, 3, 5)
  let expected = "\{c1}*x + \{c0}"
  let oracle = sympy_normalize(expected).trim().to_owned()
  assert_eq(ours, oracle)
}

///|
test "convert: explicit order and leading helpers cover option branches" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let poly = PolyBuilder::new(["x", "y"], QQ)
    .order(Grlex)
    .from_expr((x ^ @symcore.int(2)) + y + @symcore.int(1))

  let as_lex = sympy_normalize(poly.to_string(order=Lex))
  let as_default = sympy_normalize(poly.to_string())
  assert_eq(as_lex, as_default)

  let lc = poly.lc(order=Lex)
  assert_eq(Show::to_string(lc), "1")
  assert_true(poly.lm(order=Lex) is Some(_))
  assert_true(poly.lt(order=Lex) is Some(_))

  let z = Poly::zero(["x"], QQ)
  assert_eq(Show::to_string(z.lc()), "0")
  assert_true(z.lm() is None)
  assert_true(z.lt() is None)

  // Cover `impl Show for Poly`.
  let shown = "\{poly}"
  assert_true(shown.length() > 0)
}

///|
test "convert: parse_expr failure branches are typed" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")

  let bad_gen = expect_poly_error(fn() raise PolyError {
    Poly::from_expr(y, ["x"], QQ)
  })
  assert_true(bad_gen is BadGenerator(_))

  let bad_pow_kind = expect_poly_error(fn() raise PolyError {
    Poly::from_expr(x ^ y, ["x"], QQ)
  })
  assert_true(bad_pow_kind is BadExponent)

  let bad_pow_neg = expect_poly_error(fn() raise PolyError {
    Poly::from_expr(x ^ @symcore.int(-1), ["x"], QQ)
  })
  assert_true(bad_pow_neg is BadExponent)

  let bad_expr_kind = expect_poly_error(fn() raise PolyError {
    Poly::from_expr(@symcore.function("sin", [x]), ["x"], QQ)
  })
  assert_true(bad_expr_kind is NonPolynomial)
}
