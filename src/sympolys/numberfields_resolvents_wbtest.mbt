///|
fn nf_resolvent_wb_text(coeffs : Array[FieldElem]) -> String {
  "[" + coeffs.map(c => c.to_string()).join(", ") + "]"
}

///|
test "numberfields galois: degree four resolvent lookup" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  inspect(
    nf_resolvent_wb_text(
      get_resolvent_by_lookup(b.from_expr((x ^ int(4)) + x + int(1)), 1),
    ),
    content="[1, 0, -4, -1]",
  )
  inspect(
    nf_resolvent_wb_text(
      get_resolvent_by_lookup(
        b.from_expr(
          (x ^ int(4)) +
          (x ^ int(3)) +
          int(2) * (x ^ int(2)) +
          int(3) * x +
          int(4),
        ),
        1,
      ),
    ),
    content="[1, -2, -13, 19]",
  )
  let unsupported : Result[Array[FieldElem], PolyError] = try? get_resolvent_by_lookup(
    b.from_expr((x ^ int(3)) - int(2)),
    1,
  )
  assert_true(unsupported is Err(PolyError::BadGenerator(_)))
}
