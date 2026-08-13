///|
test "parsing worker quotes multiline parser input as data" {
  let source = "x + \\" + "\n" + "1"
  assert_eq(parse_expr_sstr(source), "x + 1")
}

///|
test "parsing worker keeps eval scope narrow and recovers from errors" {
  let unqualified_rejected = try {
    parsing_eval_str("sqrt(4)") |> ignore
    false
  } catch {
    _ => true
  }
  let malformed_rejected = try {
    parsing_eval_str("(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(unqualified_rejected)
  assert_true(malformed_rejected)
  assert_eq(parsing_eval_str("sympy.sqrt(4)"), "2")
}
