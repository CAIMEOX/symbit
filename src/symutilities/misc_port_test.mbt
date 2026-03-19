///|
test "misc filldedent parity" {
  let text = "\n    this is a test paragraph that should wrap\n    cleanly\n"
  let ours = filldedent(text, w=24)
  let oracle = @sympy_utilities.utilities_eval_str(
    "sympy.utilities.misc.filldedent('\\n    this is a test paragraph that should wrap\\n    cleanly\\n', w=24)",
  )
  assert_eq(ours, oracle)
}

///|
test "misc replace translate ordinal parity" {
  let ours_replace = replace("abc", [("a", "b"), ("c", "C")])
  let oracle_replace = @sympy_utilities.utilities_eval_str(
    "sympy.utilities.misc.replace('abc', ('a', 'b'), ('c', 'C'))",
  )
  assert_eq(ours_replace, oracle_replace)

  let ours_translate = translate(
    "abc",
    multimap=[("ab", "x")],
    deletechars=Some("c"),
  )
  let oracle_translate = @sympy_utilities.utilities_eval_str(
    "sympy.utilities.misc.translate('abc', {'ab': 'x'}, 'c')",
  )
  assert_eq(ours_translate, oracle_translate)

  assert_eq(
    ordinal(103),
    @sympy_utilities.utilities_eval_str("sympy.utilities.misc.ordinal(103)"),
  )
}
