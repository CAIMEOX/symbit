///|
fn tsch_port_pair_text(
  poly : @sympolys.Poly,
) -> String raise @sympolys.PolyError {
  let (a, u) = @sympolys.tschirnhausen_transformation(poly, max_tries=10)
  "(\{a.to_string()}, \{u.to_string()})"
}

///|
test "numberfields galois: tschirnhausen transformation parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], @sympolys.Domain::ZZ)
  let cases = [
    b.from_expr((x ^ @symcore.int(3)) - @symcore.int(2)),
    b.from_expr((x ^ @symcore.int(4)) + x + @symcore.int(1)),
    b.from_expr(
      (x ^ @symcore.int(3)) -
      (x ^ @symcore.int(2)) -
      @symcore.int(2) * x +
      @symcore.int(1),
    ),
  ]
  for item in cases {
    assert_eq(
      remove_spaces(sympy_normalize(tsch_port_pair_text(item))),
      remove_spaces(
        sympy_normalize(
          tschirnhausen_transformation(item.to_expr(), gens=["x"], max_tries=10),
        ),
      ),
    )
  }
}
