///|
test "ntheory worker migration covers scalars kwargs and list arguments" {
  assert_eq(isprime_str(97), "True")
  assert_eq(symmetric_residue_str(6, 11), "-5")
  assert_eq(divisor_sigma_str(12, k=2), "210")
  assert_eq(
    crt_str([3, 5, 7], [2, 3, 2], symmetric=true, check=false),
    "(23, 105)",
  )
  assert_eq(polynomial_congruence_str([1, 0, -1], 11), "[1, 10]")
}

///|
test "ntheory worker migration preserves Python None" {
  assert_eq(crt_str([2, 4], [1, 0]), "None")
  assert_eq(perfect_power_str(12), "False")
  assert_eq(sqrt_mod_str(3, 7), "None")
}

///|
test "ntheory worker recovers after a Python exception" {
  let failed : Result[String, Error] = try prime_str(0) |> Ok catch {
    error => Err(error)
  }
  let opt_failed : Result[String, Error] = try sqrt_mod_str(1, 0) |> Ok catch {
    error => Err(error)
  }
  assert_true(failed is Err(_))
  assert_true(opt_failed is Err(_))
  assert_eq(prime_str(6), "13")
  assert_eq(sqrt_mod_str(3, 7), "None")
}
