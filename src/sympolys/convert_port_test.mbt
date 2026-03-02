///|
test "convert: to_expr roundtrip over ZZ" {
  let x = @symcore.symbol("x")
  let expr = (x ^ @symcore.int(3)) + @symcore.int(2) * x + @symcore.int(1)
  let poly = PolyBuilder::new(["x"], Domain::ZZ).from_expr(expr)
  let ours = poly.to_string()
  guard @sympy_polys.expr_equal(ours, @symprint.to_string(expr)) else {
    fail("to_expr roundtrip mismatch: ours=\{ours}")
  }
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
  guard @sympy_polys.expr_equal(ours, @symprint.to_string(expr)) else {
    fail("to_expr roundtrip QQ mismatch: ours=\{ours}")
  }
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
  guard ours == oracle else {
    fail("GF to_string mismatch: ours=\{ours}, oracle=\{oracle}")
  }
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
  guard as_lex == as_default else {
    fail("explicit to_string(order=...) should stay expression-equivalent")
  }

  let lc = try! poly.lc(order=TermOrder::Lex)
  guard lc.to_string() == "1" else { fail("lc(order=...) mismatch") }
  guard poly.lm(order=TermOrder::Lex) is Some(_) else {
    fail("lm(order=...) should be present")
  }
  guard poly.lt(order=TermOrder::Lex) is Some(_) else {
    fail("lt(order=...) should be present")
  }

  let z = Poly::zero(["x"], Domain::QQ)
  guard (try! z.lc()).to_string() == "0" else { fail("zero lc should be 0") }
  guard z.lm() is None else { fail("zero lm should be None") }
  guard z.lt() is None else { fail("zero lt should be None") }

  // Cover `impl Show for Poly`.
  let shown = "\{poly}"
  guard shown.length() > 0 else { fail("Show(Poly) should not be empty") }
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
  guard bad_gen is Err(PolyError::BadGenerator(_)) else {
    fail("expected BadGenerator for symbol not in gens")
  }

  let bad_pow_kind : Result[Poly, PolyError] = try? Poly::from_expr(
    x ^ y,
    ["x"],
    Domain::QQ,
  )
  guard bad_pow_kind is Err(PolyError::BadExponent) else {
    fail("expected BadExponent for non-numeric exponent")
  }

  let bad_pow_neg : Result[Poly, PolyError] = try? Poly::from_expr(
    x ^ @symcore.int(-1),
    ["x"],
    Domain::QQ,
  )
  guard bad_pow_neg is Err(PolyError::BadExponent) else {
    fail("expected BadExponent for negative exponent")
  }

  let bad_expr_kind : Result[Poly, PolyError] = try? Poly::from_expr(
    @symcore.function("sin", [x]),
    ["x"],
    Domain::QQ,
  )
  guard bad_expr_kind is Err(PolyError::NonPolynomial) else {
    fail("expected NonPolynomial for Function expression")
  }
}
