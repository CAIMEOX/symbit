///|
test "geometry.plane equation projection and intersection" {
  let pl = plane_from_normal(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(1)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  assert_true(
    geometry_expr_equal(
        @symprint.to_string(pl.equation()),
        "z - 1",
      )
  )
  assert_eq(
    pl
    .projection(point3d(@symcore.int(2), @symcore.int(3), @symcore.int(5)))
    .repr(),
    "Point3D(2, 3, 1)",
  )
  let l = line(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(2)),
  )
  let hit = pl.intersection(geometry_line(l))
  match hit[0] {
    GeometryEntity::Point(pt) => assert_eq(pt.repr(), "Point3D(0, 0, 1)")
    _ => fail("expected plane-line point")
  }
}

///|
test "geometry.plane parallel perpendicular and parameter helpers" {
  let pl = plane_from_normal(
    point3d(@symcore.int(1), @symcore.int(1), @symcore.int(1)),
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
  )
  let same = plane_from_normal(
    point3d(@symcore.int(2), @symcore.int(2), @symcore.int(-1)),
    [@symcore.int(2), @symcore.int(2), @symcore.int(2)],
  )
  assert_true(pl.equals(geometry_plane(same)))
  let line_obj = line(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    point3d(@symcore.int(1), @symcore.int(-1), @symcore.int(0)),
  )
  assert_true(pl.is_parallel(geometry_line(line_obj)))
  let normal_line = pl.perpendicular_line(
    point3d(@symcore.int(2), @symcore.int(0), @symcore.int(1)),
  )
  assert_true(pl.is_perpendicular(geometry_line(normal_line)))
  let projected = pl.projection_line(
    geometry_line(
      line(
        point3d(@symcore.int(1), @symcore.int(1), @symcore.int(1)),
        point3d(@symcore.int(2), @symcore.int(2), @symcore.int(2)),
      ),
    ),
  )
  match projected {
    GeometryEntity::Point(pt) => assert_eq(pt.repr(), "Point3D(1, 1, 1)")
    _ => fail("expected projected point")
  }
  let u = @symcore.symbol("u")
  let v = @symcore.symbol("v")
  let uv_point = pl.arbitrary_point(
    u=Some(@symcore.int(1)),
    v=Some(@symcore.int(2)),
  )
  let uv_values = pl.parameter_value(uv_point, u, v=Some(v))
  assert_eq(expr_map_summary(uv_values), "{u: 1, v: 2}")
}

///|
test "geometry.plane remaining public helpers" {
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
  assert_eq(a.p1().repr(), "Point3D(5, 0, 0)")
  assert_true(plane_are_concurrent([a, b]))
  assert_false(plane_are_concurrent([a, b, c]))
  let xy = plane_from_normal(
    point3d(@symcore.int(0), @symcore.int(0), @symcore.int(0)),
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  )
  assert_true(
    xy.is_coplanar(
      geometry_circle(
        circle(point2d(@symcore.int(0), @symcore.int(0)), @symcore.int(1)),
      ),
    ),
  )
  let random_pt = a.random_point(seed=Some(7))
  assert_true(a.contains_point(random_pt))
}
