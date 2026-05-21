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
test "modulargcd: univariate parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
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
        Poly::zero(["x"], Domain::ZZ),
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
  let b2 = PolyBuilder::new(["x", "y"], Domain::ZZ)
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
  let b3 = PolyBuilder::new(["x", "y", "z"], Domain::ZZ)
  let h = x + y + z
  let f3 = b3.from_expr(h * (x - z))
  let g3 = b3.from_expr(h * (y + z))
  assert_eq(
    modgcd_port_repr(@sympolys.modgcd_multivariate(f3, g3)),
    modgcd_multivariate(f3.to_expr(), g3.to_expr(), gens="x,y,z"),
  )
}
