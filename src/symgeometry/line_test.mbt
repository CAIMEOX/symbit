///|
test "geometry.line ray segment helpers" {
  let p0 = try! point2d(@symcore.int(0), @symcore.int(0))
  let p1 = try! point2d(@symcore.int(2), @symcore.int(2))
  let p2 = try! point2d(@symcore.int(2), @symcore.int(0))
  let l1 = try! line(p0, p1)
  let l2 = try! line(try! point2d(@symcore.int(0), @symcore.int(2)), p2)
  let hits = try! l1.intersection(geometry_line(l2))
  assert_eq(hits.length(), 1)
  match hits[0] {
    GeometryEntity::Point(hit) => assert_eq(hit.repr(), "Point2D(1, 1)")
    _ => fail("expected point intersection")
  }
  let seg = try! segment(p0, p2)
  guard (try! @sympy_geometry.geometry_expr_equal(
    @symprint.to_string(try! seg.length()),
    "2",
  )) else {
    fail("segment length")
  }
  let ray_obj = try! ray(p0, p1)
  assert_true(
    try! ray_obj.contains(try! point2d(@symcore.int(4), @symcore.int(4))),
  )
}
