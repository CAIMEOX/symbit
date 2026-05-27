///|
test "singleton helpers expose SymPy-style singleton names and S shortcut" {
  assert_true(singleton_instance_name(int(0)) == Some("Zero"))
  assert_true(
    singleton_instance_name(Expr::NumberSymbol(NumberSymbolKind::Pi)) ==
    Some("Pi"),
  )
  assert_true(singleton_instance_name(Expr::Boolean(true)) == Some("true"))
  inspect(
    @symprint.pretty_string(singleton_expr_by_name("Half").unwrap_or(int(0))),
    content="1/2",
  )
  assert_true(is_singleton_expr(Expr::NumberSymbol(NumberSymbolKind::Infinity)))
  inspect(@symprint.pretty_string(s(SympifyInput::FromInt(5))), content="5")
}
