///|
test "geometry.point arithmetic and metric helpers" {
  let p = try! point2d(@symcore.int(1), @symcore.int(2))
  let q = try! point2d(@symcore.int(4), @symcore.int(-1))
  assert_eq((p + q).repr(), "Point2D(5, 1)")
  assert_eq((q - p).repr(), "Point2D(3, -3)")
  assert_eq(p.mul(@symcore.int(2)).repr(), "Point2D(2, 4)")
  assert_eq(p.midpoint(q).repr(), "Point2D(5/2, 1/2)")
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! p.distance(q)),
    "3*sqrt(2)",
  )) else {
    fail("point distance")
  }
}

///|
test "geometry.point collinear and coplanar helpers" {
  let p0 = try! point2d(@symcore.int(0), @symcore.int(0))
  let p1 = try! point2d(@symcore.int(1), @symcore.int(1))
  let p2 = try! point2d(@symcore.int(2), @symcore.int(2))
  let p3 = try! point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0))
  let p4 = try! point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0))
  let p5 = try! point3d(@symcore.int(1), @symcore.int(1), @symcore.int(0))
  assert_true(try! point_are_collinear([p0, p1, p2]))
  assert_true(
    try! point_are_coplanar([
      try! p0.with_dim(3),
      try! p1.with_dim(3),
      p3,
      p4,
      p5,
    ]),
  )
}
