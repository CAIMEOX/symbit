///|
test "geometry.plane parity repr distance and line intersection" {
  let pl = try! plane_from_normal(
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(1)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  assert_eq(
    pl.repr(),
    try! @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(0, 0, 1), normal_vector=(0, 0, 1))",
    ),
  )
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(
      try! pl.distance(
        try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(4)),
      ),
    ),
    "Plane(Point3D(0, 0, 1), normal_vector=(0, 0, 1)).distance(Point3D(0,0,4))",
  )) else {
    fail("plane distance parity")
  }
  let line_obj = try! line(
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(2)),
  )
  let ours = (try! pl.intersection(geometry_line(line_obj)))[0].repr()
  let rhs = try! @sympy_geometry.geometry_eval_repr(
    "Plane(Point3D(0,0,1), normal_vector=(0,0,1)).intersection(Line3D(Point3D(0,0,0), Point3D(0,0,2)))[0]",
  )
  assert_eq(ours, rhs)
}
