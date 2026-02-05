///|
test "symconcrete product finite integer" {
  let k = @symcore.symbol("k")
  let limits = [limit_range(k, @symcore.int(1), @symcore.int(3))]
  let ours = product(k, limits=limits)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("6"))
}

///|
test "symconcrete product constant term" {
  let k = @symcore.symbol("k")
  let y = @symcore.symbol("y")
  let limits = [limit_range(k, @symcore.int(1), @symcore.int(3))]
  let ours = product(y, limits=limits)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("y**3"))
}

///|
test "symconcrete Product reverse_order parity" {
  let k = @symcore.symbol("k")
  let prod = Product::{ expr: k, limits: [limit_range(k, @symcore.int(1), @symcore.int(3))] }
  let ours = prod.reverse_order().as_expr()
  let ours_str = @symprint.to_string(ours)
  let expected = "Product(1/k, (k, 4, 0))"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}

///|
test "symconcrete product ratio telescoping" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let expr = @symcore.mul([
    @symcore.add([k, @symcore.int(1)]),
    @symcore.pow(k, @symcore.int(-1)),
  ])
  let limits = [limit_range(k, @symcore.int(1), n)]
  let ours = product(expr, limits=limits)
  let ours_str = @symprint.to_string(ours)
  let expected = "n + 1"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete product geometric symbolic" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let r = @symcore.symbol("r")
  let expr = @symcore.pow(r, k)
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = product(expr, limits=limits)
  let ours_str = @symprint.to_string(ours)
  let expected = "r**(n*(n + 1)/2)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete product factorial" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let limits = [limit_range(k, @symcore.int(1), n)]
  let ours = product(k, limits=limits)
  let ours_str = @symprint.to_string(ours)
  let expected = "factorial(n)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete product rising_factorial" {
  let k = @symcore.symbol("k")
  let a = @symcore.symbol("a")
  let n = @symcore.symbol("n")
  let expr = @symcore.add([k, a])
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = product(expr, limits=limits)
  let ours_str = @symprint.to_string(ours)
  let expected = "RisingFactorial(a, n + 1)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete product linear ratio" {
  let k = @symcore.symbol("k")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let n = @symcore.symbol("n")
  let expr = @symcore.mul([
    @symcore.add([k, a]),
    @symcore.pow(@symcore.add([k, b]), @symcore.int(-1)),
  ])
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = product(expr, limits=limits)
  let ours_str = @symprint.to_string(ours)
  let expected = "RisingFactorial(a, n + 1)/RisingFactorial(b, n + 1)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}
