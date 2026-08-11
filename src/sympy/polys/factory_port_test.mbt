///|
fn factory_sympy_norm(s : String) -> String raise {
  sympy_normalize(s).trim().to_owned()
}

///|
test "factory: from_expr_defaults infers gens/domain QQ" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = x * y + @symcore.rational_from_ints(1, 2)
  let poly = Poly::from_expr_defaults(expr)
  debug_inspect(poly.gens, content="[\"x\", \"y\"]")
  match poly.domain {
    QQ => ()
    _ => fail("expected QQ domain")
  }
  let ours = factory_sympy_norm(poly.to_string())
  let oracle = factory_sympy_norm(poly_expr(expr, gens=["x", "y"], domain="QQ"))
  assert_eq(ours, oracle)
}

///|
test "factory: modulus selects GF domain" {
  let x = @symcore.Expr::Symbol("x")
  let expr = x + @symcore.int(1)
  let poly = Poly::from_expr_defaults(expr, modulus=5)
  match poly.domain {
    GF(p) => inspect("\{p}", content="5")
    _ => fail("expected GF(5)")
  }
  let ours = factory_sympy_norm(poly.to_string())
  let oracle = factory_sympy_norm(poly_expr(expr, gens=["x"], modulus=5))
  assert_eq(ours, oracle)
}

///|
test "factory: gaussian flag upgrades to CC" {
  let x = @symcore.Expr::Symbol("x")
  let expr = (x ^ @symcore.int(2)) + @symcore.int(1)
  let poly = Poly::from_expr_defaults(expr, gaussian=true)
  match poly.domain {
    CC => ()
    _ => fail("expected CC domain")
  }
}

///|
test "factory: explicit gens order preserved" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = x + y
  let poly = Poly::from_expr_defaults(expr, gens=["y", "x"])
  debug_inspect(poly.gens, content="[\"y\", \"x\"]")
}
