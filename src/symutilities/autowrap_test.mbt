///|
test "autowrap returns callable and generated source" {
  let x = @symcore.symbol("x")
  let wrapped = try! autowrap(@symcore.function("sin", [x]) + x, name="demo")
  assert_true((try! wrapped.call([0.5])).is_close(@math.sin(0.5) + 0.5))
  assert_eq(wrapped.files()[0].0, "demo.c")
}

///|
test "binary_function registers implementation for lambdify" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let bf = try! binary_function(
    "f",
    x * y + @symcore.int(1),
    args=Some(["x", "y"]),
  )
  assert_eq(try! bf.call([2.0, 3.0]), 7.0)
  let expr = bf.apply([x, y]) + x
  let fn0 = lambdify(["x", "y"], expr)
  assert_eq(try! fn0.call([2.0, 3.0]), 9.0)
}

///|
test "ufuncify respects explicit arguments" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let wrapped = try! ufuncify(["y", "x"], x - y, name="swap")
  assert_eq(try! wrapped.call([3.0, 10.0]), 7.0)
  inspect(wrapped.files()[0].0, content="swap.c")
}
