///|
test "pythonrational frontdoors: sympify and wrap" {
  inspect(@symprint.pretty_string(sympify_pythonrational(3, 4)), content="3/4")
  let bad : Result[Expr, PolyError] = try? sympify_pythonrational(1, 0)
  assert_true(bad is Err(PolyError::DivisionByZero))
  inspect(wrap("a b c d e f", width=3), content="a b c\nd e f")
  inspect(wrap("abc def", width=80), content="abc def")
}
