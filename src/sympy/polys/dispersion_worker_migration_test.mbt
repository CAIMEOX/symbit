///|
test "polys dispersion worker preserves literal generators and shared identity" {
  let literal = @symcore.Expr::Symbol("x y,z")
  assert_eq(dispersionset_expr(literal, gens=["x y,z"]), "[0]")
  assert_eq(dispersion_expr(literal, gens=["x y,z"]), "0")

  let dummy = @symcore.Expr::Dummy("d", 2401)
  assert_eq(dispersionset_expr(dummy, q=dummy), "[0]")
  assert_eq(dispersion_expr(dummy, q=dummy), "0")
}

///|
test "polys dispersion worker propagates errors and recovers" {
  let bad = @symcore.int(1)
  let raised = try {
    let _ = dispersion_expr(bad)
    false
  } catch {
    _ => true
  }
  assert_true(raised)
  let x = @symcore.Expr::Symbol("x")
  assert_eq(dispersion_expr(x, gens=["x"]), "0")
}
