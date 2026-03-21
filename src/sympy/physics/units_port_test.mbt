///|
fn units_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  assert_true(expr_equal(ours, rhs))
}

///|
test "physics.units: prefix parity" {
  assert_eq(
    prefix_value_to_string(milli.mul_prefix(kilo)),
    physics_eval_str("milli*kilo"),
  )
  assert_eq(
    prefix_value_to_string(kilo.mul_prefix(kilo)),
    physics_eval_str("kilo*kilo"),
  )
  assert_eq(
    prefix_value_to_string(milli.rdiv_one()),
    physics_eval_str("1/milli"),
  )
  assert_eq(
    prefix_value_to_string(kilo.div_prefix(milli)),
    physics_eval_str("kilo/milli"),
  )
  units_port_assert_expr_equal(
    milli.mul_quantity(watt),
    physics_eval_str("milli*watt"),
    "milli*watt parity",
  )
}
