///|
test "geometry.plane equation projection and intersection" {
  let pl = try! plane_from_normal(
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(1)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(pl.equation()),
    "z - 1",
  )) else {
    fail("plane equation")
  }
  assert_eq(
    (try! pl.projection(
      try! point3d(@symcore.int(2), @symcore.int(3), @symcore.int(5)),
    )).repr(),
    "Point3D(2, 3, 1)",
  )
  let l = try! line(
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(2)),
  )
  let hit = try! pl.intersection(geometry_line(l))
  match hit[0] {
    GeometryEntity::Point(pt) => assert_eq(pt.repr(), "Point3D(0, 0, 1)")
    _ => fail("expected plane-line point")
  }
}
