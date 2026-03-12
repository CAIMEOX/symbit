///|
fn optics_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let lhs_txt = try! @sympy_physics.physics_expr_str(lhs)
  guard (try! @sympy_physics.control_expr_equivalent(lhs, rhs)) else {
    fail("\{context}: ours=\{lhs_txt}; expected=\{rhs}")
  }
}

///|
fn optics_assert_expr_list_equal(
  lhs : Array[@symcore.Expr],
  rhs : Array[String],
  context : String,
) -> Unit raise {
  guard lhs.length() == rhs.length() else {
    fail(
      "\{context}: length mismatch ours=\{lhs.length()} expected=\{rhs.length()}",
    )
  }
  for idx in 0..<lhs.length() {
    try! optics_assert_expr_equal(lhs[idx], rhs[idx], "\{context}[\{idx}]")
  }
}

///|
fn test_rational_expr(num : Int, den : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn test_pi_expr() -> @symcore.Expr {
  @symcore.symbol("pi")
}

///|
fn test_oo_expr() -> @symcore.Expr {
  @symcore.symbol("oo")
}

///|
test "physics.optics.utils: scalar formulas" {
  let one = @symcore.int(1)
  let four_thirds = test_rational_expr(4, 3)
  let six_fifths = test_rational_expr(6, 5)
  let three_halves = test_rational_expr(3, 2)
  let theta = test_pi_expr() * test_rational_expr(1, 6)
  let f = @symcore.symbol("f")
  let u = @symcore.symbol("u")
  let v = @symcore.symbol("v")
  let n = @symcore.symbol("N")
  let c = @symcore.symbol("c")

  try! optics_assert_expr_equal(
    refraction_angle(
      theta,
      optics_index_arg(six_fifths),
      optics_index_arg(three_halves),
    ),
    "asin(2/5)",
    "refraction_angle",
  )
  guard fresnel_coefficients(
      theta,
      optics_index_arg(one),
      optics_index_arg(four_thirds),
    ).length() ==
    4 else {
    fail("fresnel_coefficients length")
  }
  try! optics_assert_expr_equal(
    deviation(
      theta,
      optics_index_arg(six_fifths),
      optics_index_arg(three_halves),
    ),
    "asin(2/5) - pi/6",
    "deviation",
  )
  try! optics_assert_expr_equal(
    brewster_angle(optics_index_arg(one), optics_index_arg(four_thirds)),
    "atan(4/3)",
    "brewster_angle",
  )
  try! optics_assert_expr_equal(
    try! critical_angle(optics_index_arg(four_thirds), optics_index_arg(one)),
    "asin(3/4)",
    "critical_angle",
  )
  try! optics_assert_expr_equal(
    lens_makers_formula(
      optics_index_arg(four_thirds),
      optics_index_arg(one),
      @symcore.int(10),
      @symcore.int(-10),
    ),
    "15",
    "lens_makers_formula thin",
  )
  try! optics_assert_expr_equal(
    lens_makers_formula(
      optics_index_arg(four_thirds),
      optics_index_arg(one),
      @symcore.int(10),
      test_oo_expr(),
    ),
    "30",
    "lens_makers_formula plano",
  )
  try! optics_assert_expr_equal(
    try! mirror_formula(focal_length=Some(f), u=Some(u)),
    "f*u/(-f + u)",
    "mirror_formula",
  )
  try! optics_assert_expr_equal(
    try! lens_formula(focal_length=Some(f), u=Some(u)),
    "f*u/(f + u)",
    "lens_formula",
  )
  try! optics_assert_expr_equal(
    hyperfocal_distance(f, n, c),
    "f**2/(N*c)",
    "hyperfocal_distance",
  )
  try! optics_assert_expr_equal(
    transverse_magnification(@symcore.int(30), @symcore.int(15)),
    "-2",
    "transverse_magnification",
  )
  try! optics_assert_expr_equal(
    try! mirror_formula(u=Some(test_oo_expr()), v=Some(v)),
    "v",
    "mirror_formula oo",
  )
  try! optics_assert_expr_equal(
    try! lens_formula(focal_length=Some(test_oo_expr()), v=Some(v)),
    "v",
    "lens_formula oo",
  )
}
