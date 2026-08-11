///|
test "algebras worker preserves expression data in quaternion components" {
  let zero = @symcore.int(0)
  let symbol = @symcore.Expr::Symbol("x y,z")
  assert_eq(quat_add(symbol, zero, zero, zero, zero, zero, zero, zero), [
    "x y,z", "0", "0", "0",
  ])
  let dummy = @symcore.Expr::Dummy("d", 701)
  let negative = @symcore.mul([@symcore.int(-1), dummy])
  assert_eq(
    quat_add(dummy, zero, zero, zero, negative, zero, zero, zero)[0],
    "0",
  )
}

///|
test "algebras worker reports parser errors and recovers" {
  let rejected = try {
    expr_equal("(", "0") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(expr_equal("x + 1", "1 + x"))
}
