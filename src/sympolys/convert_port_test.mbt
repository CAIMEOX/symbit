///|
test "convert: to_expr roundtrip over ZZ" {
  let x = @symcore.symbol("x")
  let expr = (x ^ @symcore.int(3)) + @symcore.int(2) * x + @symcore.int(1)
  let poly = PolyBuilder::new(["x"], Domain::ZZ).from_expr(expr)
  let ours = poly.to_string()
  assert_true(@sympy_polys.expr_equal(ours, @symprint.to_string(expr)))
}

///|
test "convert: to_expr roundtrip over QQ with ordering" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.rational_from_ints(1, 2) * (x ^ @symcore.int(2)) +
    @symcore.rational_from_ints(3, 4) * y +
    @symcore.int(1)
  let poly = PolyBuilder::new(["x", "y"], Domain::QQ)
    .order(TermOrder::Lex)
    .from_expr(expr)
  let ours = poly.to_string()
  assert_true(@sympy_polys.expr_equal(ours, @symprint.to_string(expr)))
}

///|
test "convert: to_string matches SymPy poly_expr over GF" {
  let x = @symcore.symbol("x")
  let expr = @symcore.rational_from_ints(3, 2) * x +
    @symcore.rational_from_ints(1, 3)
  let poly = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(expr)
  let ours = @sympy_polys.sympy_normalize(poly.to_string()).trim().to_string()
  let c1 = @sympy_polys.mod_rational(3, 2, 5)
  let c0 = @sympy_polys.mod_rational(1, 3, 5)
  let expected = "\{c1}*x + \{c0}"
  let oracle = @sympy_polys.sympy_normalize(expected).trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "convert: explicit order and leading helpers cover option branches" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let poly = PolyBuilder::new(["x", "y"], Domain::QQ)
    .order(TermOrder::Grlex)
    .from_expr((x ^ @symcore.int(2)) + y + @symcore.int(1))

  let as_lex = sympy_normalize(poly.to_string(order=TermOrder::Lex))
  let as_default = sympy_normalize(poly.to_string())
  assert_eq(as_lex, as_default)

  let lc = poly.lc(order=TermOrder::Lex)
  assert_eq(lc.to_string(), "1")
  assert_true(poly.lm(order=TermOrder::Lex) is Some(_))
  assert_true(poly.lt(order=TermOrder::Lex) is Some(_))

  let z = Poly::zero(["x"], Domain::QQ)
  assert_eq(z.lc().to_string(), "0")
  assert_true(z.lm() is None)
  assert_true(z.lt() is None)

  // Cover `impl Show for Poly`.
  let shown = "\{poly}"
  assert_true(shown.length() > 0)
}

///|
test "convert: parse_expr failure branches are typed" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")

  let bad_gen : Result[Poly, PolyError] = try? Poly::from_expr(
    y,
    ["x"],
    Domain::QQ,
  )
  assert_true(bad_gen is Err(PolyError::BadGenerator(_)))

  let bad_pow_kind : Result[Poly, PolyError] = try? Poly::from_expr(
    x ^ y,
    ["x"],
    Domain::QQ,
  )
  assert_true(bad_pow_kind is Err(PolyError::BadExponent))

  let bad_pow_neg : Result[Poly, PolyError] = try? Poly::from_expr(
    x ^ @symcore.int(-1),
    ["x"],
    Domain::QQ,
  )
  assert_true(bad_pow_neg is Err(PolyError::BadExponent))

  let bad_expr_kind : Result[Poly, PolyError] = try? Poly::from_expr(
    @symcore.function("sin", [x]),
    ["x"],
    Domain::QQ,
  )
  assert_true(bad_expr_kind is Err(PolyError::NonPolynomial))
}
