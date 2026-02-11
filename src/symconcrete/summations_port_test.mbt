///|
test "symconcrete summation finite integer" {
  let k = @symcore.symbol("k")
  let limits = [limit_range(k, @symcore.int(1), @symcore.int(3))]
  let ours = summation(k, limits~)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("6"))
}

///|
test "symconcrete summation constant term" {
  let k = @symcore.symbol("k")
  let y = @symcore.symbol("y")
  let limits = [limit_range(k, @symcore.int(1), @symcore.int(3))]
  let ours = summation(y, limits~)
  let ours_str = @symprint.to_string(ours)
  assert_eq(normalize_srepr(ours_str), normalize_srepr("3*y"))
}

///|
test "symconcrete Sum reverse_order parity" {
  let k = @symcore.symbol("k")
  let sum = Sum::{
    expr: k,
    limits: [limit_range(k, @symcore.int(0), @symcore.int(3))],
  }
  let ours = sum.reverse_order().as_expr()
  let ours_str = @symprint.to_string(ours)
  let expected = "Sum(-k, (k, 4, -1))"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}

///|
test "symconcrete Sum change_index shift" {
  let k = @symcore.symbol("k")
  let sum = Sum::{
    expr: k,
    limits: [limit_range(k, @symcore.int(0), @symcore.int(3))],
  }
  let ours = sum.change_index(k, @symcore.add([k, @symcore.int(1)])).as_expr()
  let ours_str = @symprint.to_string(ours)
  let expected = "Sum(k - 1, (k, 1, 4))"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}

///|
test "symconcrete summation polynomial symbolic" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let expr = @symcore.pow(k, @symcore.int(2))
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "n*(n + 1)*(2*n + 1)/6"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation geometric symbolic" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let r = @symcore.symbol("r")
  let expr = @symcore.pow(r, k)
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "(r**(n + 1) - 1)/(r - 1)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation telescoping symbolic" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let kp1 = @symcore.add([k, @symcore.int(1)])
  let expr = @symcore.add([
    @symcore.pow(kp1, @symcore.int(2)),
    @symcore.mul([@symcore.int(-1), @symcore.pow(k, @symcore.int(2))]),
  ])
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "(n + 1)**2"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation binomial hyper" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let expr = @symcomb.binomial(n, k)
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "2**n"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation binomial weighted" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let a = @symcore.symbol("a")
  let expr = @symcore.mul([@symcomb.binomial(n, k), @symcore.pow(a, k)])
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "(1 + a)**n"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation binomial k weighted" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let a = @symcore.symbol("a")
  let expr = @symcore.mul([k, @symcomb.binomial(n, k), @symcore.pow(a, k)])
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "n*a*(1 + a)**(n - 1)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation harmonic finite" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let expr = @symcore.pow(k, @symcore.int(-1))
  let limits = [limit_range(k, @symcore.int(1), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "harmonic(n)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation zeta infinite" {
  let k = @symcore.symbol("k")
  let expr = @symcore.pow(k, @symcore.int(-2))
  let limits = [limit_range(k, @symcore.int(1), @symcore.symbol("oo"))]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "zeta(2)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete summation geometric infinite piecewise" {
  let k = @symcore.symbol("k")
  let r = @symcore.symbol("r")
  let expr = @symcore.pow(r, k)
  let limits = [limit_range(k, @symcore.int(0), @symcore.symbol("oo"))]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "Piecewise(Tuple(1/(1 - r), Lt(Abs(r), 1)), Tuple(Sum(r**k, (k, 0, oo)), True))"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}

///|
test "symconcrete summation weighted geometric" {
  let k = @symcore.symbol("k")
  let n = @symcore.symbol("n")
  let r = @symcore.symbol("r")
  let expr = @symcore.mul([k, @symcore.pow(r, k)])
  let limits = [limit_range(k, @symcore.int(0), n)]
  let ours = summation(expr, limits~)
  let ours_str = @symprint.to_string(ours)
  let expected = "(r - (n + 1)*r**(n + 1) + n*r**(n + 2))/(1 - r)**2"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}
