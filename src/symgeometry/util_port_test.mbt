///|
test "geometry.util parity are_coplanar centroid intersection" {
  let centroid_value = try! centroid([
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(2)),
  ])
  match centroid_value {
    Some(pt) =>
      assert_eq(
        pt.repr(),
        try! @sympy_geometry.geometry_eval_repr(
          "centroid(Point2D(0,0), Point2D(2,0), Point2D(2,2))",
        ),
      )
    None => fail("expected centroid")
  }
  assert_true(
    try! are_coplanar([
      geometry_point(
        try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
      ),
      geometry_point(
        try! point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0)),
      ),
      geometry_point(
        try! point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0)),
      ),
      geometry_point(
        try! point3d(@symcore.int(1), @symcore.int(1), @symcore.int(0)),
      ),
    ]),
  )
}

///|
test "geometry.util parity convex hull and point-pair helpers" {
  let hull_points = [
    geometry_point(try! point2d(@symcore.int(1), @symcore.int(-1))),
    geometry_point(try! point2d(@symcore.int(1), @symcore.int(-2))),
    geometry_point(try! point2d(@symcore.int(3), @symcore.int(-1))),
    geometry_point(try! point2d(@symcore.int(-5), @symcore.int(-2))),
    geometry_point(try! point2d(@symcore.int(15), @symcore.int(-4))),
  ]
  let hull = try! convex_hull(hull_points)
  match hull {
    GeometryEntity::Polygon(poly_obj) =>
      assert_eq(
        point_list_summary(ordered_points(poly_obj.vertices())),
        "[Point2D(-5, -2), Point2D(1, -1), Point2D(3, -1), Point2D(15, -4)]",
      )
    _ => fail("expected polygon hull")
  }
  assert_eq(
    point_chains_summary(try! convex_hull_chains(hull_points)),
    "([Point2D(-5, -2), Point2D(15, -4)], [Point2D(-5, -2), Point2D(1, -1), Point2D(3, -1), Point2D(15, -4)])",
  )
  let trio = [
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(1)),
  ]
  assert_eq(
    point_pair_set_summary(try! closest_points(trio)),
    "{(Point2D(0, 0), Point2D(1, 0)), (Point2D(1, 0), Point2D(1, 1))}",
  )
  assert_eq(
    point_pair_set_summary(try! farthest_points(trio)),
    "{(Point2D(0, 0), Point2D(1, 1))}",
  )
}
