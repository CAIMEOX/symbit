///|
fn modgcd_port_repr(
  parts : (@sympolys.Poly, @sympolys.Poly, @sympolys.Poly),
) -> String raise {
  let h = remove_spaces(
    sympy_normalize(@symprint.pretty_string(parts.0.to_expr())),
  )
  let cff = remove_spaces(
    sympy_normalize(@symprint.pretty_string(parts.1.to_expr())),
  )
  let cfg = remove_spaces(
    sympy_normalize(@symprint.pretty_string(parts.2.to_expr())),
  )
  "(\{h},\{cff},\{cfg})"
}

///|
fn func_field_modgcd_port_repr(
  parts : (@sympolys.Poly, @sympolys.Poly, @sympolys.Poly),
) -> String raise {
  let h = func_field_modgcd_poly_text(parts.0)
  let cff = func_field_modgcd_poly_text(parts.1)
  let cfg = func_field_modgcd_poly_text(parts.2)
  "(\{h},\{cff},\{cfg})"
}

///|
fn func_field_modgcd_poly_text(poly : @sympolys.Poly) -> String raise {
  let text = @symprint.pretty_string(poly.to_expr()).replace_all(
    old="a",
    new="sqrt(2)",
  )
  remove_spaces(sympy_normalize(text))
}

///|
test "modulargcd: univariate parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], ZZ)
  for
    pair in [
      (
        b.from_expr((x ^ @symcore.int(5)) - @symcore.int(1)),
        b.from_expr(x - @symcore.int(1)),
      ),
      (
        b.from_expr(@symcore.int(6) * (x ^ @symcore.int(2)) - @symcore.int(6)),
        b.from_expr(
          @symcore.int(2) * (x ^ @symcore.int(2)) +
          @symcore.int(4) * x +
          @symcore.int(2),
        ),
      ),
      (
        Poly::zero(["x"], ZZ),
        b.from_expr(@symcore.int(-1) * x + @symcore.int(1)),
      ),
    ] {
    let ours = modgcd_port_repr(@sympolys.modgcd_univariate(pair.0, pair.1))
    let oracle = modgcd_univariate(pair.0.to_expr(), pair.1.to_expr(), gen="x")
    assert_eq(ours, oracle)
  }
}

///|
test "modulargcd: bivariate and multivariate parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let b2 = PolyBuilder::new(["x", "y"], ZZ)
  let f = b2.from_expr((x ^ @symcore.int(2)) - (y ^ @symcore.int(2)))
  let g = b2.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x * y + (y ^ @symcore.int(2)),
  )
  assert_eq(
    modgcd_port_repr(@sympolys.modgcd_bivariate(f, g)),
    modgcd_bivariate(f.to_expr(), g.to_expr(), gens="x,y"),
  )
  assert_eq(
    modgcd_port_repr(@sympolys.modgcd_multivariate(f, g)),
    modgcd_multivariate(f.to_expr(), g.to_expr(), gens="x,y"),
  )

  let z = @symcore.Expr::Symbol("z")
  let b3 = PolyBuilder::new(["x", "y", "z"], ZZ)
  let h = x + y + z
  let f3 = b3.from_expr(h * (x - z))
  let g3 = b3.from_expr(h * (y + z))
  assert_eq(
    modgcd_port_repr(@sympolys.modgcd_multivariate(f3, g3)),
    modgcd_multivariate(f3.to_expr(), g3.to_expr(), gens="x,y,z"),
  )
}

///|
test "modulargcd: function field parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let a = @symcore.Expr::Symbol("a")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let alg_domain = @sympolys.Domain::AlgExt(QQ, ["a"], [
    (a ^ @symcore.int(2)) - @symcore.int(2),
  ])

  let b1 = PolyBuilder::new(["x"], alg_domain)
  let f1 = b1.from_expr((x ^ @symcore.int(2)) - @symcore.int(2))
  let g1 = b1.from_expr(x + a)
  assert_eq(
    func_field_modgcd_port_repr(@sympolys.func_field_modgcd(f1, g1)),
    func_field_modgcd_sqrt2((x ^ @symcore.int(2)) - @symcore.int(2), x + sqrt2),
  )

  let b2 = PolyBuilder::new(["x", "y"], alg_domain)
  let f2 = b2.from_expr(
    (x ^ @symcore.int(2)) +
    @symcore.int(2) * a * x * y +
    @symcore.int(2) * (y ^ @symcore.int(2)),
  )
  let g2 = b2.from_expr(x + a * y)
  assert_eq(
    func_field_modgcd_port_repr(@sympolys.func_field_modgcd(f2, g2)),
    func_field_modgcd_sqrt2(
      (x ^ @symcore.int(2)) +
      @symcore.int(2) * sqrt2 * x * y +
      @symcore.int(2) * (y ^ @symcore.int(2)),
      x + sqrt2 * y,
      gens="x,y",
    ),
  )
}
