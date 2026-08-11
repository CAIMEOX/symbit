///|
fn dispersion_int_norm(value : Int) -> String {
  if value < 0 {
    "-oo"
  } else {
    value.to_string()
  }
}

///|
test "dispersion: frontdoor parity for linear-split polynomials" {
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], QQ)
  let fp = b.from_expr((x - @symcore.int(3)) * (x + @symcore.int(3)))

  assert_eq(
    Repr(@sympolys.dispersionset(fp)).to_string(),
    dispersionset_expr(fp.to_expr(), gens=["x"]),
  )
  assert_eq(
    dispersion_int_norm(@sympolys.dispersion(fp)),
    dispersion_expr(fp.to_expr(), gens=["x"]),
  )

  let cubic = b.from_expr(
    (x - @symcore.int(1)) * (x - @symcore.int(2)) * (x - @symcore.int(4)),
  )
  let shifted = @sympolys.compose(cubic, b.from_expr(x - @symcore.int(2)))
  assert_eq(
    Repr(@sympolys.dispersionset(cubic, q=shifted)).to_string(),
    dispersionset_expr(cubic.to_expr(), q=shifted.to_expr(), gens=["x"]),
  )
  assert_eq(
    dispersion_int_norm(@sympolys.dispersion(cubic, q=shifted)),
    dispersion_expr(cubic.to_expr(), q=shifted.to_expr(), gens=["x"]),
  )
}

///|
test "dispersion: empty dispersion parity" {
  let x = @symcore.Expr::Symbol("x")
  let b = @sympolys.PolyBuilder::new(["x"], QQ)
  let far_left = b.from_expr(x - @symcore.int(5))
  let origin = b.from_expr(x)
  assert_eq(
    Repr(@sympolys.dispersionset(far_left, q=origin)).to_string(),
    dispersionset_expr(far_left.to_expr(), q=origin.to_expr(), gens=["x"]),
  )
  assert_eq(
    dispersion_int_norm(@sympolys.dispersion(far_left, q=origin)),
    dispersion_expr(far_left.to_expr(), q=origin.to_expr(), gens=["x"]),
  )
}
