///|
fn units_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  guard (try! @sympy_physics.expr_equal(ours, rhs)) else {
    fail("\{context}: ours=\{ours}; oracle=\{rhs}")
  }
}

///|
test "physics.units: prefix parity" {
  guard prefix_value_to_string(milli.mul_prefix(kilo)) ==
    @sympy_physics.physics_eval_str("milli*kilo") else {
    fail("milli*kilo parity")
  }
  guard prefix_value_to_string(kilo.mul_prefix(kilo)) ==
    @sympy_physics.physics_eval_str("kilo*kilo") else {
    fail("kilo*kilo parity")
  }
  guard prefix_value_to_string(milli.rdiv_one()) ==
    @sympy_physics.physics_eval_str("1/milli") else {
    fail("1/milli parity")
  }
  guard prefix_value_to_string(kilo.div_prefix(milli)) ==
    @sympy_physics.physics_eval_str("kilo/milli") else {
    fail("kilo/milli parity")
  }
  units_port_assert_expr_equal(
    milli.mul_quantity(watt),
    @sympy_physics.physics_eval_str("milli*watt"),
    "milli*watt parity",
  )
}
