///|
test "lambdify evaluates common scalar expressions" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([
    @symcore.function("sin", [x]),
    @symcore.pow(x, @symcore.int(2)),
  ])
  let fn0 = lambdify(["x"], expr)
  let value = fn0.call([0.5])
  assert_true(value.is_close(@math.sin(0.5) + 0.25))
}

///|
test "lambdify accepts map arguments" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.mul([x, y])
  let fn0 = lambdify(["x", "y"], expr)
  let env : Map[String, Double] = Map([])
  env["x"] = 2.0
  env["y"] = 3.5
  assert_eq(fn0.call_map(env), 7.0)
}

///|
test "implemented_function integrates with lambdify" {
  let f = implemented_function("f", values => values[0] * values[0] + 1.0)
  let x = @symcore.Expr::Symbol("x")
  let expr = f.apply([x]) + x
  let fn0 = lambdify(["x"], expr)
  assert_eq(fn0.call([3.0]), 13.0)
}

///|
test "implemented_function errors propagate through lambdify" {
  let f = implemented_function("boom", _ => {
    raise @symutilities.UtilitiesError::InvalidArgument("boom")
  })
  let x = @symcore.Expr::Symbol("x")
  let fn0 = lambdify(["x"], f.apply([x]))
  let result : Result[Double, @symutilities.UtilitiesError] = try
    fn0.call([3.0]) |> Ok
  catch {
    error => Err(error)
  }
  debug_inspect(result, content="Err(InvalidArgument(\"boom\"))")
}

///|
test "lambdify handles Float and real ComplexFloat constants" {
  let float_value = @symcore.Float::from_str("0.125", prec=80) catch {
    _ => fail("float constant")
  }
  let float_const = @symcore.Expr::Float(float_value)
  let real_complex = @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_real(
      @symcore.Float::from_int(3),
      imag=@symcore.Float::from_int(0),
    ),
  )
  let float_fn = lambdify([], float_const)
  let real_complex_fn = lambdify([], real_complex)
  assert_true(float_fn.call([]).is_close(0.125))
  assert_true(real_complex_fn.call([]).is_close(3.0))
}

///|
test "lambdify rejects non-real ComplexFloat constants" {
  let nonreal = @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_real(
      @symcore.Float::from_int(1),
      imag=@symcore.Float::from_int(2),
    ),
  )
  let fn0 = lambdify([], nonreal)
  let result : Result[Double, @symutilities.UtilitiesError] = try
    fn0.call([]) |> Ok
  catch {
    error => Err(error)
  }
  debug_inspect(
    result,
    content="Err(Unsupported(\"lambdify does not yet support non-real complex constants\"))",
  )
}

///|
test "lambdastr renders python-style lambda text" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let expr = @symcore.function("sin", [x]) + x * y
  inspect(lambdastr(["x", "y"], expr), content="lambda x, y: x*y + sin(x)")
}
