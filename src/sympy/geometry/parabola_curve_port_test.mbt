///|
test "geometry.parabola parity repr vertex equation and intersection" {
  let pa = parabola(
    point2d(@symcore.int(0), @symcore.int(0)),
    line(
      point2d(@symcore.int(-2), @symcore.int(-2)),
      point2d(@symcore.int(2), @symcore.int(-2)),
    ),
  )
  assert_eq(
    pa.repr(),
    geometry_eval_repr(
      "Parabola(Point2D(0, 0), Line(Point2D(-2, -2), Point2D(2, -2)))",
    ),
  )
  assert_eq(
    pa.vertex().repr(),
    geometry_eval_repr(
      "Parabola(Point2D(0, 0), Line(Point2D(-2, -2), Point2D(2, -2))).vertex",
    ),
  )
  geometry_assert_point_set_equal(
    pa.intersection(
      geometry_line(
        line(
          point2d(@symcore.int(-3), @symcore.int(3)),
          point2d(@symcore.int(3), @symcore.int(3)),
        ),
      ),
    ),
    [("-4", "3"), ("4", "3")],
    "parabola intersection parity",
  )
}

///|
test "geometry.curve parity repr arbitrary point and rotation" {
  let s = @symcore.Expr::Symbol("s")
  let c = curve(
    [@symcore.int(2) * s, s ^ @symcore.int(2)],
    s,
    @symcore.int(0),
    @symcore.int(2),
  )
  let ap = c.arbitrary_point(parameter=@symcore.Expr::Symbol("z"))
  assert_true(
    geometry_expr_equal(
      @symprint.pretty_string(ap.x()),
      "Curve((2*s, s**2), (s, 0, 2)).arbitrary_point(z).x",
    ),
  )
  assert_true(
    geometry_expr_equal(
      @symprint.pretty_string(ap.y()),
      "Curve((2*s, s**2), (s, 0, 2)).arbitrary_point(z).y",
    ),
  )
  let rotated = c.rotate(
    @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
    (@symcore.int(2) ^ @symcore.int(-1)),
  )
  let rot_pt = rotated.arbitrary_point(parameter=@symcore.Expr::Symbol("z"))
  assert_true(
    geometry_expr_equal(
      @symprint.pretty_string(rot_pt.x()),
      "Curve((2*s, s**2), (s, 0, 2)).rotate(pi/2).arbitrary_point(z).x",
    ),
  )
  assert_true(
    geometry_expr_equal(
      @symprint.pretty_string(rot_pt.y()),
      "Curve((2*s, s**2), (s, 0, 2)).rotate(pi/2).arbitrary_point(z).y",
    ),
  )
}

///|
test "geometry.curve parity parameter helpers" {
  let t = @symcore.Expr::Symbol("t")
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
}

///|
test "geometry.curve parity free symbol helpers" {
  let t = @symcore.Expr::Symbol("t")
  let a = @symcore.Expr::Symbol("a")
  let b = @symcore.Expr::Symbol("b")
  let c = curve([t + a, t ^ @symcore.int(2)], t, b, @symcore.int(2))
  assert_eq(
    expr_set_summary(c.free_symbols()),
    string_set_summary(
      geometry_eval_str("Curve((t + a, t**2), (t, b, 2)).free_symbols"),
    ),
  )
}
