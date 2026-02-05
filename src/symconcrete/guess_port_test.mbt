///|
test "symconcrete find_simple_recurrence_vector" {
  let seq = [
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(5),
    @symcore.int(8),
    @symcore.int(13),
  ]
  let coeffs = find_simple_recurrence_vector(seq)
  let strs = coeffs.map(@symprint.to_string)
  assert_eq(strs, ["1", "-1", "-1"])
}

///|
test "symconcrete find_simple_recurrence expr" {
  let seq = [
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(5),
    @symcore.int(8),
    @symcore.int(13),
  ]
  let rec = match find_simple_recurrence(seq) {
    Some(r) => r
    None => fail("recurrence not found")
  }
  let ours_str = @symprint.to_string(rec)
  let expected = "-a(n) - a(n + 1) + a(n + 2)"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}

///|
test "symconcrete rinterp polynomial" {
  let data = [
    @symcore.int(1),
    @symcore.int(3),
    @symcore.int(5),
  ]
  let x = @symcore.symbol("x")
  let expr = match rinterp(data, 2, x=x) {
    Some(v) => v
    None => fail("rinterp failed")
  }
  let ours_str = @symprint.to_string(expr)
  let expected = "2*x + 1"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete rinterp symbolic fallback" {
  let a = @symcore.symbol("a")
  let x = @symcore.symbol("x")
  let data = [
    a,
    @symcore.add([a, @symcore.int(1)]),
    @symcore.add([a, @symcore.int(2)]),
  ]
  let expr = match rinterp(data, 2, x=x) {
    Some(v) => v
    None => fail("rinterp symbolic fallback failed")
  }
  let ours_str = @symprint.to_string(expr)
  let expected = "a + x"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete guess_generating_function_rational geometric" {
  let data = [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(4),
    @symcore.int(8),
    @symcore.int(16),
    @symcore.int(32),
  ]
  let x = @symcore.symbol("x")
  let expr = match guess_generating_function_rational(data, x=x) {
    Some(v) => v
    None => fail("guess_generating_function_rational failed")
  }
  let ours_str = @symprint.to_string(expr)
  let expected = "1/(1 - 2*x)"
  assert_true(try! @sympy_concrete.sympy_equiv_str(ours_str, expected))
}

///|
test "symconcrete guess returns recurrence" {
  let seq = [
    @symcore.int(1),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(5),
    @symcore.int(8),
    @symcore.int(13),
  ]
  let rec = match guess(seq) {
    Some(r) => r
    None => fail("guess failed")
  }
  let ours_str = @symprint.to_string(rec)
  let expected = "-a(n) - a(n + 1) + a(n + 2)"
  assert_eq(normalize_srepr(ours_str), normalize_srepr(expected))
}
