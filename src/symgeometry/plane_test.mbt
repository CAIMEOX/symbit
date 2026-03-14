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

///|
test "geometry.plane parallel perpendicular and parameter helpers" {
  let pl = try! plane_from_normal(
    try! point3d(@symcore.int(1), @symcore.int(1), @symcore.int(1)),
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
  )
  let same = try! plane_from_normal(
    try! point3d(@symcore.int(2), @symcore.int(2), @symcore.int(-1)),
    [@symcore.int(2), @symcore.int(2), @symcore.int(2)],
  )
  assert_true(try! pl.equals(geometry_plane(same)))
  let line_obj = try! line(
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    try! point3d(@symcore.int(1), @symcore.int(-1), @symcore.int(0)),
  )
  assert_true(try! pl.is_parallel(geometry_line(line_obj)))
  let normal_line = try! pl.perpendicular_line(
    try! point3d(@symcore.int(2), @symcore.int(0), @symcore.int(1)),
  )
  assert_true(try! pl.is_perpendicular(geometry_line(normal_line)))
  let projected = try! pl.projection_line(
    geometry_line(
      try! line(
        try! point3d(@symcore.int(1), @symcore.int(1), @symcore.int(1)),
        try! point3d(@symcore.int(2), @symcore.int(2), @symcore.int(2)),
      ),
    ),
  )
  match projected {
    GeometryEntity::Point(pt) => assert_eq(pt.repr(), "Point3D(1, 1, 1)")
    _ => fail("expected projected point")
  }
  let u = @symcore.symbol("u")
  let v = @symcore.symbol("v")
  let uv_point = try! pl.arbitrary_point(
    u=Some(@symcore.int(1)),
    v=Some(@symcore.int(2)),
  )
  let uv_values = try! pl.parameter_value(uv_point, u, v=Some(v))
  assert_eq(expr_map_summary(uv_values), "{u: 1, v: 2}")
}

///|
test "geometry.plane remaining public helpers" {
  let a = try! plane_from_normal(
    try! point3d(@symcore.int(5), @symcore.int(0), @symcore.int(0)),
    [@symcore.int(1), @symcore.int(-1), @symcore.int(1)],
  )
  let b = try! plane_from_normal(
    try! point3d(@symcore.int(0), @symcore.int(-2), @symcore.int(0)),
    [@symcore.int(3), @symcore.int(1), @symcore.int(1)],
  )
  let c = try! plane_from_normal(
    try! point3d(@symcore.int(0), @symcore.int(-1), @symcore.int(0)),
    [@symcore.int(5), @symcore.int(-1), @symcore.int(9)],
  )
  assert_eq(a.p1().repr(), "Point3D(5, 0, 0)")
  assert_true(try! plane_are_concurrent([a, b]))
  assert_false(try! plane_are_concurrent([a, b, c]))
  let xy = try! plane_from_normal(
    try! point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  assert_true(
    try! xy.is_coplanar(
      geometry_circle(
        try! circle(
          try! point2d(@symcore.int(0), @symcore.int(0)),
          @symcore.int(1),
        ),
      ),
    ),
  )
  let random_pt = try! a.random_point(seed=Some(7))
  assert_true(try! a.contains_point(random_pt))
}
