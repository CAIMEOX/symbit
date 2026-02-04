///|
test "ntheory oracle smoke" {
  assert_eq(@sympy_nt.isprime_str(13), "True")
  assert_eq(@sympy_nt.isprime_str(21), "False")
  assert_eq(@sympy_nt.prime_str(6), "13")
}
