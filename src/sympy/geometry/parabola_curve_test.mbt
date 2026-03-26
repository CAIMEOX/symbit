///|
test "geometry.parabola vertex axis and line intersection" {
  let pa = parabola(
    point2d(@symcore.int(0), @symcore.int(0)),
    line(
      point2d(@symcore.int(-2), @symcore.int(-2)),
      point2d(@symcore.int(2), @symcore.int(-2)),
    ),
  )
  assert_eq(pa.vertex().repr(), "Point2D(0, -1)")
  assert_true(geometry_expr_equal(@symprint.to_string(pa.p_parameter()), "1"))
  let hits = pa.intersection(
    geometry_line(
      line(
        point2d(@symcore.int(-3), @symcore.int(3)),
        point2d(@symcore.int(3), @symcore.int(3)),
      ),
    ),
  )
  geometry_assert_point_set_equal(
    hits,
    [("-4", "3"), ("4", "3")],
    "parabola-line intersection",
  )
}

///|
test "geometry.curve arbitrary point transforms and length shell" {
  let s = @symcore.Expr::Symbol("s")
  let c = curve(
    [@symcore.int(2) * s, s ^ @symcore.int(2)],
    s,
    @symcore.int(0),
    @symcore.int(2),
  )
  let ap = c.arbitrary_point()
  assert_eq(@symprint.to_string(ap.x()), "2*s")
  assert_eq(@symprint.to_string(ap.y()), "s**2")
  assert_eq(
    c.translate([@symcore.int(1), @symcore.int(3)]).repr(),
    "Curve((2*s + 1, s**2 + 3), (s, 0, 2))",
  )
  assert_eq(
    @symprint.to_string(c.length()),
    "Integral(sqrt(((2*s)**2 + 4)), s, 0, 2)",
  )
}

///|
test "geometry.curve parameter helpers" {
  let t = @symcore.Expr::Symbol("t")
  let z = @symcore.Expr::Symbol("z")
  let c = curve(
    [@symcore.int(2) * t, t ^ @symcore.int(2)],
    t,
    @symcore.int(0),
    @symcore.int(2),
  )
  assert_eq(
    "[" + c.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    "[t, 0, 2]",
  )
  assert_eq(
    "[" +
    c.plot_interval(parameter=z).map(geometry_py_expr_text).join(", ") +
    "]",
    "[z, 0, 2]",
  )
}

///|
test "geometry.curve free symbol helpers" {
  let t = @symcore.Expr::Symbol("t")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = curve([t + a, t ^ @symcore.int(2)], t, b, @symcore.int(2))
  assert_eq(expr_set_summary(c.free_symbols()), "{a, b}")
}
