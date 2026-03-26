///|
fn medium_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  assert_true(expr_equal(ours, rhs))
}

///|
test "physics.optics.medium: vacuum and symbolic media" {
  let vacuum = medium("m1")
  medium_assert_expr_equal(
    vacuum.intrinsic_impedance(),
    "149896229*pi*kilogram*meter**2/(1250000*ampere**2*second**3)",
    "vacuum impedance",
  )
  medium_assert_expr_equal(
    vacuum.speed(),
    "299792458*meter/second",
    "vacuum speed",
  )
  medium_assert_expr_equal(vacuum.refractive_index(), "1", "vacuum n")

  let epsilon = @symcore.Expr::Symbol("epsilon")
  let mu = @symcore.Expr::Symbol("mu")
  let symbolic = medium("m2", permittivity=Some(epsilon), permeability=Some(mu))
  medium_assert_expr_equal(
    symbolic.intrinsic_impedance(),
    "sqrt(mu/epsilon)",
    "symbolic impedance",
  )
  medium_assert_expr_equal(
    symbolic.speed(),
    "1/sqrt(epsilon*mu)",
    "symbolic speed",
  )
  medium_assert_expr_equal(
    symbolic.refractive_index(),
    "299792458*meter*sqrt(epsilon*mu)/second",
    "symbolic n",
  )
}

///|
test "physics.optics.medium: derived parameterizations and guards" {
  let mu = @symcore.Expr::Symbol("mu")
  let n = @symcore.Expr::Symbol("n")

  let by_n = medium("m6", permeability=Some(mu), n=Some(n))
  medium_assert_expr_equal(
    by_n.permittivity(),
    "n**2/(299792458**2*meter**2*mu/second**2)",
    "derived permittivity",
  )

  let err : Result[Medium, PhysicsError] = try? medium(
    "m9",
    permittivity=Some(e0),
    permeability=Some(u0),
    n=Some(@symcore.int(2)),
  )
  assert_true(err is Err(_))
}
