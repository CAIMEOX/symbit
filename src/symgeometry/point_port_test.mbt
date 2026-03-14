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
