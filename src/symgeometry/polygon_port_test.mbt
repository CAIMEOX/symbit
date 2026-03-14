///|
test "geometry.polygon parity repr and area" {
  let polygon_value = try! polygon([
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(4), @symcore.int(0)),
    try! point2d(@symcore.int(4), @symcore.int(3)),
    try! point2d(@symcore.int(0), @symcore.int(3)),
  ])
  let poly = match polygon_value {
    GeometryEntity::Polygon(value) => value
    _ => fail("expected polygon")
  }
  assert_eq(
    poly.repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Polygon(Point2D(0, 0), Point2D(4, 0), Point2D(4, 3), Point2D(0, 3))",
    ),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(poly.area()),
    "Polygon(Point2D(0, 0), Point2D(4, 0), Point2D(4, 3), Point2D(0, 3)).area",
  )) else {
    fail("polygon area parity")
  }
}

///|
test "geometry.regular polygon and triangle parity" {
  let rp = try! regular_polygon(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
    4,
  )
  assert_eq(
    rp.repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "RegularPolygon(Point2D(0, 0), 1, 4, 0)",
    ),
  )
  let vertices = try! rp.vertices()
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! vertices[0].x()),
    "RegularPolygon(Point2D(0, 0), 1, 4, 0).vertices[0].x",
  )) else {
    fail("regular polygon vertex0 x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! vertices[1].y()),
    "RegularPolygon(Point2D(0, 0), 1, 4, 0).vertices[1].y",
  )) else {
    fail("regular polygon vertex1 y parity")
  }
  let tri = try! triangle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(4), @symcore.int(0)),
    try! point2d(@symcore.int(0), @symcore.int(3)),
  )
  let incenter = try! tri.incenter()
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! incenter.x()),
    "Triangle(Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)).incenter.x",
  )) else {
    fail("triangle incenter x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! incenter.y()),
    "Triangle(Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)).incenter.y",
  )) else {
    fail("triangle incenter y parity")
  }
  let circumcircle = try! tri.circumcircle()
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(circumcircle.radius()),
    "Triangle(Point2D(0, 0), Point2D(4, 0), Point2D(0, 3)).circumcircle.radius",
  )) else {
    fail("triangle circumcircle radius parity")
  }
}
