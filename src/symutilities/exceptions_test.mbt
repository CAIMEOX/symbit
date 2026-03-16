///|
test "exceptions full message formatting" {
  let warning = try! sympy_deprecation_warning(
    "feature is deprecated", "1.10", "active-deprecations",
  )
  assert_true(warning.full_message().contains("feature is deprecated"))
  assert_true(warning.full_message().contains("active-deprecations"))
  assert_true(warning.full_message().contains("1.10"))
}

///|
test "exceptions reject malformed target" {
  guard (try? sympy_deprecation_warning("x", "1.0", "(bad)=target")) is Err(_) else {
    fail("expected malformed deprecation target to be rejected")
  }
}
