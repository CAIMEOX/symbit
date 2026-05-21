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
