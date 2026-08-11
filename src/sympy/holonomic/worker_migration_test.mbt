///|
test "holonomic worker covers recurrence differential and equivalence profiles" {
  assert_true(recurrence_str(["1", "n"]).length() > 0)
  assert_true(recurrence_mul_srepr(["n + 1 # q'quoted"], ["1"]).length() > 0)
  assert_true(differential_str(["1", "x"]).length() > 0)
  assert_true(differential_srepr(["1", "x"]).length() > 0)
  assert_true(
    differential_mul_srepr(["x + Symbol(\"q'quoted\") * 0"], ["1"]).length() > 0,
  )
  assert_true(sympy_equiv_str("x + 1", "1 + x"))
}

///|
test "holonomic worker preserves both initial-value branches" {
  assert_true(holonomic_str(["1", "x"]).length() > 0)
  assert_true(holonomic_str(["1", "x"], x0="0", y0=["1"]).length() > 0)
}

///|
test "holonomic worker rejects invalid source and recovers" {
  let rejected = try {
    differential_expr_srepr("(") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(expr_to_holonomic_str("exp(x)").length() > 0)
}
