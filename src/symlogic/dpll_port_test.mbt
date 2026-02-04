///|
test "dpll satisfiable parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let expr1 = bool_and([a, bool_not(a)])
  let ours1 = model_to_string(dpll_satisfiable(expr1))
  let oracle1 = normalize_model_string(
    try! @sympy_logic.dpll_satisfiable_str(to_string(expr1)),
  )
  assert_eq(ours1, oracle1)
  let expr2 = bool_and([a, bool_not(b)])
  let ours2 = model_to_string(dpll_satisfiable(expr2))
  let oracle2 = normalize_model_string(
    try! @sympy_logic.dpll_satisfiable_str(to_string(expr2)),
  )
  assert_eq(ours2, oracle2)
  let expr3 = bool_and([bool_equivalent([a, b]), a])
  let ours3 = model_to_string(dpll_satisfiable(expr3))
  let oracle3 = normalize_model_string(
    try! @sympy_logic.dpll_satisfiable_str(to_string(expr3)),
  )
  assert_eq(ours3, oracle3)
}

///|
test "dpll2 all models parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let expr = bool_equivalent([a, b])
  let ours = models_to_string(dpll2_all_models(expr))
  let oracle_raw = try! @sympy_logic.dpll2_all_models_str(to_string(expr))
  let oracle = normalize_models_string(oracle_raw)
  assert_eq(ours, oracle)
}
