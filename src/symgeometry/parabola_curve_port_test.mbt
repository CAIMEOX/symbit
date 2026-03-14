///|
test "geometry.parabola parity repr vertex equation and intersection" {
  let pa = try! parabola(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! line(
      try! point2d(@symcore.int(-2), @symcore.int(-2)),
      try! point2d(@symcore.int(2), @symcore.int(-2)),
    ),
  )
  assert_eq(
    try! pa.repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Parabola(Point2D(0, 0), Line(Point2D(-2, -2), Point2D(2, -2)))",
    ),
  )
  assert_eq(
    (try! pa.vertex()).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Parabola(Point2D(0, 0), Line(Point2D(-2, -2), Point2D(2, -2))).vertex",
    ),
  )
  try! geometry_assert_point_set_equal(
    try! pa.intersection(
      geometry_line(
        try! line(
          try! point2d(@symcore.int(-3), @symcore.int(3)),
          try! point2d(@symcore.int(3), @symcore.int(3)),
        ),
      ),
    ),
    [("-4", "3"), ("4", "3")],
    "parabola intersection parity",
  )
}

///|
test "geometry.curve parity repr arbitrary point and rotation" {
  let s = @symcore.symbol("s")
  let c = try! curve(
    [@symcore.int(2) * s, s ^ @symcore.int(2)],
    s,
    @symcore.int(0),
    @symcore.int(2),
  )
  let ap = try! c.arbitrary_point(parameter=@symcore.symbol("z"))
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! ap.x()),
    "Curve((2*s, s**2), (s, 0, 2)).arbitrary_point(z).x",
  )) else {
    fail("curve arbitrary point x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! ap.y()),
    "Curve((2*s, s**2), (s, 0, 2)).arbitrary_point(z).y",
  )) else {
    fail("curve arbitrary point y parity")
  }
  let rotated = try! c.rotate(
    @symcore.symbol("pi") * (@symcore.int(2) ^ @symcore.int(-1)),
  )
  let rot_pt = try! rotated.arbitrary_point(parameter=@symcore.symbol("z"))
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! rot_pt.x()),
    "Curve((2*s, s**2), (s, 0, 2)).rotate(pi/2).arbitrary_point(z).x",
  )) else {
    fail("curve rotate x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! rot_pt.y()),
    "Curve((2*s, s**2), (s, 0, 2)).rotate(pi/2).arbitrary_point(z).y",
  )) else {
    fail("curve rotate y parity")
  }
}

///|
test "geometry.curve parity parameter helpers" {
  let t = @symcore.symbol("t")
  let c = try! curve(
    [@symcore.int(2) * t, t ^ @symcore.int(2)],
    t,
    @symcore.int(0),
    @symcore.int(2),
  )
  assert_eq(
    "[" + c.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    "[t, 0, 2]",
  )
}

///|
test "geometry.curve parity free symbol helpers" {
  let t = @symcore.symbol("t")
  let a = @symcore.symbol("a")
  let b = @symcore.symbol("b")
  let c = try! curve([t + a, t ^ @symcore.int(2)], t, b, @symcore.int(2))
  assert_eq(
    expr_set_summary(c.free_symbols()),
    string_set_summary(
      try! @sympy_geometry.geometry_eval_str(
        "Curve((t + a, t**2), (t, b, 2)).free_symbols",
      ),
    ),
  )
}
