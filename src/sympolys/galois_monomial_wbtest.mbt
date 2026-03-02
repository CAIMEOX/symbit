///|
test "galoistools wb: edge-case branches" {
  let bad_mod : Result[Int, PolyError] = try? inv_mod(1, 1)
  guard bad_mod is Err(PolyError::BadModulus) else {
    fail("inv_mod with p<=1 should raise BadModulus")
  }

  let not_invertible : Result[Int, PolyError] = try? inv_mod(2, 4)
  guard not_invertible is Err(PolyError::DivisionByZero) else {
    fail("inv_mod with non-unit should raise DivisionByZero")
  }

  guard gf_strip([0, 0, 0]).length() == 0 else {
    fail("gf_strip all-zero polynomial should become []")
  }

  let add_empty_left = gf_add([], [6, 7], 5)
  guard add_empty_left.length() == 2 && add_empty_left[0] == 1 && add_empty_left[1] == 2 else {
    fail("gf_add empty-left branch mismatch")
  }
  let add_empty_right = gf_add([6, 7], [], 5)
  guard add_empty_right.length() == 2 && add_empty_right[0] == 1 &&
    add_empty_right[1] == 2 else {
    fail("gf_add empty-right branch mismatch")
  }
  let add_mixed = gf_add([1], [1, 2], 5)
  guard add_mixed.length() == 2 && add_mixed[0] == 1 && add_mixed[1] == 3 else {
    fail("gf_add mixed-length branch mismatch")
  }
  let add_mixed_rev = gf_add([1, 2], [1], 5)
  guard add_mixed_rev.length() == 2 && add_mixed_rev[0] == 1 &&
    add_mixed_rev[1] == 3 else {
    fail("gf_add mixed-length (reversed) branch mismatch")
  }

  let sub_empty_left = gf_sub([], [1, 2], 5)
  guard sub_empty_left.length() == 2 && sub_empty_left[0] == 4 &&
    sub_empty_left[1] == 3 else {
    fail("gf_sub empty-left branch mismatch")
  }
  let sub_empty_right = gf_sub([6, 7], [], 5)
  guard sub_empty_right.length() == 2 && sub_empty_right[0] == 1 &&
    sub_empty_right[1] == 2 else {
    fail("gf_sub empty-right branch mismatch")
  }
  let sub_mixed = gf_sub([1], [1, 2], 5)
  guard sub_mixed.length() == 2 && sub_mixed[0] == 4 && sub_mixed[1] == 4 else {
    fail("gf_sub mixed-length branch mismatch")
  }
  let sub_mixed_rev = gf_sub([1, 2], [1], 5)
  guard sub_mixed_rev.length() == 2 && sub_mixed_rev[0] == 1 &&
    sub_mixed_rev[1] == 1 else {
    fail("gf_sub mixed-length (reversed) branch mismatch")
  }

  guard gf_mul([], [1], 5).length() == 0 else {
    fail("gf_mul with empty input should be []")
  }
  guard (try! gf_monic([], 5)).length() == 0 else {
    fail("gf_monic([]) should stay []")
  }

  let div_by_zero : Result[(Array[Int], Array[Int]), PolyError] = try? gf_div(
    [1, 2],
    [0, 0],
    5,
  )
  guard div_by_zero is Err(PolyError::DivisionByZero) else {
    fail("gf_div by zero polynomial should raise DivisionByZero")
  }

  let (q0, r0) = try! gf_div([], [1, 1], 5)
  guard q0.length() == 0 && r0.length() == 0 else {
    fail("gf_div empty dividend branch mismatch")
  }

  let (q1, r1) = try! gf_div([1, 2], [1, 0, 1], 5)
  guard q1.length() == 0 && r1.length() > 0 else {
    fail("gf_div low-degree dividend branch mismatch")
  }
}

///|
test "monomial wb: mismatch/error/order branches" {
  let a2 = monomial_from_array([1, 2])
  let b1 = monomial_from_array([1])

  let mul_mismatch : Result[Monomial, PolyError] = try? monomial_mul(a2, b1)
  guard mul_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_mul length mismatch should raise DomainMismatch")
  }

  let pow_neg : Result[Monomial, PolyError] = try? monomial_pow(a2, -1)
  guard pow_neg is Err(PolyError::BadExponent) else {
    fail("monomial_pow negative exponent should raise BadExponent")
  }

  let divides_mismatch : Result[Bool, PolyError] = try? monomial_divides(a2, b1)
  guard divides_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_divides length mismatch should raise DomainMismatch")
  }

  let div_mismatch : Result[Monomial?, PolyError] = try? monomial_div(a2, b1)
  guard div_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_div length mismatch should raise DomainMismatch")
  }

  let lcm_mismatch : Result[Monomial, PolyError] = try? monomial_lcm(a2, b1)
  guard lcm_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_lcm length mismatch should raise DomainMismatch")
  }

  let gcd_mismatch : Result[Monomial, PolyError] = try? monomial_gcd(a2, b1)
  guard gcd_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_gcd length mismatch should raise DomainMismatch")
  }

  let gcd_ok = try! monomial_gcd(
    monomial_from_array([1, 5]),
    monomial_from_array([2, 3]),
  )
  let gcd_exps = gcd_ok.to_array()
  guard gcd_exps.length() == 2 && gcd_exps[0] == 1 && gcd_exps[1] == 3 else {
    fail("monomial_gcd min-branch mismatch")
  }

  let max_mismatch : Result[Monomial, PolyError] = try? monomial_max([
    monomial_from_array([1, 2]),
    monomial_from_array([3]),
  ])
  guard max_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_max mismatch should raise DomainMismatch")
  }

  let min_mismatch : Result[Monomial, PolyError] = try? monomial_min([
    monomial_from_array([1, 2]),
    monomial_from_array([3]),
  ])
  guard min_mismatch is Err(PolyError::DomainMismatch) else {
    fail("monomial_min mismatch should raise DomainMismatch")
  }

  guard monomial_count(-1, 2) == 0 else {
    fail("monomial_count negative vars should return 0")
  }

  guard cmp_int(2, 2) == 0 else { fail("cmp_int equal branch mismatch") }

  let lex_mismatch : Result[Int, PolyError] = try? compare_exps_lex([1], [1, 0])
  guard lex_mismatch is Err(PolyError::DomainMismatch) else {
    fail("compare_exps_lex mismatch should raise DomainMismatch")
  }

  guard (try! compare_exps_grlex([1, 0], [0, 1])) == 1 else {
    fail("compare_exps_grlex equal-degree lex-fallback mismatch")
  }
  let grlex_mismatch : Result[Int, PolyError] = try? compare_exps_grlex([1], [1, 0])
  guard grlex_mismatch is Err(PolyError::DomainMismatch) else {
    fail("compare_exps_grlex mismatch should raise DomainMismatch")
  }

  let grevlex_mismatch : Result[Int, PolyError] = try? compare_exps_grevlex(
    [1],
    [1, 0],
  )
  guard grevlex_mismatch is Err(PolyError::DomainMismatch) else {
    fail("compare_exps_grevlex mismatch should raise DomainMismatch")
  }
  guard (try! compare_exps_grevlex([2, 0], [1, 0])) == 1 else {
    fail("compare_exps_grevlex degree-compare branch mismatch")
  }
}
