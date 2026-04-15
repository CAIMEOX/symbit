///|
test "geometry.polygon area convexity and bounds" {
  let polygon_value = polygon([
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(4), @symcore.int(0)),
    point2d(@symcore.int(4), @symcore.int(3)),
    point2d(@symcore.int(0), @symcore.int(3)),
  ])
  let poly = match polygon_value {
    GeometryEntity::Polygon(value) => value
    _ => fail("expected polygon")
  }
  assert_true(geometry_expr_equal(@symprint.pretty_string(poly.area()), "12"))
  assert_true(poly.is_convex())
  let bounds = poly.bounds()
  assert_eq(bounds.0.repr(), "Point2D(0, 0)")
  assert_eq(bounds.1.repr(), "Point2D(4, 3)")
}

///|
test "geometry.regular polygon and triangle centers" {
  let rp = regular_polygon(
    point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
    4,
  )
  let vertices = rp.vertices()
  let args = rp.args()
  assert_eq(args.0.repr(), "Point2D(0, 0)")
  geometry_assert_expr_equal(args.1, "1", "regular polygon args radius")
  assert_eq(args.2, 4)
  geometry_assert_expr_equal(args.3, "0", "regular polygon args rotation")
  assert_eq(rp.circumcenter().repr(), "Point2D(0, 0)")
  assert_true(geometry_expr_equal(@symprint.pretty_string(vertices[0].x()), "1"))
  assert_true(geometry_expr_equal(@symprint.pretty_string(vertices[1].y()), "1"))
  let tri = triangle(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(4), @symcore.int(0)),
    point2d(@symcore.int(0), @symcore.int(3)),
  )
  assert_true(tri.is_right())
  let incenter = tri.incenter()
  assert_true(geometry_expr_equal(@symprint.pretty_string(incenter.x()), "1"))
  assert_true(geometry_expr_equal(@symprint.pretty_string(incenter.y()), "1"))
  let circumcenter = tri.circumcenter()
  assert_true(geometry_expr_equal(@symprint.pretty_string(circumcenter.x()), "2"))
  assert_true(geometry_expr_equal(@symprint.pretty_string(circumcenter.y()), "3/2"))
  assert_true(
    geometry_expr_equal(@symprint.pretty_string(tri.incircle().radius()), "1"),
  )
  assert_eq(
    expr_map_summary(
      geometry_regular_polygon(rp).parameter_value(
        point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.Expr::Symbol("t"),
      ),
    ),
    "{t: 0}",
  )
}

///|
test "geometry.polygon enclosure parameter and bisector helpers" {
  let sq = match
    polygon([
      point2d(@symcore.int(0), @symcore.int(0)),
      point2d(@symcore.int(0), @symcore.int(1)),
      point2d(@symcore.int(1), @symcore.int(1)),
      point2d(@symcore.int(1), @symcore.int(0)),
    ]) {
    GeometryEntity::Polygon(value) => value
    _ => fail("expected polygon")
  }
  assert_true(
    sq.encloses(
      geometry_point(
        point2d(
          @symcore.rational_from_ints(3, 4),
          @symcore.rational_from_ints(1, 2),
        ),
      ),
    ),
  )
  assert_false(
    sq.encloses(
      geometry_point(
        point2d(@symcore.int(0), @symcore.rational_from_ints(1, 2)),
      ),
    ),
  )
  assert_eq(
    expr_map_summary(
      sq.parameter_value(
        point2d(@symcore.rational_from_ints(1, 2), @symcore.int(1)),
        @symcore.Expr::Symbol("t"),
      ),
    ),
    "{t: 3/8}",
  )
  let bisectors = sq.bisectors()
  let sq_vertices = sq.vertices()
  let corner_bisector = match bisectors.get(sq_vertices[0]) {
    Some(value) => value
    None => fail("missing bisector")
  }
  assert_true(
    geometry_expr_equal(
      geometry_py_expr_text(corner_bisector.p2().x()),
      geometry_py_expr_text(corner_bisector.p2().y()),
    ),
  )
  assert_true(
    sq.encloses(
      geometry_circle(
        circle(
          point2d(
            @symcore.rational_from_ints(1, 2),
            @symcore.rational_from_ints(1, 2),
          ),
          @symcore.rational_from_ints(1, 4),
        ),
      ),
    ),
  )
}

///|
test "geometry.triangle extended centers and similarity" {
  let tri = triangle(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(0)),
    point2d(@symcore.int(0), @symcore.int(1)),
  )
  let altitudes = tri.altitudes()
  let tri_vertices = tri.vertices()
  assert_eq(
    match altitudes.get(tri_vertices[1]) {
      Some(value) => value.repr()
      None => fail("missing altitude")
    },
    "Segment2D(Point2D(1, 0), Point2D(0, 0))",
  )
  let nine = tri.nine_point_circle()
  geometry_assert_point_equal(
    nine.center(),
    "1/4",
    "1/4",
    "triangle nine-point center",
  )
  geometry_assert_expr_equal(
    nine.radius(),
    "sqrt(2)/4",
    "triangle nine-point radius",
  )
  assert_eq(tri.eulerline().repr(), "Line2D(Point2D(0, 0), Point2D(1/2, 1/2))")
  let medians = tri.medians()
  assert_eq(
    match medians.get(tri_vertices[0]) {
      Some(value) => value.repr()
      None => fail("missing median")
    },
    "Segment2D(Point2D(0, 0), Point2D(1/2, 1/2))",
  )
}
