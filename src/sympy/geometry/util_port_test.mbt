///|
test "geometry.util parity are_coplanar centroid intersection" {
  let centroid_value = centroid([
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(2)),
  ])
  match centroid_value {
    Some(pt) =>
      assert_eq(
        pt.repr(),
        geometry_eval_repr("centroid(Point2D(0,0), Point2D(2,0), Point2D(2,2))"),
      )
    None => fail("expected centroid")
  }
  assert_true(
    are_coplanar([
      geometry_point(point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0))),
      geometry_point(point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0))),
      geometry_point(point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0))),
      geometry_point(point3d(@symcore.int(1), @symcore.int(1), @symcore.int(0))),
    ]),
  )
}

///|
test "geometry.util parity convex hull and point-pair helpers" {
  let hull_points = [
    geometry_point(point2d(@symcore.int(1), @symcore.int(-1))),
    geometry_point(point2d(@symcore.int(1), @symcore.int(-2))),
    geometry_point(point2d(@symcore.int(3), @symcore.int(-1))),
    geometry_point(point2d(@symcore.int(-5), @symcore.int(-2))),
    geometry_point(point2d(@symcore.int(15), @symcore.int(-4))),
  ]
  let hull = convex_hull(hull_points)
  match hull {
    GeometryEntity::Polygon(poly_obj) =>
      assert_eq(
        point_list_summary(ordered_points(poly_obj.vertices())),
        "[Point2D(-5, -2), Point2D(1, -1), Point2D(3, -1), Point2D(15, -4)]",
      )
    _ => fail("expected polygon hull")
  }
  assert_eq(
    point_chains_summary(convex_hull_chains(hull_points)),
    "([Point2D(-5, -2), Point2D(15, -4)], [Point2D(-5, -2), Point2D(1, -1), Point2D(3, -1), Point2D(15, -4)])",
  )
  let trio = [
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(1)),
  ]
  assert_eq(
    point_pair_set_summary(closest_points(trio)),
    "{(Point2D(0, 0), Point2D(1, 0)), (Point2D(1, 0), Point2D(1, 1))}",
  )
  assert_eq(
    point_pair_set_summary(farthest_points(trio)),
    "{(Point2D(0, 0), Point2D(1, 1))}",
  )
}

///|
test "geometry.util parity are_similar dispatch" {
  let s1 = segment(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(2)),
  )
  let s2 = segment(
    point2d(@symcore.int(2), @symcore.int(2)),
    point2d(@symcore.int(4), @symcore.int(4)),
  )
  assert_eq(
    are_similar(geometry_segment(s1), geometry_segment(s2))
    .to_string()
    .to_lower(),
    geometry_eval_str(
      "sympy.geometry.util.are_similar(Segment(Point2D(0, 0), Point2D(2, 2)), Segment(Point2D(2, 2), Point2D(4, 4)))",
    ).to_lower(),
  )
}
