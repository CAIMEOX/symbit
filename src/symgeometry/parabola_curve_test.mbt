///|
test "geometry.parabola vertex axis and line intersection" {
  let pa = try! parabola(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! line(
      try! point2d(@symcore.int(-2), @symcore.int(-2)),
      try! point2d(@symcore.int(2), @symcore.int(-2)),
    ),
  )
  assert_eq((try! pa.vertex()).repr(), "Point2D(0, -1)")
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! pa.p_parameter()),
    "1",
  )) else {
    fail("parabola p parameter")
  }
  let hits = try! pa.intersection(
    geometry_line(
      try! line(
        try! point2d(@symcore.int(-3), @symcore.int(3)),
        try! point2d(@symcore.int(3), @symcore.int(3)),
      ),
    ),
  )
  try! geometry_assert_point_set_equal(
    hits,
    [("-4", "3"), ("4", "3")],
    "parabola-line intersection",
  )
}

///|
test "geometry.curve arbitrary point transforms and length shell" {
  let s = @symcore.symbol("s")
  let c = try! curve(
    [@symcore.int(2) * s, s ^ @symcore.int(2)],
    s,
    @symcore.int(0),
    @symcore.int(2),
  )
  let ap = try! c.arbitrary_point()
  assert_eq(@symprint.to_string(try! ap.x()), "2*s")
  assert_eq(@symprint.to_string(try! ap.y()), "s**2")
  assert_eq(
    (try! c.translate([@symcore.int(1), @symcore.int(3)])).repr(),
    "Curve((2*s + 1, s**2 + 3), (s, 0, 2))",
  )
  assert_eq(
    @symprint.to_string(c.length()),
    "Integral(sqrt(((2*s)**2 + 4)), s, 0, 2)",
  )
}
