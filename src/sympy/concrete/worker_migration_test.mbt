///|
test "concrete oracle worker preserves string and equivalence semantics" {
  assert_eq(@concrete.sympy_str("x + x"), "2*x")
  assert_eq(@concrete.sympy_srepr("x + 1"), "Add(Integer(1), Symbol('x'))")
  assert_true(@concrete.expr_str_eq("x + 1", "1 + x"))
  assert_false(@concrete.expr_str_eq("Dummy('x')", "Dummy('x')"))
  assert_true(@concrete.sympy_equiv_str("(x + 1)**2", "x**2 + 2*x + 1"))
  assert_false(@concrete.sympy_equiv_str("x + 1", "x + 2"))
}

///|
test "concrete oracle worker rejects Python None and recovers" {
  let rejected = try {
    @concrete.sympy_str("None") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(@concrete.sympy_str("1 + 1"), "2")
}
