///|
test "unify worker executes scripts with Unicode results" {
  assert_eq(
    @runtime.eval_str("unify.exec_result_str", "__result__ = '符号😀'"),
    "符号😀",
  )
}

///|
test "unify worker isolates script globals between requests" {
  assert_eq(
    @runtime.eval_str(
      "unify.exec_result_str", "leaked = 1\n__result__ = 'created'",
    ),
    "created",
  )
  assert_eq(
    @runtime.eval_str(
      "unify.exec_result_str", "__result__ = 'leaked' in globals()",
    ),
    "False",
  )
}
