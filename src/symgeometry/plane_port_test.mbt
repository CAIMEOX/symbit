///|
test "geometry.plane parity repr distance and line intersection" {
  let pl = plane_from_normal(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(1)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  assert_eq(
    pl.repr(),
    @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(0, 0, 1), normal_vector=(0, 0, 1))",
    ),
  )
  assert_true(
    @sympy_geometry.geometry_expr_equal(
        @symprint.to_string(
          pl.distance(point3d(@symcore.int(0), @symcore.int(0), @symcore.int(4))),
        ),
        "Plane(Point3D(0, 0, 1), normal_vector=(0, 0, 1)).distance(Point3D(0,0,4))",
      )
  )
  let line_obj = line(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(2)),
  )
  let ours = pl.intersection(geometry_line(line_obj))[0].repr()
  let rhs = @sympy_geometry.geometry_eval_repr(
    "Plane(Point3D(0,0,1), normal_vector=(0,0,1)).intersection(Line3D(Point3D(0,0,0), Point3D(0,0,2)))[0]",
  )
  assert_eq(ours, rhs)
}

///|
test "geometry.plane parity high-value helpers" {
  let pl = plane_from_normal(
    point3d(@symcore.int(1), @symcore.int(1), @symcore.int(1)),
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
  )
  assert_eq(
    pl.ambient_dimension().to_string(),
    @sympy_geometry.geometry_eval_str(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).ambient_dimension",
    ),
  )
  let ap = pl.arbitrary_point()
  let expected_ap_x = @sympy_geometry.geometry_eval_str(
    "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).arbitrary_point().x",
  )
  geometry_assert_expr_equal(ap.x(), expected_ap_x, "plane arbitrary point x")
  let expected_ap_y = @sympy_geometry.geometry_eval_str(
    "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).arbitrary_point().y",
  )
  geometry_assert_expr_equal(ap.y(), expected_ap_y, "plane arbitrary point y")
  let expected_ap_z = @sympy_geometry.geometry_eval_str(
    "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).arbitrary_point().z",
  )
  geometry_assert_expr_equal(ap.z(), expected_ap_z, "plane arbitrary point z")
  let same = plane_from_normal(
    point3d(@symcore.int(2), @symcore.int(2), @symcore.int(-1)),
    [@symcore.int(2), @symcore.int(2), @symcore.int(2)],
  )
  assert_eq(
    pl.equals(geometry_plane(same)).to_string().to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).equals(Plane(Point3D(2, 2, -1), normal_vector=(2, 2, 2)))",
    ).to_lower(),
  )
  let parallel_line = line(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    point3d(@symcore.int(1), @symcore.int(-1), @symcore.int(0)),
  )
  assert_eq(
    pl.is_parallel(geometry_line(parallel_line)).to_string().to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).is_parallel(Line3D(Point3D(0, 0, 0), Point3D(1, -1, 0)))",
    ).to_lower(),
  )
  let perp_line = pl.perpendicular_line(
    point3d(@symcore.int(2), @symcore.int(0), @symcore.int(1)),
  )
  assert_eq(
    perp_line.repr(),
    @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).perpendicular_line(Point3D(2, 0, 1))",
    ),
  )
  let expected_angle = @sympy_geometry.geometry_eval_str(
    "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).angle_between(Line3D(Point3D(2, 0, 1), Point3D(3, 1, 2)))",
  )
  geometry_assert_expr_equal(
    pl.angle_between(geometry_line(perp_line)),
    expected_angle,
    "plane angle between line",
  )
  let u = @symcore.symbol("u")
  let v = @symcore.symbol("v")
  let uv_point = pl.arbitrary_point(
    u=Some(@symcore.int(1)),
    v=Some(@symcore.int(2)),
  )
  let uv_values = pl.parameter_value(uv_point, u, v=Some(v))
  assert_eq(uv_values.length(), 2)
  let expected_u = @sympy_geometry.geometry_eval_str(
    "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).parameter_value(Point3D(-2, 0, 5), u, v)[u]",
  )
  let expected_v = @sympy_geometry.geometry_eval_str(
    "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).parameter_value(Point3D(-2, 0, 5), u, v)[v]",
  )
  for item in uv_values {
    let key = @symprint.to_string(item.0)
    if key == "u" {
      geometry_assert_expr_equal(item.1, expected_u, "plane parameter_value u")
    } else if key == "v" {
      geometry_assert_expr_equal(item.1, expected_v, "plane parameter_value v")
    } else {
      fail("unexpected plane parameter key")
    }
  }
  assert_eq(
    pl
    .parallel_plane(point3d(@symcore.int(3), @symcore.int(3), @symcore.int(3)))
    .repr(),
    @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).parallel_plane(Point3D(3, 3, 3))",
    ),
  )
  assert_eq(
    pl.perpendicular_plane().repr(),
    @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).perpendicular_plane()",
    ),
  )
  assert_eq(
    pl
    .projection_line(
      geometry_line(
        line(
          point3d(@symcore.int(1), @symcore.int(1), @symcore.int(1)),
          point3d(@symcore.int(2), @symcore.int(2), @symcore.int(2)),
        ),
      ),
    )
    .repr(),
    @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(1, 1, 1), normal_vector=(1, 1, 1)).projection_line(Line3D(Point3D(1, 1, 1), Point3D(2, 2, 2)))",
    ),
  )
}

///|
test "geometry.plane parity remaining public helpers" {
  let a = plane_from_normal(
    point3d(@symcore.int(5), @symcore.int(0), @symcore.int(0)),
    [@symcore.int(1), @symcore.int(-1), @symcore.int(1)],
  )
  let b = plane_from_normal(
    point3d(@symcore.int(0), @symcore.int(-2), @symcore.int(0)),
    [@symcore.int(3), @symcore.int(1), @symcore.int(1)],
  )
  let c = plane_from_normal(
    point3d(@symcore.int(0), @symcore.int(-1), @symcore.int(0)),
    [@symcore.int(5), @symcore.int(-1), @symcore.int(9)],
  )
  assert_eq(
    a.p1().repr(),
    @sympy_geometry.geometry_eval_repr(
      "Plane(Point3D(5, 0, 0), normal_vector=(1, -1, 1)).p1",
    ),
  )
  assert_eq(
    plane_are_concurrent([a, b]).to_string().to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Plane.are_concurrent(Plane(Point3D(5, 0, 0), normal_vector=(1, -1, 1)), Plane(Point3D(0, -2, 0), normal_vector=(3, 1, 1)))",
    ).to_lower(),
  )
  assert_eq(
    plane_are_concurrent([a, b, c]).to_string().to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Plane.are_concurrent(Plane(Point3D(5, 0, 0), normal_vector=(1, -1, 1)), Plane(Point3D(0, -2, 0), normal_vector=(3, 1, 1)), Plane(Point3D(0, -1, 0), normal_vector=(5, -1, 9)))",
    ).to_lower(),
  )
  let xy = plane_from_normal(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  assert_eq(
    xy
    .is_coplanar(
      geometry_circle(
        circle(point2d(@symcore.int(0), @symcore.int(0)), @symcore.int(1)),
      ),
    )
    .to_string()
    .to_lower(),
    @sympy_geometry.geometry_eval_str(
      "Plane(Point3D(0, 0, 0), normal_vector=(0, 0, 1)).is_coplanar(Circle(Point2D(0, 0), 1))",
    ).to_lower(),
  )
}
