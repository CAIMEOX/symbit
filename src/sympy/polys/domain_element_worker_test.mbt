///|
test "polys domain element worker rejects malformed sources and recovers" {
  let malformed_predicate = try {
    domain_is_zero_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_value = try {
    domain_add_expr("ZZ", "@@@", "1") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_exsqrt = try {
    domain_exsqrt_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_evalf = try {
    domain_evalf_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(malformed_predicate)
  assert_true(malformed_value)
  assert_true(malformed_exsqrt)
  assert_true(malformed_evalf)
  assert_true(domain_is_zero_expr("ZZ", "0"))
}

///|
test "polys domain element worker preserves direct predicate boundaries" {
  assert_true(domain_is_zero_expr("ZZ", "0"))
  assert_false(domain_is_zero_expr("ZZ", "1"))
  assert_true(domain_is_one_expr("QQ", "1"))
  assert_false(domain_is_one_expr("QQ", "0"))
  // Method lookup was strict in the legacy bridge, before the soft predicate
  // call boundary. SymPy 1.15 domains do not expose is_negative_one.
  let missing_method = try {
    domain_is_negative_one_expr("ZZ", "-1") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(missing_method)
  assert_true(domain_is_zero_expr("ZZ", "0"))
}

///|
test "polys domain element worker preserves compact tuple formats" {
  assert_eq(domain_half_gcdex_expr("QQ", "2/3", "4/9"), "(1/3,2/9)")
  assert_eq(domain_gcdex_expr("QQ", "2/3", "4/9"), "(1/3,0,2/9)")
  assert_eq(domain_cofactors_expr("ZZ", "6", "4"), "(2,3,2)")
  assert_eq(domain_div_expr("ZZ", "7", "3"), "(2,1)")
}

///|
test "polys domain element worker preserves exsqrt exact outcomes" {
  assert_eq(domain_exsqrt_expr("ZZ", "4"), "2")
  assert_eq(domain_exsqrt_expr("ZZ", "2"), "ERROR")
  assert_eq(domain_exsqrt_expr("QQ", "4/9"), "2/3")
}
