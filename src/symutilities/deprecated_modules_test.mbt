///|
test "deprecated utility submodule warnings are wired" {
  assert_true(pytest_deprecation_warning().message.contains("sympy.utilities.pytest"))
  assert_true(randtest_deprecation_warning().message.contains("sympy.utilities.randtest"))
  assert_true(runtests_deprecation_warning().message.contains("sympy.utilities.runtests"))
  assert_true(tmpfiles_deprecation_warning().message.contains("sympy.utilities.tmpfiles"))
}

///|
test "pkgdata resource path adaptation is stable" {
  assert_eq(get_resource("data/demo.txt", "/tmp/pkg"), "/tmp/pkg/data/demo.txt")
  assert_true(pkgdata_deprecation_warning().message.contains("sympy.utilities.pkgdata"))
}
