///|
test "geometry.util helpers" {
  let x = @symcore.Expr::Symbol("x")
  assert_eq(@symprint.pretty_string(find("x", x + @symcore.int(1))), "x")
  let c = centroid([
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(0)),
  ])
  match c {
    Some(point_obj) => assert_eq(point_obj.repr(), "Point2D(1, 0)")
    None => fail("expected centroid")
  }
}

///|
test "geometry.util convex hull and distance pairs" {
  let points = [
    geometry_point(point2d(@symcore.int(1), @symcore.int(-1))),
    geometry_point(point2d(@symcore.int(1), @symcore.int(-2))),
    geometry_point(point2d(@symcore.int(3), @symcore.int(-1))),
    geometry_point(point2d(@symcore.int(-5), @symcore.int(-2))),
    geometry_point(point2d(@symcore.int(15), @symcore.int(-4))),
  ]
  assert_eq(
    convex_hull(points).repr(),
    "Polygon(Point2D(-5, -2), Point2D(1, -1), Point2D(3, -1), Point2D(15, -4))",
  )
  assert_eq(
    point_chains_summary(convex_hull_chains(points)),
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
test "geometry.util are_similar dispatch" {
  let s1 = segment(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(2), @symcore.int(2)),
  )
  let s2 = segment(
    point2d(@symcore.int(2), @symcore.int(2)),
    point2d(@symcore.int(4), @symcore.int(4)),
  )
  assert_true(are_similar(geometry_segment(s1), geometry_segment(s2)))
}
