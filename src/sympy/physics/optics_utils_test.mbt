///|
fn optics_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  assert_true((try! control_expr_equivalent(lhs, rhs)))
}

///|
fn optics_assert_expr_list_equal(
  lhs : Array[@symcore.Expr],
  rhs : Array[String],
  context : String,
) -> Unit raise {
  assert_eq(lhs.length(), rhs.length())
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

  optics_assert_expr_equal(
    refraction_angle(
      theta,
      optics_index_arg(six_fifths),
      optics_index_arg(three_halves),
    ),
    "asin(2/5)",
    "refraction_angle",
  )
  assert_eq(fresnel_coefficients(
          theta,
          optics_index_arg(one),
          optics_index_arg(four_thirds),
        ).length(), 4)
  optics_assert_expr_equal(
    deviation(
      theta,
      optics_index_arg(six_fifths),
      optics_index_arg(three_halves),
    ),
    "asin(2/5) - pi/6",
    "deviation",
  )
  assert_eq(fresnel_coefficients(
          test_pi_expr() * test_rational_expr(3, 10),
          optics_index_arg(@symcore.int(2)),
          optics_index_arg(@symcore.int(1)),
        ).length(), 2)
  optics_assert_expr_equal(
    brewster_angle(optics_index_arg(one), optics_index_arg(four_thirds)),
    "atan(4/3)",
    "brewster_angle",
  )
  optics_assert_expr_equal(
    critical_angle(optics_index_arg(four_thirds), optics_index_arg(one)),
    "asin(3/4)",
    "critical_angle",
  )
  optics_assert_expr_equal(
    lens_makers_formula(
      optics_index_arg(four_thirds),
      optics_index_arg(one),
      @symcore.int(10),
      @symcore.int(-10),
    ),
    "15",
    "lens_makers_formula thin",
  )
  optics_assert_expr_equal(
    lens_makers_formula(
      optics_index_arg(four_thirds),
      optics_index_arg(one),
      @symcore.int(10),
      test_oo_expr(),
    ),
    "30",
    "lens_makers_formula plano",
  )
  optics_assert_expr_equal(
    mirror_formula(focal_length=Some(f), u=Some(u)),
    "f*u/(-f + u)",
    "mirror_formula",
  )
  optics_assert_expr_equal(
    lens_formula(focal_length=Some(f), u=Some(u)),
    "f*u/(f + u)",
    "lens_formula",
  )
  optics_assert_expr_equal(
    hyperfocal_distance(f, n, c),
    "f**2/(N*c)",
    "hyperfocal_distance",
  )
  optics_assert_expr_equal(
    transverse_magnification(@symcore.int(30), @symcore.int(15)),
    "-2",
    "transverse_magnification",
  )
  optics_assert_expr_equal(
    mirror_formula(u=Some(test_oo_expr()), v=Some(v)),
    "v",
    "mirror_formula oo",
  )
  optics_assert_expr_equal(
    lens_formula(focal_length=Some(test_oo_expr()), v=Some(v)),
    "v",
    "lens_formula oo",
  )
}
