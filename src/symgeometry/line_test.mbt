///|
test "geometry.line ray segment helpers" {
  let p0 = try! point2d(@symcore.int(0), @symcore.int(0))
  let p1 = try! point2d(@symcore.int(2), @symcore.int(2))
  let p2 = try! point2d(@symcore.int(2), @symcore.int(0))
  let l1 = try! line(p0, p1)
  let l2 = try! line(try! point2d(@symcore.int(0), @symcore.int(2)), p2)
  let hits = try! l1.intersection(geometry_line(l2))
  assert_eq(hits.length(), 1)
  match hits[0] {
    GeometryEntity::Point(hit) => assert_eq(hit.repr(), "Point2D(1, 1)")
    _ => fail("expected point intersection")
  }
  let seg = try! segment(p0, p2)
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! seg.length()),
    "2",
  )) else {
    fail("segment length")
  }
  let ray_obj = try! ray(p0, p1)
  assert_true(
    try! ray_obj.contains(try! point2d(@symcore.int(4), @symcore.int(4))),
  )
  assert_eq(
    "[" + l1.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    "[t, -5, 5]",
  )
  assert_eq(
    "[" + ray_obj.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    "[t, 0, 10]",
  )
  assert_eq(ray_obj.source().repr(), "Point2D(0, 0)")
  assert_eq(
    "[" + seg.plot_interval().map(geometry_py_expr_text).join(", ") + "]",
    "[t, 0, 1]",
  )
  assert_eq(
    (try! seg.perpendicular_bisector()).repr(),
    "Line2D(Point2D(1, 0), Point2D(1, 1))",
  )
}

///|
test "geometry.line equality helpers" {
  let l1 = try! line(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(2)),
  )
  let l2 = try! line(
    try! point2d(@symcore.int(1), @symcore.int(1)),
    try! point2d(@symcore.int(3), @symcore.int(3)),
  )
  let r1 = try! ray(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(0)),
  )
  let r2 = try! ray(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
  )
  let s1 = try! segment(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
  )
  let s2 = try! segment(
    try! point2d(@symcore.int(2), @symcore.int(0)),
    try! point2d(@symcore.int(0), @symcore.int(0)),
  )
  assert_true(try! l1.equals(geometry_line(l2)))
  assert_true(try! r1.equals(geometry_ray(r2)))
  assert_true(try! s1.equals(geometry_segment(s2)))
}
