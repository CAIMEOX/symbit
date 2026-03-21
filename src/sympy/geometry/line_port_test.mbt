///|
test "geometry.line parity repr and unique intersection" {
  let l1 = line(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(2)),
  )
  let l2 = line(
    point2d(@symcore.int(0), @symcore.int(2)),
    point2d(@symcore.int(2), @symcore.int(0)),
  )
  assert_eq(l1.repr(), geometry_eval_repr("Line(Point2D(0, 0), Point2D(2, 2))"))
  assert_eq(
    intersection(geometry_line(l1), geometry_line(l2))[0].repr(),
    geometry_eval_repr(
      "intersection(Line(Point2D(0,0), Point2D(2,2)), Line(Point2D(0,2), Point2D(2,0)))[0]",
    ),
  )
}

///|
test "geometry.line parity transforms and distance" {
  let seg = segment(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(4), @symcore.int(0)),
  )
  assert_eq(
    seg.translate([@symcore.int(0), @symcore.int(1)]).repr(),
    geometry_eval_repr("Segment(Point2D(0,0), Point2D(4,0)).translate(0, 1)"),
  )
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(
        seg.distance(point2d(@symcore.int(1), @symcore.int(2))),
      ),
      "Segment(Point2D(0,0), Point2D(4,0)).distance(Point2D(1,2))",
    ),
  )
}

///|
test "geometry.line parity plotting and bisector helpers" {
  let l = line(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(5), @symcore.int(3)),
  )
  assert_eq(
    "[" + l.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    geometry_eval_str("Line(Point2D(0, 0), Point2D(5, 3)).plot_interval()"),
  )
  let r = ray(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(4), @symcore.int(1)),
  )
  assert_eq(
    "[" + r.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    geometry_eval_str("Ray(Point2D(0, 0), Point2D(4, 1)).plot_interval()"),
  )
  assert_eq(
    r.source().repr(),
    geometry_eval_repr("Ray(Point2D(0, 0), Point2D(4, 1)).source"),
  )
  let seg = segment(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(6), @symcore.int(6)),
  )
  assert_eq(
    "[" + seg.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    geometry_eval_str("Segment(Point2D(0, 0), Point2D(6, 6)).plot_interval()"),
  )
  assert_eq(
    seg.perpendicular_bisector().repr(),
    geometry_eval_repr(
      "Segment(Point2D(0, 0), Point2D(6, 6)).perpendicular_bisector()",
    ),
  )
}

///|
test "geometry.line parity equality helpers" {
  let l1 = line(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(2)),
  )
  let l2 = line(
    point2d(@symcore.int(1), @symcore.int(1)),
    point2d(@symcore.int(3), @symcore.int(3)),
  )
  assert_eq(
    l1.equals(geometry_line(l2)).to_string().to_lower(),
    geometry_eval_str(
      "Line(Point2D(0, 0), Point2D(2, 2)).equals(Line(Point2D(1, 1), Point2D(3, 3)))",
    ).to_lower(),
  )
  let r1 = ray(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(0)),
  )
  let r2 = ray(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(0)),
  )
  assert_eq(
    r1.equals(geometry_ray(r2)).to_string().to_lower(),
    geometry_eval_str(
      "Ray(Point2D(0, 0), Point2D(1, 0)).equals(Ray(Point2D(0, 0), Point2D(2, 0)))",
    ).to_lower(),
  )
  let s1 = segment(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(0)),
  )
  let s2 = segment(
    point2d(@symcore.int(2), @symcore.int(0)),
    point2d(@symcore.int(0), @symcore.int(0)),
  )
  assert_eq(
    s1.equals(geometry_segment(s2)).to_string().to_lower(),
    geometry_eval_str(
      "Segment(Point2D(0, 0), Point2D(2, 0)).equals(Segment(Point2D(2, 0), Point2D(0, 0)))",
    ).to_lower(),
  )
}
