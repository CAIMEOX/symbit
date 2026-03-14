///|
test "geometry.ellipse core helpers" {
  let ellipse_value = try! ellipse(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(2),
    @symcore.int(1),
  )
  let e = match ellipse_value {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(e.area()),
    "2*pi",
  )) else {
    fail("ellipse area")
  }
  let foci = try! e.foci()
  try! geometry_assert_point_equal(foci[0], "-sqrt(3)", "0", "ellipse focus 0")
  try! geometry_assert_point_equal(foci[1], "sqrt(3)", "0", "ellipse focus 1")
  let hits = try! e.intersection(
    geometry_line(
      try! line(
        try! point2d(@symcore.int(1), @symcore.int(-3)),
        try! point2d(@symcore.int(1), @symcore.int(3)),
      ),
    ),
  )
  try! geometry_assert_point_set_equal(
    hits,
    [("1", "-sqrt(3)/2"), ("1", "sqrt(3)/2")],
    "ellipse-line intersection",
  )
}

///|
test "geometry.circle specialization and polygon intersection" {
  let c = try! circle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(c.circumference()),
    "2*pi",
  )) else {
    fail("circle circumference")
  }
  let hits = try! c.intersection(
    geometry_circle(
      try! circle(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.int(1),
      ),
    ),
  )
  try! geometry_assert_point_set_equal(
    hits,
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle-circle intersection",
  )
}

///|
test "geometry.ellipse tangency bounds and parameter values" {
  let e = match
    (try! ellipse(
      try! point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(2),
      @symcore.int(1),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  try! geometry_assert_expr_equal(e.major(), "2", "ellipse major")
  try! geometry_assert_expr_equal(e.minor(), "1", "ellipse minor")
  try! geometry_assert_expr_equal(
    e.periapsis(),
    "2 - sqrt(3)",
    "ellipse periapsis",
  )
  try! geometry_assert_expr_equal(
    e.apoapsis(),
    "2 + sqrt(3)",
    "ellipse apoapsis",
  )
  try! geometry_assert_expr_equal(
    e.semilatus_rectum(),
    "1/2",
    "ellipse semilatus",
  )
  let bounds = try! e.bounds()
  try! geometry_assert_point_equal(bounds.0, "-2", "-1", "ellipse bounds min")
  try! geometry_assert_point_equal(bounds.1, "2", "1", "ellipse bounds max")
  assert_eq(
    expr_map_summary(
      try! e.parameter_value(
        try! point2d(@symcore.int(2), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    "{t: 0}",
  )
  let tangents = try! e.tangent_lines(
    try! point2d(@symcore.int(3), @symcore.int(0)),
  )
  let tangent_points : Array[GeometryEntity] = []
  for tangent in tangents {
    assert_true(
      try! tangent.contains(try! point2d(@symcore.int(3), @symcore.int(0))),
    )
    tangent_points.push(geometry_point(tangent.p2()))
  }
  try! geometry_assert_point_set_equal(
    tangent_points,
    [("4/3", "-sqrt(5)/3"), ("4/3", "sqrt(5)/3")],
    "ellipse tangent touch points",
  )
  assert_true(
    try! e.is_tangent(
      geometry_line(
        try! line(
          try! point2d(@symcore.int(2), @symcore.int(0)),
          try! point2d(@symcore.int(2), @symcore.int(1)),
        ),
      ),
    ),
  )
  assert_true(
    try! e.encloses(
      geometry_segment(
        try! segment(
          try! point2d(@symcore.int(-1), @symcore.int(0)),
          try! point2d(@symcore.int(1), @symcore.int(0)),
        ),
      ),
    ),
  )
}

///|
test "geometry.circle tangency bounds and parameter values" {
  let c = try! circle(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(1),
  )
  assert_eq(@symprint.to_string(c.vradius()), "1")
  let bounds = try! c.bounds()
  try! geometry_assert_point_equal(bounds.0, "-1", "-1", "circle bounds min")
  try! geometry_assert_point_equal(bounds.1, "1", "1", "circle bounds max")
  assert_eq(
    expr_map_summary(
      try! c.parameter_value(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    "{t: 0}",
  )
  let tangents = try! c.tangent_lines(
    try! point2d(@symcore.int(2), @symcore.int(0)),
  )
  let tangent_points : Array[GeometryEntity] = []
  for tangent in tangents {
    assert_true(
      try! tangent.contains(try! point2d(@symcore.int(2), @symcore.int(0))),
    )
    tangent_points.push(geometry_point(tangent.p2()))
  }
  try! geometry_assert_point_set_equal(
    tangent_points,
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle tangent touch points",
  )
  assert_false(
    try! c.encloses(
      geometry_segment(
        try! segment(
          try! point2d(@symcore.int(0), @symcore.int(0)),
          try! point2d(@symcore.int(1), @symcore.int(0)),
        ),
      ),
    ),
  )
}

///|
test "geometry.ellipse higher helpers" {
  let e = match
    (try! ellipse(
      try! point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(5),
      @symcore.int(4),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_eq(
    expr_triple_summary(try! e.second_moment_of_area()),
    "(80*pi, 125*pi, 0)",
  )
  assert_eq(
    expr_triple_summary(
      try! e.second_moment_of_area(
        point=Some(try! point2d(@symcore.int(6), @symcore.int(5))),
      ),
    ),
    "(580*pi, 845*pi, 600*pi)",
  )
  assert_eq(expr_pair_summary(try! e.section_modulus()), "(20*pi, 25*pi)")
  assert_eq(
    geometry_py_expr_text(try! e.polar_second_moment_of_area()),
    "205*pi",
  )
  let c = try! circle(
    try! point2d(@symcore.int(3), @symcore.int(7)),
    @symcore.int(8),
  )
  assert_eq(expr_pair_summary(try! c.section_modulus()), "(128*pi, 128*pi)")
  assert_eq(
    geometry_py_expr_text(try! c.polar_second_moment_of_area()),
    "2048*pi",
  )
}

///|
test "geometry.ellipse auxiliary director evolute reflect and random" {
  let c = try! point2d(@symcore.int(1), @symcore.int(2))
  let ellipse_obj = match
    (try! ellipse(c, @symcore.symbol("a"), @symcore.symbol("b"))) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected symbolic ellipse")
  }
  assert_eq(
    (try! ellipse_obj.auxiliary_circle()).repr(),
    "Circle(Point2D(1, 2), Max(a, b))",
  )
  assert_eq(
    (try! ellipse_obj.director_circle()).repr(),
    "Circle(Point2D(1, 2), sqrt((a**2 + b**2)))",
  )
  let evolute = try! ellipse_obj.evolute()
  try! geometry_assert_expr_equal(
    evolute, "(a*(x - 1))**(2/3) + (b*(y - 2))**(2/3) - ((a**2 - b**2))**(2/3)",
    "ellipse evolute",
  )
  let numeric = match
    (try! ellipse(
      try! point2d(@symcore.int(1), @symcore.int(0)),
      @symcore.int(1),
      @symcore.int(2),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected numeric ellipse")
  }
  let horizontal = try! line(
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(1), @symcore.int(0)),
  )
  let vertical = try! line(
    try! point2d(@symcore.int(1), @symcore.int(-1)),
    try! point2d(@symcore.int(1), @symcore.int(1)),
  )
  assert_eq(
    (try! numeric.reflect(horizontal)).repr(),
    "Ellipse(Point2D(1, 0), -1, 2)",
  )
  assert_eq(
    (try! numeric.reflect(vertical)).repr(),
    "Ellipse(Point2D(1, 0), -1, 2)",
  )
  assert_eq(
    (try! (try! circle(
      try! point2d(@symcore.int(0), @symcore.int(1)),
      @symcore.int(1),
    )).reflect(
      try! line(
        try! point2d(@symcore.int(0), @symcore.int(0)),
        try! point2d(@symcore.int(1), @symcore.int(1)),
      ),
    )).repr(),
    "Circle(Point2D(1, 0), -1)",
  )
  let random_pt = try! numeric.random_point(seed=Some(0))
  assert_true(try! numeric.contains_point(random_pt))
}

///|
test "geometry.ellipse normal lines" {
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
    "[" +
    (try! e.normal_lines(try! point2d(@symcore.int(0), @symcore.int(0))))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    "[Line2D(Point2D(0, 0), Point2D(0, 1)), Line2D(Point2D(0, 0), Point2D(1, 0))]",
  )
  assert_eq(
    "[" +
    (try! e.normal_lines(try! point2d(@symcore.int(1), @symcore.int(0))))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    "[Line2D(Point2D(0, 0), Point2D(1, 0))]",
  )
  let off_axis = try! e.normal_lines(
    try! point2d(@symcore.int(1), @symcore.int(1)),
    prec=Some(2),
  )
  assert_eq(off_axis.length(), 2)
  try! geometry_assert_point_close(
    off_axis[0].p1(),
    "-2",
    "-1/5",
    "0.05",
    "ellipse normal off-axis 0",
  )
  try! geometry_assert_point_close(
    off_axis[1].p1(),
    "97/100",
    "-22/25",
    "0.05",
    "ellipse normal off-axis 1",
  )
}
