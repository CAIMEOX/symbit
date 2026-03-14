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
  let args = rp.args()
  assert_eq(
    args.0.repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).args[0]",
    ),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(args.1),
    "RegularPolygon(Point2D(0, 0), 1, 4, 0).args[1]",
  )) else {
    fail("regular polygon args radius parity")
  }
  assert_eq(
    args.2.to_string(),
    try! @sympy_geometry.geometry_eval_str(
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).args[2]",
    ),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(args.3),
    "RegularPolygon(Point2D(0, 0), 1, 4, 0).args[3]",
  )) else {
    fail("regular polygon args rotation parity")
  }
  assert_eq(
    rp.circumcenter().repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).circumcenter",
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
  assert_eq(
    expr_map_summary(
      try! geometry_regular_polygon(rp).parameter_value(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    try! @sympy_geometry.geometry_eval_str(
      "RegularPolygon(Point2D(0, 0), 1, 4, 0).parameter_value(Point2D(1, 0), t)",
    ),
  )
}

///|
test "geometry.polygon parity enclosure and parameter helpers" {
  let sq = match
    (try! polygon([
      try! point2d(@symcore.int(0), @symcore.int(0)),
      try! point2d(@symcore.int(0), @symcore.int(1)),
      try! point2d(@symcore.int(1), @symcore.int(1)),
      try! point2d(@symcore.int(1), @symcore.int(0)),
    ])) {
    GeometryEntity::Polygon(value) => value
    _ => fail("expected polygon")
  }
  assert_eq(
    expr_map_summary(
      try! sq.parameter_value(
        try! point2d(try! @symcore.rational_from_ints(1, 2), @symcore.int(1)),
        @symcore.symbol("t"),
      ),
    ),
    try! @sympy_geometry.geometry_eval_str(
      "Polygon(Point2D(0, 0), Point2D(0, 1), Point2D(1, 1), Point2D(1, 0)).parameter_value(Point2D(1/2, 1), t)",
    ),
  )
  let encloses_text = (try! sq.encloses(
      geometry_point(
        try! point2d(
          try! @symcore.rational_from_ints(3, 4),
          try! @symcore.rational_from_ints(1, 2),
        ),
      ),
    ))
    .to_string()
    .to_lower()
  assert_eq(
    encloses_text,
    try! @sympy_geometry.geometry_eval_str(
      "Polygon(Point2D(0, 0), Point2D(0, 1), Point2D(1, 1), Point2D(1, 0)).encloses(Point2D(3/4, 1/2))",
    ).to_lower(),
  )
}

///|
test "geometry.triangle parity extended centers" {
  let tri = try! triangle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(0)),
    try! point2d(@symcore.int(0), @symcore.int(1)),
  )
  let nine = try! tri.nine_point_circle()
  assert_eq(
    nine.center().repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Triangle(Point2D(0, 0), Point2D(1, 0), Point2D(0, 1)).nine_point_circle.center",
    ),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(nine.radius()),
    "Triangle(Point2D(0, 0), Point2D(1, 0), Point2D(0, 1)).nine_point_circle.radius",
  )) else {
    fail("triangle nine-point radius parity")
  }
  assert_eq(
    (try! tri.eulerline()).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Triangle(Point2D(0, 0), Point2D(1, 0), Point2D(0, 1)).eulerline",
    ),
  )
}
