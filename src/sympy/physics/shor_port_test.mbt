///|
test "physics.quantum.shor: helper parity" {
  quantum_test_assert_string_equal(
    ratioize([1, 2, 3], 15).to_string(),
    quantum_shor_ratioize([1, 2, 3], 15),
    "ratioize parity",
  )
  quantum_test_assert_string_equal(
    getr(1, 4, 15).to_string(),
    quantum_shor_getr(1, 4, 15),
    "getr quarter parity",
  )
  quantum_test_assert_string_equal(
    getr(3, 8, 15).to_string(),
    quantum_shor_getr(3, 8, 15),
    "getr three eighths parity",
  )
}
