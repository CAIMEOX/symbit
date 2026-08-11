///|
test "singleton helpers expose SymPy-style singleton names and S shortcut" {
  assert_true(singleton_instance_name(int(0)) == Some("Zero"))
  assert_true(singleton_instance_name(NumberSymbol(Pi)) == Some("Pi"))
  assert_true(singleton_instance_name(Boolean(true)) == Some("true"))
  inspect(
    @symprint.pretty_string(singleton_expr_by_name("Half").unwrap_or(int(0))),
    content="1/2",
  )
  assert_true(is_singleton_expr(NumberSymbol(Infinity)))
  inspect(@symprint.pretty_string(s(FromInt(5))), content="5")
}
