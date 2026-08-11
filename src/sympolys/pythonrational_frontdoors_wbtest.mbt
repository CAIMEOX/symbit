///|
test "pythonrational frontdoors: sympify and wrap" {
  inspect(@symprint.pretty_string(sympify_pythonrational(3, 4)), content="3/4")
  sympolys_assert_error(
    fn() raise PolyError { sympify_pythonrational(1, 0) },
    "DivisionByZero",
  )
  inspect(wrap("a b c d e f", width=3), content="a b c\nd e f")
  inspect(wrap("abc def", width=80), content="abc def")
}
