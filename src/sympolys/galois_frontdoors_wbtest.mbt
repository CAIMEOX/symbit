///|
fn galois_wb_repr(result : GaloisGroupResult) -> String {
  "(\{result.name}, \{result.is_alt})"
}

///|
test "galois frontdoor: low degree group names" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
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
  let reducible : Result[GaloisGroupResult, PolyError] = try? galois_group(
    b.from_expr((x ^ int(2)) - int(1)),
  )
  assert_true(reducible is Err(PolyError::NonPolynomial))
}
