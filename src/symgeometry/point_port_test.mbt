///|
test "geometry.point parity repr and distance" {
  let p = point2d(@symcore.symbol("x"), @symcore.int(2))
  let q = point2d(@symcore.int(1), @symcore.int(5))
  assert_eq(p.repr(), @sympy_geometry.geometry_eval_repr("Point2D(x, 2)"))
  guard @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(p.distance(q)),
    "Point2D(x, 2).distance(Point2D(1, 5))",
  ) else {
    fail("point distance parity")
  }
}

///|
test "geometry.point parity translate rotate scale" {
  let p = point2d(@symcore.int(2), @symcore.int(1))
  assert_eq(
    p.translate([@symcore.int(-1), @symcore.int(3)]).repr(),
    @sympy_geometry.geometry_eval_repr("Point2D(2, 1).translate(-1, 3)"),
  )
  let rotated = p.rotate(@symcore.symbol("pi"))
  guard @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(rotated.x()),
    "Point2D(2, 1).rotate(pi).x",
  ) else {
    fail("point rotate x parity")
  }
  guard @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(rotated.y()),
    "Point2D(2, 1).rotate(pi).y",
  ) else {
    fail("point rotate y parity")
  }
  assert_eq(
    p.scale([@symcore.int(3), @symcore.int(2)]).repr(),
    @sympy_geometry.geometry_eval_repr("Point2D(2, 1).scale(3, 2)"),
  )
}

///|
test "geometry.point parity projection and norm helpers" {
  let p = point2d(@symcore.int(1), @symcore.int(2))
  let q = point2d(@symcore.int(2), @symcore.int(5))
  assert_eq(
    p.origin().repr(),
    @sympy_geometry.geometry_eval_repr("Point2D(1, 2).origin"),
  )
  assert_eq(
    p.orthogonal_direction().repr(),
    @sympy_geometry.geometry_eval_repr("Point2D(1, 2).orthogonal_direction"),
  )
  let projected = p.project(q)
  guard @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(projected.x()),
    "Point.project(Point2D(1, 2), Point2D(2, 5)).x",
  ) else {
    fail("point project x parity")
  }
  guard @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(projected.y()),
    "Point.project(Point2D(1, 2), Point2D(2, 5)).y",
  ) else {
    fail("point project y parity")
  }
  guard @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(
      p.taxicab_distance(point2d(@symcore.int(3), @symcore.int(3))),
    ),
    "Point2D(1, 2).taxicab_distance(Point2D(3, 3))",
  ) else {
    fail("point taxicab parity")
  }
  guard @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(
      p.canberra_distance(point2d(@symcore.int(3), @symcore.int(3))),
    ),
    "Point2D(1, 2).canberra_distance(Point2D(3, 3))",
  ) else {
    fail("point canberra parity")
  }
  let unit_pt = point2d(@symcore.int(3), @symcore.int(4)).unit()
  guard @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(unit_pt.x()),
    "Point2D(3, 4).unit.x",
  ) else {
    fail("point unit x parity")
  }
  guard @sympy_geometry.geometry_expr_equal(
    geometry_py_expr_text(unit_pt.y()),
    "Point2D(3, 4).unit.y",
  ) else {
    fail("point unit y parity")
  }
  assert_eq(
    p.is_nonzero().to_string().to_lower(),
    @sympy_geometry.geometry_eval_str("Point2D(1, 2).is_nonzero").to_lower(),
  )
}

///|
test "geometry.point parity equals intersection and cyclic helpers" {
  let p = point2d(@symcore.int(1), @symcore.int(1))
  let q = point2d(@symcore.int(1), @symcore.int(1))
  assert_eq(
    p.equals(q).to_string().to_lower(),
    @sympy_geometry.geometry_eval_str("Point2D(1, 1).equals(Point2D(1, 1))").to_lower(),
  )
  assert_eq(
    p
    .is_scalar_multiple(point2d(@symcore.int(2), @symcore.int(2)))
    .to_string()
    .to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Point2D(1, 1).is_scalar_multiple(Point2D(2, 2))",
    ).to_lower(),
  )
  assert_eq(
    point2d(@symcore.int(1), @symcore.int(0))
    .is_concyclic([
      point2d(@symcore.int(0), @symcore.int(1)),
      point2d(@symcore.int(-1), @symcore.int(0)),
      point2d(@symcore.int(0), @symcore.int(-1)),
    ])
    .to_string()
    .to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Point2D(1, 0).is_concyclic(Point2D(0, 1), Point2D(-1, 0), Point2D(0, -1))",
    ).to_lower(),
  )
  let hit = p.intersection(
    geometry_line(
      line(
        point2d(@symcore.int(1), @symcore.int(0)),
        point2d(@symcore.int(1), @symcore.int(3)),
      ),
    ),
  )
  assert_eq(hit.length(), 1)
  assert_eq(
    geometry_entities_summary(hit),
    "[" +
    @sympy_geometry.geometry_eval_repr(
      "Point2D(1, 1).intersection(Line(Point2D(1, 0), Point2D(1, 3)))[0]",
    ) +
    "]",
  )
}
