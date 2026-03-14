///|
test "geometry.point parity repr and distance" {
  let p = try! point2d(@symcore.symbol("x"), @symcore.int(2))
  let q = try! point2d(@symcore.int(1), @symcore.int(5))
  assert_eq(p.repr(), try! @sympy_geometry.geometry_eval_repr("Point2D(x, 2)"))
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! p.distance(q)),
    "Point2D(x, 2).distance(Point2D(1, 5))",
  )) else {
    fail("point distance parity")
  }
}

///|
test "geometry.point parity translate rotate scale" {
  let p = try! point2d(@symcore.int(2), @symcore.int(1))
  assert_eq(
    p.translate([@symcore.int(-1), @symcore.int(3)]).repr(),
    try! @sympy_geometry.geometry_eval_repr("Point2D(2, 1).translate(-1, 3)"),
  )
  let rotated = p.rotate(@symcore.symbol("pi"))
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! rotated.x()),
    "Point2D(2, 1).rotate(pi).x",
  )) else {
    fail("point rotate x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! rotated.y()),
    "Point2D(2, 1).rotate(pi).y",
  )) else {
    fail("point rotate y parity")
  }
  assert_eq(
    p.scale([@symcore.int(3), @symcore.int(2)]).repr(),
    try! @sympy_geometry.geometry_eval_repr("Point2D(2, 1).scale(3, 2)"),
  )
}

///|
test "geometry.point parity projection and norm helpers" {
  let p = try! point2d(@symcore.int(1), @symcore.int(2))
  let q = try! point2d(@symcore.int(2), @symcore.int(5))
  assert_eq(
    (try! p.origin()).repr(),
    try! @sympy_geometry.geometry_eval_repr("Point2D(1, 2).origin"),
  )
  assert_eq(
    (try! p.orthogonal_direction()).repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Point2D(1, 2).orthogonal_direction",
    ),
  )
  let projected = try! p.project(q)
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(try! projected.x()),
    "Point.project(Point2D(1, 2), Point2D(2, 5)).x",
  )) else {
    fail("point project x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(try! projected.y()),
    "Point.project(Point2D(1, 2), Point2D(2, 5)).y",
  )) else {
    fail("point project y parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(
      p.taxicab_distance(try! point2d(@symcore.int(3), @symcore.int(3))),
    ),
    "Point2D(1, 2).taxicab_distance(Point2D(3, 3))",
  )) else {
    fail("point taxicab parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(
      p.canberra_distance(try! point2d(@symcore.int(3), @symcore.int(3))),
    ),
    "Point2D(1, 2).canberra_distance(Point2D(3, 3))",
  )) else {
    fail("point canberra parity")
  }
  let unit_pt = try! (try! point2d(@symcore.int(3), @symcore.int(4))).unit()
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(try! unit_pt.x()),
    "Point2D(3, 4).unit.x",
  )) else {
    fail("point unit x parity")
  }
  guard (try! @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(try! unit_pt.y()),
    "Point2D(3, 4).unit.y",
  )) else {
    fail("point unit y parity")
  }
  assert_eq(
    p.is_nonzero().to_string().to_lower(),
    try! @sympy_geometry.geometry_eval_str("Point2D(1, 2).is_nonzero").to_lower(),
  )
}

///|
test "geometry.point parity equals intersection and cyclic helpers" {
  let p = try! point2d(@symcore.int(1), @symcore.int(1))
  let q = try! point2d(@symcore.int(1), @symcore.int(1))
  assert_eq(
    p.equals(q).to_string().to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Point2D(1, 1).equals(Point2D(1, 1))",
    ).to_lower(),
  )
  assert_eq(
    (try! p.is_scalar_multiple(try! point2d(@symcore.int(2), @symcore.int(2))))
    .to_string()
    .to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Point2D(1, 1).is_scalar_multiple(Point2D(2, 2))",
    ).to_lower(),
  )
  assert_eq(
    (try! (try! point2d(@symcore.int(1), @symcore.int(0))).is_concyclic([
      try! point2d(@symcore.int(0), @symcore.int(1)),
      try! point2d(@symcore.int(-1), @symcore.int(0)),
      try! point2d(@symcore.int(0), @symcore.int(-1)),
    ]))
    .to_string()
    .to_lower(),
    try! @sympy_geometry.geometry_eval_str(
      "Point2D(1, 0).is_concyclic(Point2D(0, 1), Point2D(-1, 0), Point2D(0, -1))",
    ).to_lower(),
  )
  let hit = try! p.intersection(
    geometry_line(
      try! line(
        try! point2d(@symcore.int(1), @symcore.int(0)),
        try! point2d(@symcore.int(1), @symcore.int(3)),
      ),
    ),
  )
  assert_eq(hit.length(), 1)
  assert_eq(
    try! geometry_entities_summary(hit),
    "[" +
    (try! @sympy_geometry.geometry_eval_repr(
      "Point2D(1, 1).intersection(Line(Point2D(1, 0), Point2D(1, 3)))[0]",
    )) +
    "]",
  )
}
