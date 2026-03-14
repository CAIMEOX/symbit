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
