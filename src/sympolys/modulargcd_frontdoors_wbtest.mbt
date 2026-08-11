///|
fn modgcd_wb_repr(parts : (Poly, Poly, Poly)) -> String {
  "(\{parts.0.to_string()}, \{parts.1.to_string()}, \{parts.2.to_string()})"
}

///|
test "modulargcd frontdoor: univariate gcd cofactors" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], ZZ)
  let f = b.from_expr((x ^ int(5)) - int(1))
  let g = b.from_expr(x - int(1))
  inspect(
    modgcd_wb_repr(modgcd_univariate(f, g)),
    content="(x - 1, x**2 + x**3 + x**4 + x + 1, 1)",
  )

  let f2 = b.from_expr(int(6) * (x ^ int(2)) - int(6))
  let g2 = b.from_expr(int(2) * (x ^ int(2)) + int(4) * x + int(2))
  inspect(
    modgcd_wb_repr(modgcd_univariate(f2, g2)),
    content="(2*x + 2, 3*x - 3, x + 1)",
  )

  let zero = Poly::zero(["x"], ZZ)
  inspect(
    modgcd_wb_repr(modgcd_univariate(zero, b.from_expr(int(-1) * x + int(1)))),
    content="(x - 1, 0, -1)",
  )
}

///|
test "modulargcd frontdoor: bivariate and multivariate gcd cofactors" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let b2 = PolyBuilder::new(["x", "y"], ZZ)
  let f = b2.from_expr((x ^ int(2)) - (y ^ int(2)))
  let g = b2.from_expr((x ^ int(2)) + int(2) * x * y + (y ^ int(2)))
  inspect(
    modgcd_wb_repr(modgcd_bivariate(f, g)),
    content="(x + y, x - y, x + y)",
  )
  inspect(
    modgcd_wb_repr(modgcd_multivariate(f, g)),
    content="(x + y, x - y, x + y)",
  )

  let z = Expr::Symbol("z")
  let b3 = PolyBuilder::new(["x", "y", "z"], ZZ)
  let h = x + y + z
  let f3 = b3.from_expr(h * (x - z))
  let g3 = b3.from_expr(h * (y + z))
  inspect(
    modgcd_wb_repr(modgcd_multivariate(f3, g3)),
    content="(x + y + z, x - z, y + z)",
  )
}

///|
test "modulargcd frontdoor: algebraic function field gcd cofactors" {
  let x = Expr::Symbol("x")
  let y = Expr::Symbol("y")
  let a = Expr::Symbol("a")
  let alg_domain = Domain::AlgExt(QQ, ["a"], [(a ^ int(2)) - int(2)])

  let b1 = PolyBuilder::new(["x"], alg_domain)
  let f1 = b1.from_expr((x ^ int(2)) - int(2))
  let g1 = b1.from_expr(x + a)
  let (h1, cff1, cfg1) = func_field_modgcd(f1, g1)
  inspect(h1.to_string(), content="a + x")
  assert_true(cff1.mul(h1).sub(f1).is_zero())
  assert_true(cfg1.mul(h1).sub(g1).is_zero())

  let b2 = PolyBuilder::new(["x", "y"], alg_domain)
  let f2 = b2.from_expr(
    (x ^ int(2)) + int(2) * a * x * y + int(2) * (y ^ int(2)),
  )
  let g2 = b2.from_expr(x + a * y)
  let (h2, cff2, cfg2) = func_field_modgcd(f2, g2)
  inspect(h2.to_string(), content="a*y + x")
  assert_true(cff2.mul(h2).sub(f2).is_zero())
  assert_true(cfg2.mul(h2).sub(g2).is_zero())
}
