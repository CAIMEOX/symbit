///|
fn order_to_sympy(order : TermOrder) -> String {
  match order {
    TermOrder::Lex => "lex"
    TermOrder::Grlex => "grlex"
    TermOrder::Grevlex => "grevlex"
  }
}

///|
fn normalize_basis_str(s : String) -> String {
  let parts : Array[String] = Array::new()
  for part in s.split("|") {
    let raw = part.to_string()
    let trimmed = raw.trim().to_string()
    parts.push(trimmed)
  }
  parts.sort()
  parts.join("|")
}

///|
fn expect_groebner_same(polys : Array[Poly], order : TermOrder) -> Unit raise {
  let basis = Poly::groebner(polys, order~)
  let ours = normalize_basis_str(groebner_to_string(basis))
  let exprs = polys.map(p => p.to_expr())
  let oracle = normalize_basis_str(
    @sympy_polys.groebner(exprs, order=order_to_sympy(order)),
  )
  guard ours == oracle else {
    fail("groebner mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "groebnertools: simple lex pair" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f1 = b.from_expr(x * y - @symcore.int(1))
  let f2 = b.from_expr(x - @symcore.int(1))
  expect_groebner_same([f1, f2], TermOrder::Lex)
}

///|
test "groebnertools: grevlex ordering changes basis" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grevlex)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f1 = b.from_expr((x ^ @symcore.int(2)) + y)
  let f2 = try! b.from_expr(x - @symcore.int(1))
  expect_groebner_same([f1, f2], TermOrder::Grevlex)
}

///|
test "groebnertools: lex basis for x^2 + 2*x*y^2, x*y + 2*y^3 - 1" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x * (y ^ @symcore.int(2)),
  )
  let g = try! b.from_expr(
    x * y + @symcore.int(2) * (y ^ @symcore.int(3)) - @symcore.int(1),
  )
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for x^3-2*x*y, x^2*y + x - 2*y^2" {
  let b = PolyBuilder::new(["x", "y"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let f = b.from_expr((x ^ @symcore.int(3)) + @symcore.int(-2) * x * y)
  let g = try! b.from_expr(
    (x ^ @symcore.int(2)) * y + x + @symcore.int(-2) * (y ^ @symcore.int(2)),
  )
  expect_groebner_same([f, g], TermOrder::Grlex)
}

///|
test "groebnertools: lex basis for x - z^2, y - z^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f = b.from_expr(x - (z ^ @symcore.int(2)))
  let g = try! b.from_expr(y - (z ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for x - z^2, y - z^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f = b.from_expr(x - (z ^ @symcore.int(2)))
  let g = try! b.from_expr(y - (z ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Grlex)
}

///|
test "groebnertools: lex basis for y - x^2, z - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f = b.from_expr(y - (x ^ @symcore.int(2)))
  let g = try! b.from_expr(z - (x ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for y - x^2, z - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f = b.from_expr(y - (x ^ @symcore.int(2)))
  let g = try! b.from_expr(z - (x ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Grlex)
}

///|
test "groebnertools: grevlex basis for x*y + z, x - z, y - z" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(
    TermOrder::Grevlex,
  )
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f1 = b.from_expr(x * y + z)
  let f2 = b.from_expr(x - z)
  let f3 = try! b.from_expr(y - z)
  expect_groebner_same([f1, f2, f3], TermOrder::Grevlex)
}

///|
test "groebnertools: lex basis for sphere constraints" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f1 = b.from_expr(
    (x ^ @symcore.int(2)) +
    (y ^ @symcore.int(2)) +
    (z ^ @symcore.int(2)) +
    @symcore.int(-1),
  )
  let f2 = b.from_expr(x - y)
  let f3 = try! b.from_expr(y - z)
  expect_groebner_same([f1, f2, f3], TermOrder::Lex)
}

///|
test "groebnertools: lex basis for z - x^2, y - x^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f = b.from_expr(z - (x ^ @symcore.int(2)))
  let g = try! b.from_expr(y - (x ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Lex)
}

///|
test "groebnertools: grlex basis for x - y^2, z - y^3" {
  let b = PolyBuilder::new(["x", "y", "z"], Domain::QQ).order(TermOrder::Grlex)
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let f = b.from_expr(x - (y ^ @symcore.int(2)))
  let g = try! b.from_expr(z - (y ^ @symcore.int(3)))
  expect_groebner_same([f, g], TermOrder::Grlex)
}
