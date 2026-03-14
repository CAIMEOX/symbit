///|
test "geometry.util helpers" {
  let x = @symcore.symbol("x")
  assert_eq(@symprint.to_string(find("x", x + @symcore.int(1))), "x")
  let c = try! centroid([
    try! point2d(@symcore.int(0), @symcore.int(0)),
    try! point2d(@symcore.int(2), @symcore.int(0)),
  ])
  match c {
    Some(point_obj) => assert_eq(point_obj.repr(), "Point2D(1, 0)")
    None => fail("expected centroid")
  }
}
