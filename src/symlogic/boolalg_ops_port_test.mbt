///|
test "boolalg xnor/exclusive and complement simplification" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")
  let xnor_expr = bool_xnor([x, y])
  assert_eq(
    to_string(xnor_expr),
    try! @sympy_logic.boolalg_str("Not(Xor(x, y))"),
  )
  let excl_expr = bool_exclusive([x, y, z])
  assert_eq(
    to_string(excl_expr),
    try! @sympy_logic.boolalg_str("~(x & y) & ~(x & z) & ~(y & z)"),
  )
  let and_expr = bool_and([x, bool_not(x)])
  assert_eq(to_string(and_expr), try! @sympy_logic.boolalg_str("x & ~x"))
  let or_expr = bool_or([x, bool_not(x)])
  assert_eq(to_string(or_expr), try! @sympy_logic.boolalg_str("x | ~x"))
}
