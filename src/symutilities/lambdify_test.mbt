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
