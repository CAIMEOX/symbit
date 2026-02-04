///|
fn factory_sympy_norm(s : String) -> String {
  try! @sympy_polys.sympy_normalize(s).trim().to_string()
}

///|
test "factory: from_expr_defaults infers gens/domain QQ" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = x * y + @symcore.rational_from_ints(1, 2)
  let poly = Poly::from_expr_defaults(expr)
  inspect(poly.gens.to_string(), content="[\"x\", \"y\"]")
  match poly.domain {
    Domain::QQ => ()
    _ => fail("expected QQ domain")
  }
  let ours = factory_sympy_norm(poly.to_string())
  let oracle = factory_sympy_norm(
    @sympy_polys.poly_expr(expr, gens=["x", "y"], domain="QQ"),
  )
  guard ours == oracle else {
    fail("from_expr_defaults mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factory: modulus selects GF domain" {
  let x = @symcore.symbol("x")
  let expr = x + @symcore.int(1)
  let poly = Poly::from_expr_defaults(expr, modulus=5)
  match poly.domain {
    Domain::GF(p) => inspect("\{p}", content="5")
    _ => fail("expected GF(5)")
  }
  let ours = factory_sympy_norm(poly.to_string())
  let oracle = factory_sympy_norm(
    @sympy_polys.poly_expr(expr, gens=["x"], modulus=5),
  )
  guard ours == oracle else {
    fail("GF expr mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "factory: gaussian flag upgrades to CC" {
  let x = @symcore.symbol("x")
  let expr = (x ^ @symcore.int(2)) + @symcore.int(1)
  let poly = Poly::from_expr_defaults(expr, gaussian=true)
  match poly.domain {
    Domain::CC => ()
    _ => fail("expected CC domain")
  }
}

///|
test "factory: explicit gens order preserved" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = x + y
  let poly = Poly::from_expr_defaults(expr, gens=["y", "x"])
  inspect(poly.gens.to_string(), content="[\"y\", \"x\"]")
}
