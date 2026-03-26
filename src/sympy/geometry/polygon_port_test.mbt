///|
test "geometry.polygon parity repr and area" {
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
  assert_eq(
    poly.repr(),
    geometry_eval_repr(
      "Polygon(Point2D(0, 0), Point2D(4, 0), Point2D(4, 3), Point2D(0, 3))",
    ),
  )
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(poly.area()),
      "Polygon(Point2D(0, 0), Point2D(4, 0), Point2D(4, 3), Point2D(0, 3)).area",
    ),
  )
}

///|
test "geometry.regular polygon and triangle parity" {
  let rp = regular_polygon(
    point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
    4,
  )
  assert_eq(
    rp.repr(),
    geometry_eval_repr("RegularPolygon(Point2D(0, 0), 1, 4, 0)"),
  )
  let args = rp.args()
  assert_eq(
    args.0.repr(),
    geometry_eval_repr("RegularPolygon(Point2D(0, 0), 1, 4, 0).args[0]"),
  )
  assert_true(
    geometry_expr_equal(
      geometry_py_expr_text(args.1),
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).args[1]",
    ),
  )
  assert_eq(
    args.2.to_string(),
    geometry_eval_str("RegularPolygon(Point2D(0, 0), 1, 4, 0).args[2]"),
  )
  assert_true(
    geometry_expr_equal(
      geometry_py_expr_text(args.3),
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).args[3]",
    ),
  )
  assert_eq(
    rp.circumcenter().repr(),
    geometry_eval_repr("RegularPolygon(Point2D(0, 0), 1, 4, 0).circumcenter"),
  )
  let vertices = rp.vertices()
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(vertices[0].x()),
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).vertices[0].x",
    ),
  )
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(vertices[1].y()),
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).vertices[1].y",
    ),
  )
  let tri = triangle(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(4), @symcore.int(0)),
    point2d(@symcore.int(0), @symcore.int(3)),
  )
  let incenter = tri.incenter()
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(incenter.x()),
      "Triangle(Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)).incenter.x",
    ),
  )
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(incenter.y()),
      "Triangle(Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)).incenter.y",
    ),
  )
  let circumcircle = tri.circumcircle()
  assert_true(
    geometry_expr_equal(
      @symprint.to_string(circumcircle.radius()),
      "Triangle(Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)).circumcircle.radius",
    ),
  )
  assert_eq(
    expr_map_summary(
      geometry_regular_polygon(rp).parameter_value(
        point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.Expr::Symbol("t"),
      ),
    ),
    geometry_eval_str(
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).parameter_value(Point2D(1, 0), t)",
    ),
  )
}

///|
test "geometry.polygon parity enclosure and parameter helpers" {
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
  assert_eq(
    expr_map_summary(
      sq.parameter_value(
        point2d(@symcore.rational_from_ints(1, 2), @symcore.int(1)),
        @symcore.Expr::Symbol("t"),
      ),
    ),
    geometry_eval_str(
      "Polygon(Point2D(0, 0), Point2D(0, 1), Point2D(1, 1), Point2D(1, 0)).parameter_value(Point2D(1/2, 1), t)",
    ),
  )
  let encloses_text = sq
    .encloses(
      geometry_point(
        point2d(
          @symcore.rational_from_ints(3, 4),
          @symcore.rational_from_ints(1, 2),
        ),
      ),
    )
    .to_string()
    .to_lower()
  assert_eq(
    encloses_text,
    geometry_eval_str(
      "Polygon(Point2D(0, 0), Point2D(0, 1), Point2D(1, 1), Point2D(1, 0)).encloses(Point2D(3/4, 1/2))",
    ).to_lower(),
  )
}

///|
test "geometry.triangle parity extended centers" {
  let tri = triangle(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(0)),
    point2d(@symcore.int(0), @symcore.int(1)),
  )
  let nine = tri.nine_point_circle()
  assert_eq(
    nine.center().repr(),
    geometry_eval_repr(
      "Triangle(Point2D(0, 0), Point2D(1, 0), Point2D(0, 1)).nine_point_circle.center",
    ),
  )
  assert_true(
    geometry_expr_equal(
      geometry_py_expr_text(nine.radius()),
      "Triangle(Point2D(0, 0), Point2D(1, 0), Point2D(0, 1)).nine_point_circle.radius",
    ),
  )
  assert_eq(
    tri.eulerline().repr(),
    geometry_eval_repr(
      "Triangle(Point2D(0, 0), Point2D(1, 0), Point2D(0, 1)).eulerline",
    ),
  )
}
