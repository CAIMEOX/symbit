///|
test "stats oracle worker preserves its evaluation profile" {
  assert_eq(stats_eval_str("P(Die('D', 6) > 3)"), "1/2")
  assert_eq(stats_eval_str("E(Die('D', 6))"), "7/2")
  assert_eq(stats_eval_srepr("x + 1"), "Add(Integer(1), Symbol('x'))")
  assert_true(stats_expr_equiv("P(Die('D', 6) > 3)", "Rational(1, 2)"))
  assert_true(stats_srepr_eq("x + 1", "1 + x"))
}

///|
test "stats oracle worker returns None for errors and recovers" {
  assert_eq(stats_try_eval_str("this is not valid Python"), None)
  assert_eq(stats_try_eval_str("factor"), None)
  assert_eq(stats_try_eval_str("json"), None)
  assert_eq(stats_try_eval_str("_name"), None)
  assert_eq(stats_try_eval_str("__symbit_stats_equiv"), None)
  assert_eq(stats_try_eval_str("1 + 1"), Some("2"))
}
