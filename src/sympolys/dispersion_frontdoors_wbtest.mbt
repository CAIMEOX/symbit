///|
test "dispersion frontdoors: univariate dispersion set" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], QQ)
  let fp = b.from_expr((x - int(3)) * (x + int(3)))

  debug_inspect(dispersionset(fp), content="[0, 6]")
  inspect(dispersion(fp), content="6")

  let cubic = b.from_expr((x - int(1)) * (x - int(2)) * (x - int(4)))
  let shifted = poly_shift_int(cubic, -2)
  debug_inspect(dispersionset(cubic, q=shifted), content="[0, 1, 2, 3, 4, 5]")
  inspect(dispersion(cubic, q=shifted), content="5")

  let far_left = b.from_expr(x - int(5))
  let origin = b.from_expr(x)
  debug_inspect(dispersionset(far_left, q=origin), content="[]")
  inspect(dispersion(far_left, q=origin), content="-1")
}

///|
test "dispersion frontdoors: constants and invalid inputs" {
  let x = Expr::Symbol("x")
  let b = PolyBuilder::new(["x"], ZZ)
  let c = b.from_expr(int(5))
  debug_inspect(dispersionset(c), content="[0]")
  inspect(dispersion(c), content="0")

  let by = PolyBuilder::new(["y"], ZZ)
  sympolys_assert_error(
    fn() raise PolyError {
      dispersionset(
        b.from_expr(x + int(1)),
        q=by.from_expr(Symbol("y") + int(1)),
      )
    },
    "DomainMismatch",
  )
}
