///|
test "physics.mechanics wrapping geometry core" {
  let n = @symvector.reference_frame("WN")
  let p_o = @symvector.point("WpO")
  let sphere = wrapping_sphere(@symcore.Expr::Symbol("r"), p_o)
  let p_1 = @symvector.point("Wp1")
  let p_2 = @symvector.point("Wp2")
  p_1.set_pos(p_o, n.x().scale(@symcore.Expr::Symbol("r")))
  p_2.set_pos(p_o, n.y().scale(@symcore.Expr::Symbol("r")))
  inspect(sphere.repr(), content="WrappingSphere(radius=r, point=WpO)")
  inspect(
    @symprint.pretty_string(sphere.geodesic_length(p_1, p_2)),
    content="r*acos(0)",
  )

  let cylinder = wrapping_cylinder(@symcore.Expr::Symbol("r"), p_o, n.z())
  let p_3 = @symvector.point("Wp3")
  p_3.set_pos(p_o, n.x().scale(@symcore.Expr::Symbol("r")) + n.z())
  inspect(
    cylinder.repr(),
    content="WrappingCylinder(radius=r, point=WpO, axis=WN.z)",
  )
  inspect(@symprint.pretty_string(cylinder.geodesic_length(p_1, p_3)), content="1")
}
