///|
test "physics.optics.utils: parity" {
  let one = @symcore.int(1)
  let four_thirds = test_rational_expr(4, 3)
  let six_fifths = test_rational_expr(6, 5)
  let three_halves = test_rational_expr(3, 2)
  let theta = test_pi_expr() * test_rational_expr(1, 6)
  let small_angle = test_rational_expr(1, 10)
  let f = @symcore.symbol("f")
  let u = @symcore.symbol("u")
  let n = @symcore.symbol("N")
  let c = @symcore.symbol("c")

  optics_assert_expr_equal(
    refraction_angle(
      theta,
      optics_index_arg(six_fifths),
      optics_index_arg(three_halves),
    ),
    @sympy_physics.optics_utils_eval("refraction_angle(pi/6, 6/5, 3/2)"),
    "refraction_angle parity",
  )
  optics_assert_expr_list_equal(
    fresnel_coefficients(
      theta,
      optics_index_arg(one),
      optics_index_arg(four_thirds),
    ),
    [
      @sympy_physics.optics_utils_eval("fresnel_coefficients(pi/6, 1, 4/3)[0]"),
      @sympy_physics.optics_utils_eval("fresnel_coefficients(pi/6, 1, 4/3)[1]"),
      @sympy_physics.optics_utils_eval("fresnel_coefficients(pi/6, 1, 4/3)[2]"),
      @sympy_physics.optics_utils_eval("fresnel_coefficients(pi/6, 1, 4/3)[3]"),
    ],
    "fresnel_coefficients parity",
  )
  optics_assert_expr_equal(
    deviation(
      small_angle,
      optics_index_arg(six_fifths),
      optics_index_arg(three_halves),
    ),
    @sympy_physics.optics_utils_eval("deviation(0.1, 6/5, 3/2)"),
    "deviation parity",
  )
  optics_assert_expr_list_equal(
    fresnel_coefficients(
      test_pi_expr() * test_rational_expr(3, 10),
      optics_index_arg(@symcore.int(2)),
      optics_index_arg(@symcore.int(1)),
    ),
    [
      @sympy_physics.optics_utils_eval("fresnel_coefficients(3*pi/10, 2, 1)[0]"),
      @sympy_physics.optics_utils_eval("fresnel_coefficients(3*pi/10, 2, 1)[1]"),
    ],
    "fresnel_coefficients tir parity",
  )
  optics_assert_expr_equal(
    brewster_angle(optics_index_arg(one), optics_index_arg(four_thirds)),
    @sympy_physics.optics_utils_eval("brewster_angle(1, 4/3)"),
    "brewster_angle parity",
  )
  optics_assert_expr_equal(
    critical_angle(optics_index_arg(four_thirds), optics_index_arg(one)),
    @sympy_physics.optics_utils_eval("critical_angle(4/3, 1)"),
    "critical_angle parity",
  )
  optics_assert_expr_equal(
    lens_makers_formula(
      optics_index_arg(four_thirds),
      optics_index_arg(one),
      @symcore.int(10),
      @symcore.int(-10),
    ),
    @sympy_physics.optics_utils_eval("lens_makers_formula(4/3, 1, 10, -10)"),
    "lens_makers_formula parity",
  )
  optics_assert_expr_equal(
    lens_makers_formula(
      optics_index_arg(four_thirds),
      optics_index_arg(one),
      @symcore.int(10),
      test_oo_expr(),
    ),
    @sympy_physics.optics_utils_eval("lens_makers_formula(4/3, 1, 10, oo)"),
    "lens_makers_formula plano parity",
  )
  optics_assert_expr_equal(
    mirror_formula(focal_length=Some(f), u=Some(u)),
    @sympy_physics.optics_utils_eval("mirror_formula(focal_length=f, u=u)"),
    "mirror_formula parity",
  )
  optics_assert_expr_equal(
    lens_formula(focal_length=Some(f), u=Some(u)),
    @sympy_physics.optics_utils_eval("lens_formula(focal_length=f, u=u)"),
    "lens_formula parity",
  )
  optics_assert_expr_equal(
    hyperfocal_distance(f, n, c),
    @sympy_physics.optics_utils_eval("hyperfocal_distance(f, N, c)"),
    "hyperfocal_distance parity",
  )
  optics_assert_expr_equal(
    transverse_magnification(@symcore.int(30), @symcore.int(15)),
    @sympy_physics.optics_utils_eval("transverse_magnification(30, 15)"),
    "transverse_magnification parity",
  )
}
