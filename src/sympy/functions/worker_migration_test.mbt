///|
test "functions oracle worker preserves string and equality semantics" {
  assert_eq(sympy_str("x + x"), "2*x")
  assert_eq(sympy_srepr("x + 1"), "Add(Integer(1), Symbol('x'))")
  assert_true(expr_str_eq("x + 1", "1 + x"))
  assert_false(expr_str_eq("Dummy('x')", "Dummy('x')"))
}

///|
test "functions oracle worker rejects Python None and recovers" {
  let rejected = try {
    sympy_str("None") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(sympy_str("1 + 1"), "2")
}
