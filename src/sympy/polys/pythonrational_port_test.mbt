///|
test "pythonrational: scalar helper parity" {
  assert_eq(
    @symprint.pretty_string(@sympolys.sympify_pythonrational(3, 4)),
    sympify_pythonrational(3, 4),
  )
  assert_eq(
    @sympolys.wrap("a b c d e f", width=3),
    wrap("a b c d e f", width=3),
  )
  assert_eq(@sympolys.wrap("abc def"), wrap("abc def"))
}
