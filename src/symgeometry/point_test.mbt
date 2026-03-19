///|
test "geometry.point arithmetic and metric helpers" {
  let p = point2d(@symcore.int(1), @symcore.int(2))
  let q = point2d(@symcore.int(4), @symcore.int(-1))
  assert_eq((p + q).repr(), "Point2D(5, 1)")
  assert_eq((q - p).repr(), "Point2D(3, -3)")
  assert_eq(p.mul(@symcore.int(2)).repr(), "Point2D(2, 4)")
  assert_eq(p.midpoint(q).repr(), "Point2D(5/2, 1/2)")
  guard @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(p.distance(q)),
    "3*sqrt(2)",
  ) else {
    fail("point distance")
  }
}

///|
test "geometry.point collinear and coplanar helpers" {
  let p0 = point2d(@symcore.int(0), @symcore.int(0))
  let p1 = point2d(@symcore.int(1), @symcore.int(1))
  let p2 = point2d(@symcore.int(2), @symcore.int(2))
  let p3 = point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0))
  let p4 = point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0))
  let p5 = point3d(@symcore.int(1), @symcore.int(1), @symcore.int(0))
  assert_true(point_are_collinear([p0, p1, p2]))
  assert_true(point_are_coplanar([p0.with_dim(3), p1.with_dim(3), p3, p4, p5]))
}

///|
test "geometry.point projection and norm helpers" {
  let p = point2d(@symcore.int(1), @symcore.int(2))
  let q = point2d(@symcore.int(2), @symcore.int(5))
  assert_eq(p.origin().repr(), "Point2D(0, 0)")
  assert_eq(p.orthogonal_direction().repr(), "Point2D(-2, 1)")
  let projected = p.project(q)
  geometry_assert_point_equal(projected, "24/29", "60/29", "point projection")
  geometry_assert_expr_equal(
    p.taxicab_distance(point2d(@symcore.int(4), @symcore.int(5))),
    "6",
    "point taxicab",
  )
  geometry_assert_expr_equal(
    p.canberra_distance(point2d(@symcore.int(3), @symcore.int(3))),
    "7/10",
    "point canberra",
  )
  geometry_assert_point_equal(
    point2d(@symcore.int(3), @symcore.int(4)).unit(),
    "3/5",
    "4/5",
    "point unit",
  )
  assert_true(p.is_nonzero())
  assert_false(point2d(@symcore.int(0), @symcore.int(0)).is_nonzero())
}

///|
test "geometry.point equals intersection and cyclic helpers" {
  let p = point2d(@symcore.int(1), @symcore.int(1))
  let q = point2d(@symcore.int(1), @symcore.int(1))
  let r = point2d(@symcore.int(2), @symcore.int(2))
  assert_true(p.equals(q))
  assert_false(p.equals(r.with_dim(3)))
  assert_true(p.is_scalar_multiple(r))
  assert_false(p.is_scalar_multiple(point2d(@symcore.int(2), @symcore.int(3))))
  assert_true(
    point2d(@symcore.int(1), @symcore.int(0)).is_concyclic([
      point2d(@symcore.int(0), @symcore.int(1)),
      point2d(@symcore.int(-1), @symcore.int(0)),
      point2d(@symcore.int(0), @symcore.int(-1)),
    ]),
  )
  let hit = p.intersection(
    geometry_line(
      line(
        point2d(@symcore.int(1), @symcore.int(0)),
        point2d(@symcore.int(1), @symcore.int(3)),
      ),
    ),
  )
  assert_eq(geometry_entities_summary(hit), "[Point2D(1, 1)]")
}
