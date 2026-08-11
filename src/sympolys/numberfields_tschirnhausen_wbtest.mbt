///|
fn tsch_wb_pair_text(poly : Poly) -> String raise PolyError {
  let (a, u) = tschirnhausen_transformation(poly, max_tries=10)
  "(\{a.to_string()}, \{u.to_string()})"
}

///|
test "numberfields galois: tschirnhausen fixed-order transformation" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  inspect(
    tsch_wb_pair_text(b.from_expr((x ^ int(3)) - int(2))),
    content="(x**2 + x + 1, _X**3 - 3*_X**2 - 3*_X - 1)",
  )
  inspect(
    tsch_wb_pair_text(b.from_expr((x ^ int(4)) + x + int(1))),
    content="(x**2 + x + 1, _X**4 - 10*_X - 4*_X**3 + 11*_X**2 + 3)",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      tschirnhausen_transformation(
        b.from_expr((x ^ int(3)) - int(3) * (x ^ int(2)) + int(3) * x - int(1)),
        max_tries=3,
      )
    },
    "BadGenerator",
  )
}
