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
