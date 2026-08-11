///|
test "logic worker covers boolean inference and DIMACS profiles" {
  assert_eq(boolalg_to_cnf("Implies(x, y)"), "y | ~x")
  assert_eq(dpll2_all_models_str("x & ~x"), "[False]")
  assert_eq(inference_valid("Implies(x, x)"), "True")
  assert_true(dimacs_load_str("1 -2").length() > 0)
}

///|
test "logic worker treats quoted expressions as data and recovers from errors" {
  assert_eq(boolalg_str("Symbol(\"x'quoted\")"), "x'quoted")
  assert_eq(propkb_clauses_str(["Symbol(\"q'quoted\")"]), "[q'quoted]")
  assert_eq(propkb_retract_clauses_str(["A & B", "C"], "B"), "[A, C]")
  let rejected = try {
    boolalg_str("(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let propkb_rejected = try {
    propkb_clauses_str(["("]) |> ignore
    false
  } catch {
    _ => true
  }
  let none_rejected = try {
    inference_pl_true("A & B", ["A"], [true]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(propkb_rejected)
  assert_true(none_rejected)
  assert_eq(boolalg_str("x & True"), "x")
  assert_eq(propkb_clauses_str(["A & B"]), "[A, B]")
}
