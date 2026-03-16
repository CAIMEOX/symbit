///|
test "lambdify evaluates common scalar expressions" {
  let x = @symcore.symbol("x")
  let expr = @symcore.add([
    @symcore.function("sin", [x]),
    @symcore.pow(x, @symcore.int(2)),
  ])
  let fn0 = lambdify(["x"], expr)
  let value = try! fn0.call([0.5])
  assert_true(value.is_close(@math.sin(0.5) + 0.25))
}

///|
test "lambdify accepts map arguments" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.mul([x, y])
  let fn0 = lambdify(["x", "y"], expr)
  let env : Map[String, Double] = {}
  env["x"] = 2.0
  env["y"] = 3.5
  assert_eq(try! fn0.call_map(env), 7.0)
}

///|
test "implemented_function integrates with lambdify" {
  let f = implemented_function("f", values => values[0] * values[0] + 1.0)
  let x = @symcore.symbol("x")
  let expr = f.apply([x]) + x
  let fn0 = lambdify(["x"], expr)
  assert_eq(try! fn0.call([3.0]), 13.0)
}

///|
test "lambdastr renders python-style lambda text" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.function("sin", [x]) + x * y
  inspect(lambdastr(["x", "y"], expr), content="lambda x, y: x*y + sin(x)")
}
