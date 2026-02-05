///|
test "symconcrete deltasummation basic" {
  let i = @symcore.symbol("i")
  let delta = @symcore.function("KroneckerDelta", [i, @symcore.int(2)])
  let limits = [limit_range(i, @symcore.int(0), @symcore.int(3))]
  let ours = deltasummation(delta, limits)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("1"))
}

///|
test "symconcrete deltasummation with factor" {
  let i = @symcore.symbol("i")
  let delta = @symcore.function("KroneckerDelta", [i, @symcore.int(2)])
  let expr = @symcore.mul([delta, @symcore.add([i, @symcore.int(5)])])
  let limits = [limit_range(i, @symcore.int(0), @symcore.int(3))]
  let ours = deltasummation(expr, limits)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("7"))
}

///|
test "symconcrete deltaproduct range" {
  let i = @symcore.symbol("i")
  let delta = @symcore.function("KroneckerDelta", [i, @symcore.int(2)])
  let limits = [limit_range(i, @symcore.int(0), @symcore.int(3))]
  let ours = deltaproduct(delta, limits)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("0"))
}

///|
test "symconcrete deltaproduct singleton" {
  let i = @symcore.symbol("i")
  let delta = @symcore.function("KroneckerDelta", [i, @symcore.int(2)])
  let expr = @symcore.mul([delta, @symcore.add([i, @symcore.int(1)])])
  let limits = [limit_range(i, @symcore.int(2), @symcore.int(2))]
  let ours = deltaproduct(expr, limits)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("3"))
}

///|
test "symconcrete deltasummation symbolic bounds piecewise" {
  let i = @symcore.symbol("i")
  let k = @symcore.symbol("k")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let delta = @symcore.function("KroneckerDelta", [i, k])
  let expr = @symcore.mul([delta, @symcore.add([i, @symcore.int(1)])])
  let limits = [limit_range(i, a, b)]
  let ours = deltasummation(expr, limits)
  let ours_str = @symprint.to_string(ours)
  let expected =
    "Piecewise(Tuple(k + 1, And(Le(a, k), Le(k, b))), Tuple(0, True))"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}

///|
test "symconcrete deltaproduct symbolic bounds piecewise" {
  let i = @symcore.symbol("i")
  let k = @symcore.symbol("k")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let delta = @symcore.function("KroneckerDelta", [i, k])
  let expr = @symcore.mul([delta, @symcore.add([i, @symcore.int(1)])])
  let limits = [limit_range(i, a, b)]
  let ours = deltaproduct(expr, limits)
  let ours_str = @symprint.to_string(ours)
  let expected =
    "Piecewise(Tuple(k + 1, And(Eq(a, b), Eq(k, a))), Tuple(0, True))"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}
