///|
test "polys domain conversion worker rejects malformed sources and recovers" {
  let malformed_contains = try {
    domain_contains_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_from_sympy = try {
    domain_from_sympy_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_to_sympy = try {
    domain_to_sympy_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_convert = try {
    domain_convert_expr("ZZ", "@@@") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_hook = try {
    domain_from_zz_expr("QQ", "@@@", "ZZ") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(malformed_contains)
  assert_true(malformed_from_sympy)
  assert_true(malformed_to_sympy)
  assert_true(malformed_convert)
  assert_true(malformed_hook)
  assert_false(domain_contains_expr("IntegerRing", "1"))
  assert_eq(domain_from_sympy_expr("ZZ", "1/2"), "ERROR")
  assert_eq(domain_to_sympy_expr("ZZ", "1/2"), "ERROR")
  assert_eq(domain_convert_expr("ZZ", "1/2"), "ERROR")
  assert_eq(domain_convert_from_expr("QQ", "1/2", "ZZ"), "ERROR")
  assert_eq(domain_sum_expr("ZZ", ["1", "1/2"]), "ERROR")
  assert_eq(domain_from_zz_expr("QQ", "1/2", "ZZ"), "ERROR")
  assert_true(domain_contains_expr("QQ(1/x,y)", "x + y"))
  assert_eq(domain_from_sympy_expr("ZZ", "7"), "7")
}

///|
test "polys domain conversion worker preserves optional hook tri-state" {
  assert_eq(domain_from_fraction_field_expr("QQ", "2", "QQ(x)"), "NONE")
  assert_eq(
    domain_from_monogenic_finite_extension_expr("QQ", "2", "QQ<sqrt(2)>"),
    "NONE",
  )
  assert_eq(domain_from_zz_expr("QQ", "2", "ZZ"), "2")
}
