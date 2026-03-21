///|
test "geometry.ellipse parity repr equation and intersections" {
  let ellipse_value = ellipse(
    point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(2),
    @symcore.int(1),
  )
  let e = match ellipse_value {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_eq(e.repr(), geometry_eval_repr("Ellipse(Point2D(0, 0), 2, 1)"))
  geometry_assert_point_set_equal(
    e.intersection(
      geometry_line(
        line(
          point2d(@symcore.int(1), @symcore.int(-3)),
          point2d(@symcore.int(1), @symcore.int(3)),
        ),
      ),
    ),
    [("1", "-sqrt(3)/2"), ("1", "sqrt(3)/2")],
    "ellipse intersection parity",
  )
  assert_eq(
    geometry_entities_summary(e.intersection(geometry_ellipse(e))),
    "[Ellipse(Point2D(0, 0), 2, 1)]",
  )
}

///|
test "geometry.circle parity repr and intersections" {
  let c = circle(point2d(@symcore.int(0), @symcore.int(0)), @symcore.int(1))
  assert_eq(c.repr(), geometry_eval_repr("Circle(Point2D(0, 0), 1)"))
  geometry_assert_point_set_equal(
    c.intersection(
      geometry_circle(
        circle(point2d(@symcore.int(1), @symcore.int(0)), @symcore.int(1)),
      ),
    ),
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle intersection parity",
  )
}

///|
test "geometry.ellipse parity tangency and parameter helpers" {
  let e = match
    ellipse(
      point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(2),
      @symcore.int(1),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_eq(
    expr_map_summary(
      e.parameter_value(
        point2d(@symcore.int(2), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    geometry_eval_str(
      "Ellipse(Point2D(0, 0), 2, 1).parameter_value(Point2D(2, 0), t)",
    ),
  )
  let tangent_points : Array[Point] = []
  for tangent in e.tangent_lines(point2d(@symcore.int(3), @symcore.int(0))) {
    tangent_points.push(tangent.p2())
  }
  geometry_assert_point_set_equal(
    tangent_points.map(geometry_point),
    [("4/3", "-sqrt(5)/3"), ("4/3", "sqrt(5)/3")],
    "ellipse tangent point parity",
  )
  assert_eq(
    e
    .encloses(
      geometry_segment(
        segment(
          point2d(@symcore.int(-1), @symcore.int(0)),
          point2d(@symcore.int(1), @symcore.int(0)),
        ),
      ),
    )
    .to_string()
    .to_lower(),
    geometry_eval_str(
      "Ellipse(Point2D(0, 0), 2, 1).encloses(Segment(Point2D(-1, 0), Point2D(1, 0)))",
    ).to_lower(),
  )
}

///|
test "geometry.circle parity tangency and parameter helpers" {
  let c = circle(point2d(@symcore.int(0), @symcore.int(0)), @symcore.int(1))
  geometry_assert_expr_equal(
    c.vradius(),
    "Circle(Point2D(0, 0), 1).vradius",
    "circle vradius",
  )
  assert_eq(
    expr_map_summary(
      c.parameter_value(
        point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.symbol("t"),
      ),
    ),
    geometry_eval_str(
      "Circle(Point2D(0, 0), 1).parameter_value(Point2D(1, 0), t)",
    ),
  )
  let tangent_points : Array[Point] = []
  for tangent in c.tangent_lines(point2d(@symcore.int(2), @symcore.int(0))) {
    tangent_points.push(tangent.p2())
  }
  geometry_assert_point_set_equal(
    tangent_points.map(geometry_point),
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle tangent point parity",
  )
}

///|
test "geometry.ellipse parity formula helpers" {
  let e = match
    ellipse(
      point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(5),
      @symcore.int(4),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  let second = e.second_moment_of_area()
  geometry_assert_expr_equal(
    second.0,
    geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area())[0]",
    ),
    "ellipse second moment parity.0",
  )
  geometry_assert_expr_equal(
    second.1,
    geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area())[1]",
    ),
    "ellipse second moment parity.1",
  )
  geometry_assert_expr_equal(
    second.2,
    geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area())[2]",
    ),
    "ellipse second moment parity.2",
  )
  let shifted_second = e.second_moment_of_area(
    point=Some(point2d(@symcore.int(6), @symcore.int(5))),
  )
  geometry_assert_expr_equal(
    shifted_second.0,
    geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area(Point2D(6, 5)))[0]",
    ),
    "ellipse shifted second moment parity.0",
  )
  geometry_assert_expr_equal(
    shifted_second.1,
    geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area(Point2D(6, 5)))[1]",
    ),
    "ellipse shifted second moment parity.1",
  )
  geometry_assert_expr_equal(
    shifted_second.2,
    geometry_eval_str(
      "(Ellipse(Point2D(0, 0), 5, 4).second_moment_of_area(Point2D(6, 5)))[2]",
    ),
    "ellipse shifted second moment parity.2",
  )
  let section = e.section_modulus()
  geometry_assert_expr_equal(
    section.0,
    geometry_eval_str("(Ellipse(Point2D(0, 0), 5, 4).section_modulus())[0]"),
    "ellipse section modulus parity.0",
  )
  geometry_assert_expr_equal(
    section.1,
    geometry_eval_str("(Ellipse(Point2D(0, 0), 5, 4).section_modulus())[1]"),
    "ellipse section modulus parity.1",
  )
  geometry_assert_expr_equal(
    e.polar_second_moment_of_area(),
    "Ellipse(Point2D(0, 0), 5, 4).polar_second_moment_of_area()",
    "ellipse polar second moment parity",
  )
  let symbolic = match
    ellipse(
      point2d(@symcore.int(1), @symcore.int(2)),
      @symcore.symbol("a"),
      @symcore.symbol("b"),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected symbolic ellipse")
  }
  assert_eq(
    symbolic.auxiliary_circle().repr(),
    geometry_eval_repr("Ellipse(Point2D(1, 2), a, b).auxiliary_circle()"),
  )
  let director = symbolic.director_circle()
  assert_eq(director.center().repr(), "Point2D(1, 2)")
  geometry_assert_expr_equal(
    director.radius(),
    "sqrt(a**2 + b**2)",
    "ellipse director circle parity.radius",
  )
  geometry_assert_expr_equal(
    symbolic.evolute(),
    geometry_eval_str("Ellipse(Point2D(1, 2), a, b).evolute()"),
    "ellipse evolute parity",
  )
}

///|
test "geometry.ellipse parity reflect and exact normals" {
  let e = match
    ellipse(
      point2d(@symcore.int(1), @symcore.int(0)),
      @symcore.int(1),
      @symcore.int(2),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  let horizontal = line(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(0)),
  )
  let vertical = line(
    point2d(@symcore.int(1), @symcore.int(-1)),
    point2d(@symcore.int(1), @symcore.int(1)),
  )
  assert_eq(
    e.reflect(horizontal).repr(),
    geometry_eval_repr(
      "Ellipse(Point2D(1, 0), 1, 2).reflect(Line2D(Point2D(0, 0), Point2D(1, 0)))",
    ),
  )
  assert_eq(
    e.reflect(vertical).repr(),
    geometry_eval_repr(
      "Ellipse(Point2D(1, 0), 1, 2).reflect(Line2D(Point2D(1, -1), Point2D(1, 1)))",
    ),
  )
  let circle_obj = circle(
    point2d(@symcore.int(0), @symcore.int(1)),
    @symcore.int(1),
  )
  assert_eq(
    circle_obj
    .reflect(
      line(
        point2d(@symcore.int(0), @symcore.int(0)),
        point2d(@symcore.int(1), @symcore.int(1)),
      ),
    )
    .repr(),
    geometry_eval_repr(
      "Circle(Point2D(0, 1), 1).reflect(Line2D(Point2D(0, 0), Point2D(1, 1)))",
    ),
  )
  let exact = match
    ellipse(
      point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(2),
      @symcore.int(1),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected exact ellipse")
  }
  assert_eq(
    "[" +
    exact
    .normal_lines(point2d(@symcore.int(0), @symcore.int(0)))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    geometry_eval_str(
      "repr(Ellipse(Point2D(0, 0), 2, 1).normal_lines(Point2D(0, 0)))",
    ),
  )
  assert_eq(
    "[" +
    exact
    .normal_lines(point2d(@symcore.int(1), @symcore.int(0)))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    geometry_eval_str(
      "repr(Ellipse(Point2D(0, 0), 2, 1).normal_lines(Point2D(1, 0)))",
    ),
  )
}
