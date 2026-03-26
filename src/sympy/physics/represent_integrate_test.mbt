///|
test "physics.quantum.represent: integrate_result collapses cartesian unities" {
  let x = @symcore.Expr::Symbol("x")
  let x1 = @symcore.Expr::Symbol("x_1")
  let x2 = @symcore.Expr::Symbol("x_2")
  let original = @symcore.raw_mul([x_op(), x_ket()])
  let result = x *
    @symcore.raw_function("DiracDelta", [x - x1]) *
    @symcore.raw_function("DiracDelta", [x1 - x2])

  quantum_test_assert_expr_equal(
    integrate_result(original, result, unities=[1]),
    "x*DiracDelta(x - x_2)",
    "integrate_result cartesian collapse",
  )
  quantum_test_assert_expr_equal(
    integrate_result(original, result),
    "x*DiracDelta(x - x_1)*DiracDelta(x_1 - x_2)",
    "integrate_result without unities is noop",
  )
}
