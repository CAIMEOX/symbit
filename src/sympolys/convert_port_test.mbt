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
