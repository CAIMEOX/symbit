///|
test "geometry.util parity are_coplanar centroid intersection" {
  let centroid_value = try! centroid([
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(2)),
  ])
  match centroid_value {
    Some(pt) =>
      assert_eq(
        pt.repr(),
        try! @sympy_geometry.geometry_eval_repr(
          "centroid(Point2D(0,0), Point2D(2,0), Point2D(2,2))",
        ),
      )
    None => fail("expected centroid")
  }
  assert_true(
    try! are_coplanar([
      geometry_point(
        try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
      ),
      geometry_point(
        try! point3d(@symcore.int(1), @symcore.int(0), @symcore.int(0)),
      ),
      geometry_point(
        try! point3d(@symcore.int(0), @symcore.int(1), @symcore.int(0)),
      ),
      geometry_point(
        try! point3d(@symcore.int(1), @symcore.int(1), @symcore.int(0)),
      ),
    ]),
  )
}
