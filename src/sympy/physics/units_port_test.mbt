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
    milli.mul_prefix(kilo).to_string(),
    physics_eval_str("milli*kilo"),
  )
  assert_eq(
    kilo.mul_prefix(kilo).to_string(),
    physics_eval_str("kilo*kilo"),
  )
  assert_eq(
    milli.rdiv_one().to_string(),
    physics_eval_str("1/milli"),
  )
  assert_eq(
    kilo.div_prefix(milli).to_string(),
    physics_eval_str("kilo/milli"),
  )
  units_port_assert_expr_equal(
    milli.mul_quantity(watt),
    physics_eval_str("milli*watt"),
    "milli*watt parity",
  )
}
