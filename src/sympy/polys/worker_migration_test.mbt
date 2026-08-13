///|
test "polys worker preserves literal Symbol punctuation" {
  let literal = @symcore.Expr::Symbol("x y,z")
  assert_eq(cancel(literal, @symcore.int(1)), "x y,z||1")
}

///|
test "polys worker shares Dummy identity within one public call" {
  let dummy = @symcore.Expr::Dummy("d", 1201)
  assert_eq(cancel(dummy, dummy), "1||1")
}

///|
test "polys worker reports a strict error then recovers" {
  let none_rejected = try {
    sympy_call_string("sympy.sympify", [Null]) |> ignore
    false
  } catch {
    _ => true
  }
  let rejected = try {
    sympy_call_string("sympy.__symbit_missing_callable__", []) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(none_rejected)
  assert_true(rejected)
  assert_eq(
    sympy_call_string("sympy.expand", [Str("(x + 1)**2")]),
    "x**2 + 2*x + 1",
  )
}

///|
test "polys worker preserves intentional None and polyconfig state" {
  ignore(polyconfig_configure())
  assert_eq(polyconfig_query("definitely_missing_key"), "None")
  ignore(polyconfig_setup_int("LOCAL_ONLY", 73))
  assert_eq(polyconfig_query("local_only"), "73")
  ignore(polyconfig_configure())
  // Upstream configure refreshes known defaults without clearing extension
  // keys; this also proves worker module state survives request boundaries.
  assert_eq(polyconfig_query("local_only"), "73")
}
