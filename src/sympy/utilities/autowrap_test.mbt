///|
test "autowrap returns callable and generated source" {
  let x = @symcore.Expr::Symbol("x")
  let wrapped = autowrap(@symcore.function("sin", [x]) + x, name="demo")
  assert_true(wrapped.call([0.5]).is_close(@math.sin(0.5) + 0.5))
  assert_eq(wrapped.files()[0].0, "demo.c")
}

///|
test "binary_function registers implementation for lambdify" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let bf = binary_function("f", x * y + @symcore.int(1), args=Some(["x", "y"]))
  assert_eq(bf.call([2.0, 3.0]), 7.0)
  let expr = bf.apply([x, y]) + x
  let fn0 = lambdify(["x", "y"], expr)
  assert_eq(fn0.call([2.0, 3.0]), 9.0)
}

///|
test "binary_function preserves autowrap evaluation errors" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let bf = binary_function(
    "f_bad",
    x * y + @symcore.int(1),
    args=Some(["x", "y"]),
  )
  let fn0 = lambdify(["x"], bf.apply([x]))
  let result : Result[Double, @symutilities.UtilitiesError] = try
    fn0.call([1.0]) |> Ok
  catch {
    error => Err(error)
  }
  debug_inspect(
    result,
    content="Err(InvalidArgument(\"lambdify argument count mismatch\"))",
  )
}

///|
test "ufuncify respects explicit arguments" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let wrapped = ufuncify(["y", "x"], x - y, name="swap")
  assert_eq(wrapped.call([3.0, 10.0]), 7.0)
  inspect(wrapped.files()[0].0, content="swap.c")
}
