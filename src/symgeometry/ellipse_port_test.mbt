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
