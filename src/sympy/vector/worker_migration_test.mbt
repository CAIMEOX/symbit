///|
test "vector oracle forwards Unicode with request-local globals" {
  assert_eq(@vector.vector_eval_str("'向量' + '✓'"), "向量✓")
  assert_eq(
    @vector.vector_eval_str("globals().__setitem__('vector_leak', 1)"),
    "None",
  )
  assert_eq(@vector.vector_eval_str("'vector_leak' in globals()"), "False")
}
