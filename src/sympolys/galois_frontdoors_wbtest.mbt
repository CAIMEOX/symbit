///|
fn galois_wb_repr(result : GaloisGroupResult) -> String {
  "(\{result.name}, \{result.is_alt})"
}

///|
test "galois frontdoor: low degree group names" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], ZZ)
  inspect(
    galois_wb_repr(galois_group(b.from_expr(x - int(1)))),
    content="(S1, true)",
  )
  inspect(
    galois_wb_repr(galois_group(b.from_expr((x ^ int(2)) - int(2)))),
    content="(S2, false)",
  )
  inspect(
    galois_wb_repr(galois_group(b.from_expr((x ^ int(3)) - int(2)))),
    content="(S3, false)",
  )
  inspect(
    galois_wb_repr(
      galois_group(b.from_expr((x ^ int(3)) - int(3) * x + int(1))),
    ),
    content="(A3, true)",
  )
  assert_true(has_square_disc(b.from_expr((x ^ int(3)) - int(3) * x + int(1))))
  assert_false(has_square_disc(b.from_expr((x ^ int(3)) - int(2))))
  assert_true(has_square_disc(b.from_expr((x ^ int(2)) - int(4))))
  sympolys_assert_error(
    fn() raise PolyError { galois_group(b.from_expr((x ^ int(2)) - int(1))) },
    "NonPolynomial",
  )
}
