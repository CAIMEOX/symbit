///|
test "geometry.line parity repr and unique intersection" {
  let l1 = try! line(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(2)),
  )
  let l2 = try! line(
    try! point2d(@symcore.int(0), @symcore.int(2)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
  )
  assert_eq(
    l1.repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Line(Point2D(0, 0), Point2D(2, 2))",
    ),
  )
  assert_eq(
    (try! intersection(geometry_line(l1), geometry_line(l2)))[0].repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "intersection(Line(Point2D(0,0), Point2D(2,2)), Line(Point2D(0,2), Point2D(2,0)))[0]",
    ),
  )
}

///|
test "geometry.line parity transforms and distance" {
  let seg = try! segment(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(4), @symcore.int(0)),
  )
  assert_eq(
    seg.translate([@symcore.int(0), @symcore.int(1)]).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Segment(Point2D(0,0), Point2D(4,0)).translate(0, 1)",
    ),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(
      try! seg.distance(try! point2d(@symcore.int(1), @symcore.int(2))),
    ),
    "Segment(Point2D(0,0), Point2D(4,0)).distance(Point2D(1,2))",
  )) else {
    fail("segment distance parity")
  }
}

///|
test "geometry.line parity plotting and bisector helpers" {
  let l = try! line(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(5), @symcore.int(3)),
  )
  assert_eq(
    "[" + l.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    try! @sympy_geometry.geometry_eval_str(
      "Line(Point2D(0, 0), Point2D(5, 3)).plot_interval()",
    ),
  )
  let r = try! ray(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(4), @symcore.int(1)),
  )
  assert_eq(
    "[" + r.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    try! @sympy_geometry.geometry_eval_str(
      "Ray(Point2D(0, 0), Point2D(4, 1)).plot_interval()",
    ),
  )
  assert_eq(
    r.source().repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Ray(Point2D(0, 0), Point2D(4, 1)).source",
    ),
  )
  let seg = try! segment(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(6), @symcore.int(6)),
  )
  assert_eq(
    "[" + seg.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    try! @sympy_geometry.geometry_eval_str(
      "Segment(Point2D(0, 0), Point2D(6, 6)).plot_interval()",
    ),
  )
  assert_eq(
    (try! seg.perpendicular_bisector()).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Segment(Point2D(0, 0), Point2D(6, 6)).perpendicular_bisector()",
    ),
  )
}

///|
test "geometry.line parity equality helpers" {
  let l1 = try! line(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(2)),
  )
  let l2 = try! line(
    try! point2d(@symcore.int(1), @symcore.int(1)),
    try! point2d(@symcore.int(3), @symcore.int(3)),
  )
  assert_eq(
    (try! l1.equals(geometry_line(l2))).to_string().to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Line(Point2D(0, 0), Point2D(2, 2)).equals(Line(Point2D(1, 1), Point2D(3, 3)))",
    ).to_lower(),
  )
  let r1 = try! ray(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(0)),
  )
  let r2 = try! ray(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
  )
  assert_eq(
    (try! r1.equals(geometry_ray(r2))).to_string().to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Ray(Point2D(0, 0), Point2D(1, 0)).equals(Ray(Point2D(0, 0), Point2D(2, 0)))",
    ).to_lower(),
  )
  let s1 = try! segment(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
  )
  let s2 = try! segment(
    try! point2d(@symcore.int(2), @symcore.int(0)),
    try! point2d(@symcore.int(0), @symcore.int(0)),
  )
  assert_eq(
    (try! s1.equals(geometry_segment(s2))).to_string().to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Segment(Point2D(0, 0), Point2D(2, 0)).equals(Segment(Point2D(2, 0), Point2D(0, 0)))",
    ).to_lower(),
  )
}
