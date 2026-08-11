///|
test "core worker preserves literal names and shared Dummy identity" {
  assert_eq(core_expr_srepr(Symbol("x y,z")), "Symbol('x y,z')")
  let dummy = @symcore.Expr::Dummy("d", 801)
  let expression = @symcore.add([dummy, @symcore.int(1)])
  assert_true(core_has_bool(expression, dummy))
}

///|
test "core worker contains source and attribute errors then recovers" {
  let source_rejected = try {
    core_parameters_sstr("(") |> ignore
    false
  } catch {
    _ => true
  }
  let attribute_rejected = try {
    core_attr_bool(@symcore.int(1), "__symbit_missing_attribute__") |> ignore
    false
  } catch {
    _ => true
  }
  let unqualified_sympy_name_rejected = try {
    core_parameters_sstr("sqrt(4)") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(source_rejected)
  assert_true(attribute_rejected)
  assert_true(unqualified_sympy_name_rejected)
  assert_eq(core_parameters_sstr("sympy.sqrt(4)"), "2")
  assert_eq(core_expr_sstr(@symcore.int(2)), "2")
}
