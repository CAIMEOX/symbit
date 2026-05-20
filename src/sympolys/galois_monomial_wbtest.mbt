///|
fn galois_wb_arr(values : Array[Int]) -> String {
  if values.is_empty() {
    "[]"
  } else {
    "[" + values.map(v => v.to_string()).join(", ") + "]"
  }
}

///|
fn galois_wb_pair(pair : (Array[Int], Array[Int])) -> String {
  let (lhs, rhs) = pair
  "(\{galois_wb_arr(lhs)}, \{galois_wb_arr(rhs)})"
}

///|
fn galois_wb_map(values : Map[Int, Int]) -> String {
  let items : Array[(Int, Int)] = []
  for key, value in values {
    items.push((key, value))
  }
  items.sort_by((lhs, rhs) => lhs.0 - rhs.0)
  "{" + items.map(item => "\{item.0}: \{item.1}").join(", ") + "}"
}

///|
test "galoistools wb: edge-case branches" {
  let bad_mod : Result[Int, PolyError] = try? inv_mod(1, 1)
  assert_true(bad_mod is Err(PolyError::BadModulus))

  let not_invertible : Result[Int, PolyError] = try? inv_mod(2, 4)
  assert_true(not_invertible is Err(PolyError::DivisionByZero))

  assert_eq(gf_strip([0, 0, 0]).length(), 0)

  let add_empty_left = gf_add([], [6, 7], 5)
  assert_true(
    add_empty_left.length() == 2 &&
    add_empty_left[0] == 1 &&
    add_empty_left[1] == 2,
  )
  let add_empty_right = gf_add([6, 7], [], 5)
  assert_true(
    add_empty_right.length() == 2 &&
    add_empty_right[0] == 1 &&
    add_empty_right[1] == 2,
  )
  let add_mixed = gf_add([1], [1, 2], 5)
  assert_true(add_mixed.length() == 2 && add_mixed[0] == 1 && add_mixed[1] == 3)
  let add_mixed_rev = gf_add([1, 2], [1], 5)
  assert_true(
    add_mixed_rev.length() == 2 &&
    add_mixed_rev[0] == 1 &&
    add_mixed_rev[1] == 3,
  )

  let sub_empty_left = gf_sub([], [1, 2], 5)
  assert_true(
    sub_empty_left.length() == 2 &&
    sub_empty_left[0] == 4 &&
    sub_empty_left[1] == 3,
  )
  let sub_empty_right = gf_sub([6, 7], [], 5)
  assert_true(
    sub_empty_right.length() == 2 &&
    sub_empty_right[0] == 1 &&
    sub_empty_right[1] == 2,
  )
  let sub_mixed = gf_sub([1], [1, 2], 5)
  assert_true(sub_mixed.length() == 2 && sub_mixed[0] == 4 && sub_mixed[1] == 4)
  let sub_mixed_rev = gf_sub([1, 2], [1], 5)
  assert_true(
    sub_mixed_rev.length() == 2 &&
    sub_mixed_rev[0] == 1 &&
    sub_mixed_rev[1] == 1,
  )

  assert_eq(gf_mul([], [1], 5).length(), 0)
  assert_eq(gf_monic([], 5).length(), 0)

  let div_by_zero : Result[(Array[Int], Array[Int]), PolyError] = try? gf_div(
    [1, 2],
    [0, 0],
    5,
  )
  assert_true(div_by_zero is Err(PolyError::DivisionByZero))

  let (q0, r0) = gf_div([], [1, 1], 5)
  assert_true(q0.length() == 0 && r0.length() == 0)

  let (q1, r1) = gf_div([1, 2], [1, 0, 1], 5)
  assert_true(q1.length() == 0 && r1.length() > 0)
}

///|
test "galoistools wb: conversion scalar and power helpers" {
  inspect(gf_int(5, 7), content="-2")
  inspect(galois_wb_arr(gf_normal([5, 10, 21, -3], 5)), content="[1, 2]")
  let sparse : Map[Int, Int] = { 10: 4, 4: 33, 0: -1 }
  let dense = gf_from_dict(sparse, 5)
  inspect(galois_wb_arr(dense), content="[4, 0, 0, 0, 0, 0, 3, 0, 0, 0, 4]")
  inspect(galois_wb_map(gf_to_dict(dense, 5)), content="{0: -1, 4: -2, 10: -1}")
  inspect(
    galois_wb_map(gf_to_dict(dense, 5, symmetric=false)),
    content="{0: 4, 4: 3, 10: 4}",
  )
  inspect(galois_wb_arr(gf_from_int_poly([7, -2, 3], 5)), content="[2, 3, 3]")
  inspect(galois_wb_arr(gf_to_int_poly([2, 3, 3], 5)), content="[2, -2, -2]")
  inspect(galois_wb_arr(gf_neg([3, 2, 1, 0], 5)), content="[2, 3, 4, 0]")
  inspect(galois_wb_arr(gf_add_ground([3, 2, 4], 2, 5)), content="[3, 2, 1]")
  inspect(galois_wb_arr(gf_sub_ground([3, 2, 4], 2, 5)), content="[3, 2, 2]")
  inspect(galois_wb_arr(gf_mul_ground([3, 2, 4], 2, 5)), content="[1, 4, 3]")
  inspect(galois_wb_arr(gf_quo_ground([3, 2, 4], 2, 5)), content="[4, 1, 2]")
  inspect(galois_wb_arr(gf_sqr([3, 2, 4], 5)), content="[4, 2, 3, 1, 1]")
  inspect(
    galois_wb_arr(gf_add_mul([3, 2, 4], [2, 2, 2], [1, 4], 5)),
    content="[2, 3, 2, 2]",
  )
  inspect(
    galois_wb_arr(gf_sub_mul([3, 2, 4], [2, 2, 2], [1, 4], 5)),
    content="[3, 3, 2, 1]",
  )
  inspect(
    galois_wb_arr(gf_exquo([1, 0, 3, 2, 3], [2, 2, 2], 5)),
    content="[3, 2, 4]",
  )
  inspect(
    galois_wb_arr(gf_lshift([3, 2, 4], 4)),
    content="[3, 2, 4, 0, 0, 0, 0]",
  )
  inspect(
    galois_wb_pair(gf_rshift([1, 2, 3, 4, 0], 3)),
    content="([1, 2], [3, 4, 0])",
  )
  inspect(
    galois_wb_arr(gf_pow([3, 2, 4], 3, 5)),
    content="[2, 4, 4, 2, 2, 1, 4]",
  )
}

///|
test "monomial wb: mismatch/error/order branches" {
  let a2 = monomial_from_array([1, 2])
  let b1 = monomial_from_array([1])

  let mul_mismatch : Result[Monomial, PolyError] = try? monomial_mul(a2, b1)
  assert_true(mul_mismatch is Err(PolyError::DomainMismatch))

  let pow_neg : Result[Monomial, PolyError] = try? monomial_pow(a2, -1)
  assert_true(pow_neg is Err(PolyError::BadExponent))

  let divides_mismatch : Result[Bool, PolyError] = try? monomial_divides(a2, b1)
  assert_true(divides_mismatch is Err(PolyError::DomainMismatch))

  let div_mismatch : Result[Monomial?, PolyError] = try? monomial_div(a2, b1)
  assert_true(div_mismatch is Err(PolyError::DomainMismatch))

  let lcm_mismatch : Result[Monomial, PolyError] = try? monomial_lcm(a2, b1)
  assert_true(lcm_mismatch is Err(PolyError::DomainMismatch))

  let gcd_mismatch : Result[Monomial, PolyError] = try? monomial_gcd(a2, b1)
  assert_true(gcd_mismatch is Err(PolyError::DomainMismatch))

  let gcd_ok = monomial_gcd(
    monomial_from_array([1, 5]),
    monomial_from_array([2, 3]),
  )
  let gcd_exps = gcd_ok.to_array()
  assert_true(gcd_exps.length() == 2 && gcd_exps[0] == 1 && gcd_exps[1] == 3)

  let max_mismatch : Result[Monomial, PolyError] = try? monomial_max([
    monomial_from_array([1, 2]),
    monomial_from_array([3]),
  ])
  assert_true(max_mismatch is Err(PolyError::DomainMismatch))

  let min_mismatch : Result[Monomial, PolyError] = try? monomial_min([
    monomial_from_array([1, 2]),
    monomial_from_array([3]),
  ])
  assert_true(min_mismatch is Err(PolyError::DomainMismatch))

  assert_eq(monomial_count(-1, 2), 0)

  assert_eq(cmp_int(2, 2), 0)

  let lex_mismatch : Result[Int, PolyError] = try? compare_exps_lex([1], [1, 0])
  assert_true(lex_mismatch is Err(PolyError::DomainMismatch))

  assert_eq(compare_exps_grlex([1, 0], [0, 1]), 1)
  let grlex_mismatch : Result[Int, PolyError] = try? compare_exps_grlex([1], [
    1, 0,
  ])
  assert_true(grlex_mismatch is Err(PolyError::DomainMismatch))

  let grevlex_mismatch : Result[Int, PolyError] = try? compare_exps_grevlex(
    [1],
    [1, 0],
  )
  assert_true(grevlex_mismatch is Err(PolyError::DomainMismatch))
  assert_eq(compare_exps_grevlex([2, 0], [1, 0]), 1)
}
