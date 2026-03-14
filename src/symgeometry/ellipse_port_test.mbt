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

///|
test "geometry.ellipse parity formula helpers" {
  let e = match
    (try! ellipse(
      try! point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(5),
      @symcore.int(4),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  let second = try! e.second_moment_of_area()
  try! geometry_assert_expr_equal(
    second.0,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area())[0]",
    ),
    "ellipse second moment parity.0",
  )
  try! geometry_assert_expr_equal(
    second.1,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area())[1]",
    ),
    "ellipse second moment parity.1",
  )
  try! geometry_assert_expr_equal(
    second.2,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area())[2]",
    ),
    "ellipse second moment parity.2",
  )
  let shifted_second = try! e.second_moment_of_area(
    point=Some(try! point2d(@symcore.int(6), @symcore.int(5))),
  )
  try! geometry_assert_expr_equal(
    shifted_second.0,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area(Point2D(6, 5)))[0]",
    ),
    "ellipse shifted second moment parity.0",
  )
  try! geometry_assert_expr_equal(
    shifted_second.1,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area(Point2D(6, 5)))[1]",
    ),
    "ellipse shifted second moment parity.1",
  )
  try! geometry_assert_expr_equal(
    shifted_second.2,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area(Point2D(6, 5)))[2]",
    ),
    "ellipse shifted second moment parity.2",
  )
  let section = try! e.section_modulus()
  try! geometry_assert_expr_equal(
    section.0,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).section_modulus())[0]",
    ),
    "ellipse section modulus parity.0",
  )
  try! geometry_assert_expr_equal(
    section.1,
    try! @sympy_geometry.geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).section_modulus())[1]",
    ),
    "ellipse section modulus parity.1",
  )
  try! geometry_assert_expr_equal(
    try! e.polar_second_moment_of_area(),
    "Ellipse(Point2D(0, 0), 5, 4).polar_second_moment_of_area()",
    "ellipse polar second moment parity",
  )
  let symbolic = match
    (try! ellipse(
      try! point2d(@symcore.int(1), @symcore.int(2)),
      @symcore.symbol("a"),
      @symcore.symbol("b"),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected symbolic ellipse")
  }
  assert_eq(
    (try! symbolic.auxiliary_circle()).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Ellipse(Point2D(1, 2), a, b).auxiliary_circle()",
    ),
  )
  let director = try! symbolic.director_circle()
  assert_eq(director.center().repr(), "Point2D(1, 2)")
  try! geometry_assert_expr_equal(
    director.radius(),
    "sqrt(a**2 + b**2)",
    "ellipse director circle parity.radius",
  )
  try! geometry_assert_expr_equal(
    try! symbolic.evolute(),
    try! @sympy_geometry.geometry_eval_str(
      "Ellipse(Point2D(1, 2), a, b).evolute()",
    ),
    "ellipse evolute parity",
  )
}

///|
test "geometry.ellipse parity reflect and exact normals" {
  let e = match
    (try! ellipse(
      try! point2d(@symcore.int(1), @symcore.int(0)),
      @symcore.int(1),
      @symcore.int(2),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
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
    (try! e.reflect(horizontal)).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Ellipse(Point2D(1, 0), 1, 2).reflect(Line2D(Point2D(0, 0), Point2D(1, 0)))",
    ),
  )
  assert_eq(
    (try! e.reflect(vertical)).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Ellipse(Point2D(1, 0), 1, 2).reflect(Line2D(Point2D(1, -1), Point2D(1, 1)))",
    ),
  )
  let circle_obj = try! circle(
    try! point2d(@symcore.int(0), @symcore.int(1)),
    @symcore.int(1),
  )
  assert_eq(
    (try! circle_obj.reflect(
      try! line(
        try! point2d(@symcore.int(0), @symcore.int(0)),
        try! point2d(@symcore.int(1), @symcore.int(1)),
      ),
    )).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Circle(Point2D(0, 1), 1).reflect(Line2D(Point2D(0, 0), Point2D(1, 1)))",
    ),
  )
  let exact = match
    (try! ellipse(
      try! point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(2),
      @symcore.int(1),
    )) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected exact ellipse")
  }
  assert_eq(
    "[" +
    (try! exact.normal_lines(try! point2d(@symcore.int(0), @symcore.int(0))))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    try! @sympy_geometry.geometry_eval_str(
      "repr(Ellipse(Point2D(0, 0), 2, 1).normal_lines(Point2D(0, 0)))",
    ),
  )
  assert_eq(
    "[" +
    (try! exact.normal_lines(try! point2d(@symcore.int(1), @symcore.int(0))))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    try! @sympy_geometry.geometry_eval_str(
      "repr(Ellipse(Point2D(0, 0), 2, 1).normal_lines(Point2D(1, 0)))",
    ),
  )
}
