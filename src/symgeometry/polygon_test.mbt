///|
test "geometry.polygon area convexity and bounds" {
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
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(poly.area()),
    "12",
  )) else {
    fail("polygon area")
  }
  assert_true(try! poly.is_convex())
  let bounds = try! poly.bounds()
  assert_eq(bounds.0.repr(), "Point2D(0, 0)")
  assert_eq(bounds.1.repr(), "Point2D(4, 3)")
}

///|
test "geometry.regular polygon and triangle centers" {
  let rp = try! regular_polygon(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
    4,
  )
  let vertices = try! rp.vertices()
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! vertices[0].x()),
    "1",
  )) else {
    fail("regular polygon first vertex x")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! vertices[1].y()),
    "1",
  )) else {
    fail("regular polygon second vertex y")
  }
  let tri = try! triangle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(4), @symcore.int(0)),
    try! point2d(@symcore.int(0), @symcore.int(3)),
  )
  assert_true(try! tri.is_right())
  let incenter = try! tri.incenter()
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! incenter.x()),
    "1",
  )) else {
    fail("triangle incenter x")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! incenter.y()),
    "1",
  )) else {
    fail("triangle incenter y")
  }
  let circumcenter = try! tri.circumcenter()
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! circumcenter.x()),
    "2",
  )) else {
    fail("triangle circumcenter x")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! circumcenter.y()),
    "3/2",
  )) else {
    fail("triangle circumcenter y")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string((try! tri.incircle()).radius()),
    "1",
  )) else {
    fail("triangle incircle radius")
  }
}
