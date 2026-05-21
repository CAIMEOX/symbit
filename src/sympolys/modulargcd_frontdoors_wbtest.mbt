///|
fn modgcd_wb_repr(parts : (Poly, Poly, Poly)) -> String {
  "(\{parts.0.to_string()}, \{parts.1.to_string()}, \{parts.2.to_string()})"
}

///|
test "modulargcd frontdoor: univariate gcd cofactors" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
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

  let zero = Poly::zero(["x"], Domain::ZZ)
  inspect(
    modgcd_wb_repr(modgcd_univariate(zero, b.from_expr(int(-1) * x + int(1)))),
    content="(x - 1, 0, -1)",
  )
}
