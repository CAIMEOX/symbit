///|
fn units_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  assert_true((try! @sympy_physics.expr_equal(ours, rhs)))
}

///|
test "physics.units: prefix parity" {
  assert_eq(prefix_value_to_string(milli.mul_prefix(kilo)), @sympy_physics.physics_eval_str("milli*kilo"))
  assert_eq(prefix_value_to_string(kilo.mul_prefix(kilo)), @sympy_physics.physics_eval_str("kilo*kilo"))
  assert_eq(prefix_value_to_string(milli.rdiv_one()), @sympy_physics.physics_eval_str("1/milli"))
  assert_eq(prefix_value_to_string(kilo.div_prefix(milli)), @sympy_physics.physics_eval_str("kilo/milli"))
  units_port_assert_expr_equal(
    milli.mul_quantity(watt),
    @sympy_physics.physics_eval_str("milli*watt"),
    "milli*watt parity",
  )
}
