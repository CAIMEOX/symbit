///|
test "geometry.ellipse core helpers" {
  let ellipse_value = ellipse(
    point2d(@symcore.int(0), @symcore.int(0)),
    @symcore.int(2),
    @symcore.int(1),
  )
  let e = match ellipse_value {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_true(geometry_expr_equal(geometry_py_expr_text(e.area()), "2*pi"))
  let foci = e.foci()
  geometry_assert_point_equal(foci[0], "-sqrt(3)", "0", "ellipse focus 0")
  geometry_assert_point_equal(foci[1], "sqrt(3)", "0", "ellipse focus 1")
  let hits = e.intersection(
    geometry_line(
      line(
        point2d(@symcore.int(1), @symcore.int(-3)),
        point2d(@symcore.int(1), @symcore.int(3)),
      ),
    ),
  )
  geometry_assert_point_set_equal(
    hits,
    [("1", "-sqrt(3)/2"), ("1", "sqrt(3)/2")],
    "ellipse-line intersection",
  )
}

///|
test "geometry.circle specialization and polygon intersection" {
  let c = circle(point2d(@symcore.int(0), @symcore.int(0)), @symcore.int(1))
  assert_true(
    geometry_expr_equal(geometry_py_expr_text(c.circumference()), "2*pi"),
  )
  let hits = c.intersection(
    geometry_circle(
      circle(point2d(@symcore.int(1), @symcore.int(0)), @symcore.int(1)),
    ),
  )
  geometry_assert_point_set_equal(
    hits,
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle-circle intersection",
  )
}

///|
test "geometry.ellipse tangency bounds and parameter values" {
  let e = match
    ellipse(
      point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(2),
      @symcore.int(1),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  geometry_assert_expr_equal(e.major(), "2", "ellipse major")
  geometry_assert_expr_equal(e.minor(), "1", "ellipse minor")
  geometry_assert_expr_equal(e.periapsis(), "2 - sqrt(3)", "ellipse periapsis")
  geometry_assert_expr_equal(e.apoapsis(), "2 + sqrt(3)", "ellipse apoapsis")
  geometry_assert_expr_equal(e.semilatus_rectum(), "1/2", "ellipse semilatus")
  let bounds = e.bounds()
  geometry_assert_point_equal(bounds.0, "-2", "-1", "ellipse bounds min")
  geometry_assert_point_equal(bounds.1, "2", "1", "ellipse bounds max")
  assert_eq(
    expr_map_summary(
      e.parameter_value(
        point2d(@symcore.int(2), @symcore.int(0)),
        @symcore.Expr::Symbol("t"),
      ),
    ),
    "{t: 0}",
  )
  let tangents = e.tangent_lines(point2d(@symcore.int(3), @symcore.int(0)))
  let tangent_points : Array[GeometryEntity] = []
  for tangent in tangents {
    assert_true(tangent.contains(point2d(@symcore.int(3), @symcore.int(0))))
    tangent_points.push(geometry_point(tangent.p2()))
  }
  geometry_assert_point_set_equal(
    tangent_points,
    [("4/3", "-sqrt(5)/3"), ("4/3", "sqrt(5)/3")],
    "ellipse tangent touch points",
  )
  assert_true(
    e.is_tangent(
      geometry_line(
        line(
          point2d(@symcore.int(2), @symcore.int(0)),
          point2d(@symcore.int(2), @symcore.int(1)),
        ),
      ),
    ),
  )
  assert_true(
    e.encloses(
      geometry_segment(
        segment(
          point2d(@symcore.int(-1), @symcore.int(0)),
          point2d(@symcore.int(1), @symcore.int(0)),
        ),
      ),
    ),
  )
}

///|
test "geometry.circle tangency bounds and parameter values" {
  let c = circle(point2d(@symcore.int(0), @symcore.int(0)), @symcore.int(1))
  assert_eq(@symprint.pretty_string(c.vradius()), "1")
  let bounds = c.bounds()
  geometry_assert_point_equal(bounds.0, "-1", "-1", "circle bounds min")
  geometry_assert_point_equal(bounds.1, "1", "1", "circle bounds max")
  assert_eq(
    expr_map_summary(
      c.parameter_value(
        point2d(@symcore.int(1), @symcore.int(0)),
        @symcore.Expr::Symbol("t"),
      ),
    ),
    "{t: 0}",
  )
  let tangents = c.tangent_lines(point2d(@symcore.int(2), @symcore.int(0)))
  let tangent_points : Array[GeometryEntity] = []
  for tangent in tangents {
    assert_true(tangent.contains(point2d(@symcore.int(2), @symcore.int(0))))
    tangent_points.push(geometry_point(tangent.p2()))
  }
  geometry_assert_point_set_equal(
    tangent_points,
    [("1/2", "-sqrt(3)/2"), ("1/2", "sqrt(3)/2")],
    "circle tangent touch points",
  )
  assert_false(
    c.encloses(
      geometry_segment(
        segment(
          point2d(@symcore.int(0), @symcore.int(0)),
          point2d(@symcore.int(1), @symcore.int(0)),
        ),
      ),
    ),
  )
}

///|
test "geometry.ellipse higher helpers" {
  let e = match
    ellipse(
      point2d(@symcore.int(0), @symcore.int(0)),
      @symcore.int(5),
      @symcore.int(4),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected ellipse")
  }
  assert_eq(
    expr_triple_summary(e.second_moment_of_area()),
    "(80*pi, 125*pi, 0)",
  )
  assert_eq(
    expr_triple_summary(
      e.second_moment_of_area(
        point=Some(point2d(@symcore.int(6), @symcore.int(5))),
      ),
    ),
    "(580*pi, 845*pi, 600*pi)",
  )
  assert_eq(expr_pair_summary(e.section_modulus()), "(20*pi, 25*pi)")
  assert_eq(geometry_py_expr_text(e.polar_second_moment_of_area()), "205*pi")
  let c = circle(point2d(@symcore.int(3), @symcore.int(7)), @symcore.int(8))
  assert_eq(expr_pair_summary(c.section_modulus()), "(128*pi, 128*pi)")
  assert_eq(geometry_py_expr_text(c.polar_second_moment_of_area()), "2048*pi")
}

///|
test "geometry.ellipse auxiliary director evolute reflect and random" {
  let c = point2d(@symcore.int(1), @symcore.int(2))
  let ellipse_obj = match
    ellipse(c, @symcore.Expr::Symbol("a"), @symcore.Expr::Symbol("b")) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected symbolic ellipse")
  }
  assert_eq(
    ellipse_obj.auxiliary_circle().repr(),
    "Circle(Point2D(1, 2), Max(a, b))",
  )
  assert_eq(
    ellipse_obj.director_circle().repr(),
    "Circle(Point2D(1, 2), sqrt((a**2 + b**2)))",
  )
  let evolute = ellipse_obj.evolute()
  geometry_assert_expr_equal(
    evolute, "(a*(x - 1))**(2/3) + (b*(y - 2))**(2/3) - ((a**2 - b**2))**(2/3)",
    "ellipse evolute",
  )
  let numeric = match
    ellipse(
      point2d(@symcore.int(1), @symcore.int(0)),
      @symcore.int(1),
      @symcore.int(2),
    ) {
    GeometryEntity::Ellipse(value) => value
    _ => fail("expected numeric ellipse")
  }
  let horizontal = line(
    point2d(@symcore.int(0), @symcore.int(0)),
    point2d(@symcore.int(1), @symcore.int(0)),
  )
  let vertical = line(
    point2d(@symcore.int(1), @symcore.int(-1)),
    point2d(@symcore.int(1), @symcore.int(1)),
  )
  assert_eq(numeric.reflect(horizontal).repr(), "Ellipse(Point2D(1, 0), -1, 2)")
  assert_eq(numeric.reflect(vertical).repr(), "Ellipse(Point2D(1, 0), -1, 2)")
  assert_eq(
    circle(point2d(@symcore.int(0), @symcore.int(1)), @symcore.int(1))
    .reflect(
      line(
        point2d(@symcore.int(0), @symcore.int(0)),
        point2d(@symcore.int(1), @symcore.int(1)),
      ),
    )
    .repr(),
    "Circle(Point2D(1, 0), -1)",
  )
  let random_pt = numeric.random_point(seed=Some(0))
  assert_true(numeric.contains_point(random_pt))
}

///|
test "geometry.ellipse normal lines" {
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
    "[" +
    e
    .normal_lines(point2d(@symcore.int(0), @symcore.int(0)))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    "[Line2D(Point2D(0, 0), Point2D(0, 1)), Line2D(Point2D(0, 0), Point2D(1, 0))]",
  )
  assert_eq(
    "[" +
    e
    .normal_lines(point2d(@symcore.int(1), @symcore.int(0)))
    .map(line_obj => line_obj.repr())
    .join(", ") +
    "]",
    "[Line2D(Point2D(0, 0), Point2D(1, 0))]",
  )
  let off_axis = e.normal_lines(
    point2d(@symcore.int(1), @symcore.int(1)),
    prec=Some(2),
  )
  assert_eq(off_axis.length(), 2)
  geometry_assert_point_close(
    off_axis[0].p1(),
    "-2",
    "-1/5",
    "0.05",
    "ellipse normal off-axis 0",
  )
  geometry_assert_point_close(
    off_axis[1].p1(),
    "97/100",
    "-22/25",
    "0.05",
    "ellipse normal off-axis 1",
  )
}
