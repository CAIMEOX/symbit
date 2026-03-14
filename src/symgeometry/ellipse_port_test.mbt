///|
test "geometry.ellipse parity repr equation and intersections" {
  let ellipse_value = try! ellipse(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(2),
    @symcore.int(1),
  )
  let e = match ellipse_value {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_eq(
    e.repr(),
    try! @sympy_geometry.geometry_eval_repr("Ellipse(Point2D(0, 0), 2, 1)"),
  )
  try! geometry_assert_point_set_equal(
    try! e.intersection(
      geometry_line(
        try! line(
          try! point2d(@symcore.int(1), @symcore.int(-3)),
          try! point2d(@symcore.int(1), @symcore.int(3)),
        ),
      ),
    ),
    [("1", "-sqrt(3)/2"), ("1", "sqrt(3)/2")],
    "ellipse intersection parity",
  )
  assert_eq(
    try! geometry_entities_summary(try! e.intersection(geometry_ellipse(e))),
    "[Ellipse(Point2D(0, 0), 2, 1)]",
  )
}

///|
test "geometry.circle parity repr and intersections" {
  let c = try! circle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
  )
  assert_eq(
    c.repr(),
    try! @sympy_geometry.geometry_eval_repr("Circle(Point2D(0, 0), 1)"),
  )
  try! geometry_assert_point_set_equal(
    try! c.intersection(
      geometry_circle(
        try! circle(
          try! point2d(@symcore.int(1), @symcore.int(0)),
          @symcore.int(1),
        ),
      ),
    ),
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle intersection parity",
  )
}

///|
test "geometry.ellipse parity tangency and parameter helpers" {
  let e = match
    (try! ellipse(
      try! point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(2),
      @symcore.int(1),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_eq(
    expr_map_summary(
      try! e.parameter_value(
        try! point2d(@symcore.int(2), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    try! @sympy_geometry.geometry_eval_str(
      "Ellipse(Point2D(0, 0), 2, 1).parameter_value(Point2D(2, 0), t)",
    ),
  )
  let tangent_points : Array[Point] = []
  for
    tangent in (try! e.tangent_lines(
      try! point2d(@symcore.int(3), @symcore.int(0)),
    )) {
    tangent_points.push(tangent.p2())
  }
  try! geometry_assert_point_set_equal(
    tangent_points.map(geometry_point),
    [("4/3", "-sqrt(5)/3"), ("4/3", "sqrt(5)/3")],
    "ellipse tangent point parity",
  )
  assert_eq(
    (try! e.encloses(
      geometry_segment(
        try! segment(
          try! point2d(@symcore.int(-1), @symcore.int(0)),
          try! point2d(@symcore.int(1), @symcore.int(0)),
        ),
      ),
    ))
    .to_string()
    .to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Ellipse(Point2D(0, 0), 2, 1).encloses(Segment(Point2D(-1, 0), Point2D(1, 0)))",
    ).to_lower(),
  )
}

///|
test "geometry.circle parity tangency and parameter helpers" {
  let c = try! circle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
  )
  try! geometry_assert_expr_equal(
    c.vradius(),
    "Circle(Point2D(0, 0), 1).vradius",
    "circle vradius",
  )
  assert_eq(
    expr_map_summary(
      try! c.parameter_value(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    try! @sympy_geometry.geometry_eval_str(
      "Circle(Point2D(0, 0), 1).parameter_value(Point2D(1, 0), t)",
    ),
  )
  let tangent_points : Array[Point] = []
  for
    tangent in (try! c.tangent_lines(
      try! point2d(@symcore.int(2), @symcore.int(0)),
    )) {
    tangent_points.push(tangent.p2())
  }
  try! geometry_assert_point_set_equal(
    tangent_points.map(geometry_point),
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle tangent point parity",
  )
}
