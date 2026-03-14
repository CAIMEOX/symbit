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
