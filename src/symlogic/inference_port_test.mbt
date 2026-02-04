///|
test "inference literal_symbol parity" {
  let a = bool_symbol("A")
  let expr = bool_not(a)
  let ours = to_string(literal_symbol(expr))
  let oracle = try! @sympy_logic.inference_literal_symbol("~A")
  assert_eq(ours, oracle)
}

///|
test "inference satisfiable parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let expr = bool_and([a, bool_not(b)])
  let ours = satresult_to_string(satisfiable(expr, algorithm="dpll2"))
  let oracle = normalize_model_string(
    try! @sympy_logic.inference_satisfiable_str(
      to_string(expr),
      algorithm="dpll2",
    ),
  )
  assert_eq(ours, oracle)
}

///|
test "inference satisfiable all_models parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let expr = bool_equivalent([a, b])
  let ours = satresult_to_string(
    satisfiable(expr, algorithm="dpll2", all_models=true),
  )
  let oracle_raw = try! @sympy_logic.inference_satisfiable_str(
    to_string(expr),
    algorithm="dpll2",
    all_models=true,
  )
  let oracle = normalize_models_string(oracle_raw)
  assert_eq(ours, oracle)
}

///|
test "inference valid/entails parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let expr_valid = bool_implies(a, bool_implies(b, a))
  let expr_entails = bool_implies(a, b)
  let ours_valid = if valid(expr_valid) { "True" } else { "False" }
  let oracle_valid = try! @sympy_logic.inference_valid(to_string(expr_valid))
  assert_eq(ours_valid, oracle_valid)
  let ours_entails = if entails(expr_entails, formula_set=[expr_entails]) {
    "True"
  } else {
    "False"
  }
  let oracle_entails = try! @sympy_logic.inference_entails(
    to_string(expr_entails),
    [to_string(expr_entails)],
  )
  assert_eq(ours_entails, oracle_entails)
}

///|
test "inference pl_true parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let expr = bool_and([a, b])
  let model : Map[String, Bool?] = { "A": Some(true), "B": Some(false) }
  let ours = bool_option_to_string(pl_true(expr, model~))
  let oracle = try! @sympy_logic.inference_pl_true(
    to_string(expr),
    ["A", "B"],
    [true, false],
  )
  assert_eq(ours, oracle)
}

///|
test "inference PropKB ask parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let c = bool_symbol("C")
  let kb = PropKB::new()
  kb.tell(bool_implies(a, b))
  kb.tell(bool_implies(b, c))
  let ours_ask = if kb.ask(bool_implies(a, c)) { "True" } else { "False" }
  let oracle_res : Result[String, Error] = try? @sympy_logic.propkb_ask_str(
    ["A >> B", "B >> C"],
    "A >> C",
  )
  match oracle_res {
    Ok(oracle_ask) => assert_eq(ours_ask, oracle_ask)
    Err(err) => fail(err.to_string())
  }
}

///|
test "inference PropKB clauses parity" {
  let a = bool_symbol("A")
  let b = bool_symbol("B")
  let c = bool_symbol("C")
  let kb = PropKB::new()
  kb.tell(bool_implies(a, b))
  kb.tell(bool_implies(b, c))
  let ours_clauses = clauses_to_string(kb.clauses())
  let oracle_clauses = try! @sympy_logic.propkb_clauses_str(["A >> B", "B >> C"])
  assert_eq(ours_clauses, oracle_clauses)
}
