///|
fn medium_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = try! @sympy_physics.physics_eval_str(@symprint.to_string(lhs))
  guard ours == rhs else {
    fail("\{context}: ours=\{ours}; oracle=\{rhs}")
  }
}

///|
test "physics.optics.medium: parity" {
  let epsilon = @symcore.symbol("epsilon")
  let mu = @symcore.symbol("mu")
  let n = @symcore.symbol("n")

  let vacuum = try! medium("m1")
  try! medium_port_assert_expr_equal(
    try! vacuum.intrinsic_impedance(),
    try! @sympy_physics.optics_medium_property("intrinsic_impedance", "m1"),
    "vacuum impedance parity",
  )
  try! medium_port_assert_expr_equal(
    vacuum.speed(),
    try! @sympy_physics.optics_medium_property("speed", "m1"),
    "vacuum speed parity",
  )
  try! medium_port_assert_expr_equal(
    vacuum.refractive_index(),
    try! @sympy_physics.optics_medium_property("refractive_index", "m1"),
    "vacuum n parity",
  )

  let symbolic = try! medium("m2", permittivity=Some(epsilon), permeability=Some(mu))
  try! medium_port_assert_expr_equal(
    try! symbolic.intrinsic_impedance(),
    try! @sympy_physics.optics_medium_property(
      "intrinsic_impedance",
      "m2",
      permittivity=Some(epsilon),
      permeability=Some(mu),
    ),
    "symbolic impedance parity",
  )
  try! medium_port_assert_expr_equal(
    symbolic.speed(),
    try! @sympy_physics.optics_medium_property(
      "speed",
      "m2",
      permittivity=Some(epsilon),
      permeability=Some(mu),
    ),
    "symbolic speed parity",
  )

  let by_n = try! medium("m6", permeability=Some(mu), n=Some(n))
  try! medium_port_assert_expr_equal(
    try! by_n.permittivity(),
    try! @sympy_physics.optics_medium_property(
      "permittivity",
      "m6",
      permeability=Some(mu),
      n=Some(n),
    ),
    "derived permittivity parity",
  )
}
