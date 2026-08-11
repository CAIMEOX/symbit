///|
test "integrals oracle preserves Unicode source and result" {
  assert_eq(@integrals.integrals_eval_str("'符号😀'"), "符号😀")
}

///|
test "integrals oracle keeps its SymPy helper profile alive" {
  assert_eq(
    @integrals.integrals_eval_str(
      "__symbit_symbol('x') is __symbit_symbol('x')",
    ),
    "True",
  )
  assert_eq(
    @integrals.integrals_eval_str(
      "(__symbit_symbol('x'), " +
      "isinstance(__symbit_symbol_cache, dict) and " +
      "'x' in __symbit_symbol_cache)[1]",
    ),
    "True",
  )
  assert_eq(
    @integrals.integrals_eval_str("sympy.sstr(__symbit_locals['sqrt'](4))"),
    "2",
  )
  assert_eq(@integrals.integrals_eval_str("None"), "None")
}

///|
test "integrals oracle exposes Python failures and remains usable" {
  let seen = try {
    @integrals.integrals_eval_str("1 / 0") |> ignore
    "missing-error"
  } catch {
    err => Show::to_string(err)
  }
  assert_true(seen.contains("PythonException"))
  assert_true(seen.contains("ZeroDivisionError"))
  assert_eq(@integrals.integrals_eval_str("40 + 2"), "42")
}
