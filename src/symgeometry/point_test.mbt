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

///|
test "geometry.point projection and norm helpers" {
  let p = try! point2d(@symcore.int(1), @symcore.int(2))
  let q = try! point2d(@symcore.int(2), @symcore.int(5))
  assert_eq((try! p.origin()).repr(), "Point2D(0, 0)")
  assert_eq((try! p.orthogonal_direction()).repr(), "Point2D(-2, 1)")
  let projected = try! p.project(q)
  try! geometry_assert_point_equal(
    projected, "24/29", "60/29", "point projection",
  )
  try! geometry_assert_expr_equal(
    p.taxicab_distance(try! point2d(@symcore.int(4), @symcore.int(5))),
    "6",
    "point taxicab",
  )
  try! geometry_assert_expr_equal(
    p.canberra_distance(try! point2d(@symcore.int(3), @symcore.int(3))),
    "7/10",
    "point canberra",
  )
  try! geometry_assert_point_equal(
    try! (try! point2d(@symcore.int(3), @symcore.int(4))).unit(),
    "3/5",
    "4/5",
    "point unit",
  )
  assert_true(p.is_nonzero())
  assert_false((try! point2d(@symcore.int(0), @symcore.int(0))).is_nonzero())
}

///|
test "geometry.point equals intersection and cyclic helpers" {
  let p = try! point2d(@symcore.int(1), @symcore.int(1))
  let q = try! point2d(@symcore.int(1), @symcore.int(1))
  let r = try! point2d(@symcore.int(2), @symcore.int(2))
  assert_true(p.equals(q))
  assert_false(p.equals(try! r.with_dim(3)))
  assert_true(try! p.is_scalar_multiple(r))
  assert_false(
    try! p.is_scalar_multiple(try! point2d(@symcore.int(2), @symcore.int(3))),
  )
  assert_true(
    try! (try! point2d(@symcore.int(1), @symcore.int(0))).is_concyclic([
      try! point2d(@symcore.int(0), @symcore.int(1)),
      try! point2d(@symcore.int(-1), @symcore.int(0)),
      try! point2d(@symcore.int(0), @symcore.int(-1)),
    ]),
  )
  let hit = try! p.intersection(
    geometry_line(
      try! line(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        try! point2d(@symcore.int(1), @symcore.int(3)),
      ),
    ),
  )
  assert_eq(try! geometry_entities_summary(hit), "[Point2D(1, 1)]")
}
