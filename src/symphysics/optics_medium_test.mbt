///|
fn medium_assert_expr_equal(
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
test "physics.optics.medium: vacuum and symbolic media" {
  let vacuum = try! medium("m1")
  try! medium_assert_expr_equal(
    try! vacuum.intrinsic_impedance(),
    "149896229*pi*kilogram*meter**2/(1250000*ampere**2*second**3)",
    "vacuum impedance",
  )
  try! medium_assert_expr_equal(vacuum.speed(), "299792458*meter/second", "vacuum speed")
  try! medium_assert_expr_equal(vacuum.refractive_index(), "1", "vacuum n")

  let epsilon = @symcore.symbol("epsilon")
  let mu = @symcore.symbol("mu")
  let symbolic = try! medium("m2", permittivity=Some(epsilon), permeability=Some(mu))
  try! medium_assert_expr_equal(
    try! symbolic.intrinsic_impedance(),
    "sqrt(mu/epsilon)",
    "symbolic impedance",
  )
  try! medium_assert_expr_equal(symbolic.speed(), "1/sqrt(epsilon*mu)", "symbolic speed")
  try! medium_assert_expr_equal(
    symbolic.refractive_index(),
    "299792458*meter*sqrt(epsilon*mu)/second",
    "symbolic n",
  )
}

///|
test "physics.optics.medium: derived parameterizations and guards" {
  let mu = @symcore.symbol("mu")
  let n = @symcore.symbol("n")

  let by_n = try! medium("m6", permeability=Some(mu), n=Some(n))
  try! medium_assert_expr_equal(
    try! by_n.permittivity(),
    "n**2/(299792458**2*meter**2*mu/second**2)",
    "derived permittivity",
  )

  let err : Result[Medium, PhysicsError] = try? medium("m9", permittivity=Some(e0), permeability=Some(u0), n=Some(@symcore.int(2)))
  guard err is Err(_) else {
    fail("expected over-specified Medium to fail")
  }
}
