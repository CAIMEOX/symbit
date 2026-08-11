///|
test "tensor worker preserves literal array symbols and shared Dummy identity" {
  let symbol = @symcore.Expr::Symbol("x y,z")
  let array = @symtensor_array.dense([1], [symbol])
  assert_eq(array_str(array), "[x y,z]")
  let dummy = @symcore.Expr::Dummy("d", 901)
  let negative = @symcore.mul([@symcore.int(-1), dummy])
  let expression = @symtensor_tensor.add([
    @symtensor_tensor.scalar_expr(dummy),
    @symtensor_tensor.scalar_expr(negative),
  ])
  assert_eq(tensor_str(expression), "0")
}

///|
test "tensor worker reports parse errors and recovers" {
  let rejected = try {
    sympy_str("(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(sympy_str("2 + 2"), "4")
}

///|
test "tensor worker preserves legacy scalar and sparse array structure" {
  let dense_scalar = @symtensor_array.dense([], [@symcore.int(5)])
  assert_eq(array_str(dense_scalar), "5")
  let sparse_scalar = @symtensor_array.sparse([], [([], @symcore.int(7))])
  assert_eq(array_str(sparse_scalar), "7")
  let sparse_matrix = @symtensor_array.sparse([2, 2], [([0, 1], Symbol("x"))])
  assert_eq(array_str(sparse_matrix), "[[0, x], [0, 0]]")
}

///|
test "tensor worker infers legacy shapes after zero dimensions" {
  let leading_zero = @symtensor_array.dense([0, 2], [])
  assert_eq(
    array_srepr(leading_zero),
    "ImmutableDenseNDimArray(Tuple(), Tuple(Integer(0)))",
  )
  let middle_zero = @symtensor_array.sparse([2, 0, 3], [])
  assert_eq(
    array_srepr(middle_zero),
    "ImmutableDenseNDimArray(Tuple(), Tuple(Integer(2), Integer(0)))",
  )
  // Also exercise the string renderer that used to fail on the exact shape.
  array_str(leading_zero) |> ignore
  array_str(middle_zero) |> ignore
}
