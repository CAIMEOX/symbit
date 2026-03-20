///|
fn medium_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = try! physics_eval_str(@symprint.to_string(lhs))
  assert_eq(ours, rhs)
}

///|
test "physics.optics.medium: parity" {
  let epsilon = @symcore.symbol("epsilon")
  let mu = @symcore.symbol("mu")
  let n = @symcore.symbol("n")

  let vacuum = medium("m1")
  medium_port_assert_expr_equal(
    vacuum.intrinsic_impedance(),
    optics_medium_property("intrinsic_impedance", "m1"),
    "vacuum impedance parity",
  )
  medium_port_assert_expr_equal(
    vacuum.speed(),
    optics_medium_property("speed", "m1"),
    "vacuum speed parity",
  )
  medium_port_assert_expr_equal(
    vacuum.refractive_index(),
    optics_medium_property("refractive_index", "m1"),
    "vacuum n parity",
  )

  let symbolic = medium("m2", permittivity=Some(epsilon), permeability=Some(mu))
  medium_port_assert_expr_equal(
    symbolic.intrinsic_impedance(),
    optics_medium_property(
      "intrinsic_impedance",
      "m2",
      permittivity=Some(epsilon),
      permeability=Some(mu),
    ),
    "symbolic impedance parity",
  )
  medium_port_assert_expr_equal(
    symbolic.speed(),
    optics_medium_property(
      "speed",
      "m2",
      permittivity=Some(epsilon),
      permeability=Some(mu),
    ),
    "symbolic speed parity",
  )

  let by_n = medium("m6", permeability=Some(mu), n=Some(n))
  medium_port_assert_expr_equal(
    by_n.permittivity(),
    optics_medium_property(
      "permittivity",
      "m6",
      permeability=Some(mu),
      n=Some(n),
    ),
    "derived permittivity parity",
  )
}
