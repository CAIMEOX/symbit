///|
test "symconcrete ExprWithLimits to_expr Sum" {
  let x = @symcore.symbol("x")
  let limits = [limit_range(x, @symcore.int(1), @symcore.int(3))]
  let ewl = ExprWithLimits::{ expr: x, limits }
  let expr = ewl.to_expr("Sum")
  let ours = @symprint.to_string(expr)
  let expected = "Sum(x, (x, 1, 3))"
  assert_eq(normalize_srepr(ours), normalize_srepr(expected))
}

///|
test "symconcrete ExprWithLimits free_symbols" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.add([x, y])
  let limits = [limit_range(x, @symcore.int(0), @symcore.int(2))]
  let ewl = ExprWithLimits::{ expr, limits }
  let free = ewl.free_symbols()
  assert_eq(free, ["y"])
}

///|
test "symconcrete ExprWithLimits finite limits check" {
  let x = @symcore.symbol("x")
  let finite = ExprWithLimits::{
    expr: x,
    limits: [limit_range(x, @symcore.int(1), @symcore.int(2))],
  }
  let infinite = ExprWithLimits::{ expr: x, limits: [limit_var(x)] }
  assert_eq(finite.has_finite_limits(), true)
  assert_eq(finite.has_infinite_limits(), false)
  assert_eq(infinite.has_finite_limits(), false)
  assert_eq(infinite.has_infinite_limits(), true)
}
