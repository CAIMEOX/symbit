///|
test "polys P6e groundtypes worker preserves compact integer codecs" {
  assert_eq(p6e_python_gcd(30, 12), "6")
  assert_eq(p6e_python_lcm(-30, 12), "60")
  assert_eq(p6e_python_gcdex(30, 12), "(1,-2,6)")
  assert_eq(p6e_python_gcdex(-30, 12), "(-1,-2,6)")
  assert_eq(p6e_python_gcdex(0, 0), "(0,0,0)")
}

///|
test "polys P6e galoistools worker preserves compact list codecs" {
  assert_eq(p6e_linear_congruence(3, 12, 15), "[4,9,14]")
  assert_eq(p6e_csolve_prime([1, 1, 7], 3, 1), "[1]")
  assert_eq(p6e_csolve_prime([1, 1, 7], 3, 2), "[1,4,7]")
}

///|
test "polys P6e itermonomials worker keeps names as literal symbols" {
  assert_eq(
    p6e_itermonomials_total(["x y,z", "q[r]"], 2, 1),
    "q[r] | x y,z | q[r]**2 | x y,z**2 | q[r]*x y,z",
  )
}

///|
test "polys P6e itermonomials worker materializes bounded degrees declaratively" {
  assert_eq(
    p6e_itermonomials_bounded(["x y,z", "q[r]"], [2, 3], [1, 2]),
    "q[r]**2*x y,z | q[r]**3*x y,z | q[r]**2*x y,z**2 | q[r]**3*x y,z**2",
  )
}

///|
test "polys P6e monomial worker preserves raw tuple formatting" {
  assert_eq(p6e_monomial_ldiv([3, 4, 1], [1, 2, 2]), "(2, 2, -1)")
  assert_eq(p6e_monomial_deg([3, 4, 1]), "8")
  assert_eq(p6e_term_div_zz([3, 2], 6, [1, 1], 3), "((2, 1), 2)")
}

///|
test "polys P6e monomial worker rejects None then recovers" {
  let rejected = try {
    p6e_term_div_zz([3, 2], 5, [1, 1], 3) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(p6e_monomial_deg([3, 4, 1]), "8")
}
