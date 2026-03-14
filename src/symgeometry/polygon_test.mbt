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
  let args = rp.args()
  assert_eq(args.0.repr(), "Point2D(0, 0)")
  try! geometry_assert_expr_equal(args.1, "1", "regular polygon args radius")
  assert_eq(args.2, 4)
  try! geometry_assert_expr_equal(args.3, "0", "regular polygon args rotation")
  assert_eq(rp.circumcenter().repr(), "Point2D(0, 0)")
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
  assert_eq(
    expr_map_summary(
      try! geometry_regular_polygon(rp).parameter_value(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    "{t: 0}",
  )
}

///|
test "geometry.polygon enclosure parameter and bisector helpers" {
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
  assert_true(
    try! sq.encloses(
      geometry_point(
        try! point2d(
          try! @symcore.rational_from_ints(3, 4),
          try! @symcore.rational_from_ints(1, 2),
        ),
      ),
    ),
  )
  assert_false(
    try! sq.encloses(
      geometry_point(
        try! point2d(@symcore.int(0), try! @symcore.rational_from_ints(1, 2)),
      ),
    ),
  )
  assert_eq(
    expr_map_summary(
      try! sq.parameter_value(
        try! point2d(try! @symcore.rational_from_ints(1, 2), @symcore.int(1)),
        @symcore.symbol("t"),
      ),
    ),
    "{t: 3/8}",
  )
  let bisectors = try! sq.bisectors()
  let sq_vertices = sq.vertices()
  let corner_bisector = match bisectors.get(sq_vertices[0]) {
    Some(value) => value
    None => fail("missing bisector")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(try! corner_bisector.p2().x()),
    geometry_py_expr_text(try! corner_bisector.p2().y()),
  )) else {
    fail("square corner bisector slope")
  }
  assert_true(
    try! sq.encloses(
      geometry_circle(
        try! circle(
          try! point2d(
            try! @symcore.rational_from_ints(1, 2),
            try! @symcore.rational_from_ints(1, 2),
          ),
          try! @symcore.rational_from_ints(1, 4),
        ),
      ),
    ),
  )
}

///|
test "geometry.triangle extended centers and similarity" {
  let tri = try! triangle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(0)),
    try! point2d(@symcore.int(0), @symcore.int(1)),
  )
  let altitudes = try! tri.altitudes()
  let tri_vertices = tri.vertices()
  assert_eq(
    match altitudes.get(tri_vertices[1]) {
      Some(value) => value.repr()
      None => fail("missing altitude")
    },
    "Segment2D(Point2D(1, 0), Point2D(0, 0))",
  )
  let nine = try! tri.nine_point_circle()
  try! geometry_assert_point_equal(
    nine.center(),
    "1/4",
    "1/4",
    "triangle nine-point center",
  )
  try! geometry_assert_expr_equal(
    nine.radius(),
    "sqrt(2)/4",
    "triangle nine-point radius",
  )
  assert_eq(
    (try! tri.eulerline()).repr(),
    "Line2D(Point2D(0, 0), Point2D(1/2, 1/2))",
  )
  let medians = try! tri.medians()
  assert_eq(
    match medians.get(tri_vertices[0]) {
      Some(value) => value.repr()
      None => fail("missing median")
    },
    "Segment2D(Point2D(0, 0), Point2D(1/2, 1/2))",
  )
}
