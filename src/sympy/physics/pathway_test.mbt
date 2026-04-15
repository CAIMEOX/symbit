///|
fn mechanics_load_summary(loads : Array[Force]) -> String {
  "[" + loads.map(fn(load) { load.repr() }).join(", ") + "]"
}

///|
test "physics.mechanics pathway core" {
  let n = @symvector.reference_frame("PN")
  let p_a = @symvector.point("pA")
  let p_b = @symvector.point("pB")
  let q = @symvector.dynamicsymbol("q")
  p_b.set_pos(p_a, n.x().scale(q))
  let linear = linear_pathway(p_a, p_b)
  inspect(linear.repr(), content="LinearPathway(pA, pB)")
  inspect(@symprint.pretty_string(linear.length()), content="sqrt((q(t)**2))")
  inspect(
    mechanics_load_summary(linear.to_loads(@symcore.Expr::Symbol("F"))),
    content="[Force(point=pA, force=-F*sqrt((q(t)**2))**-1*q(t)*PN.x), Force(point=pB, force=F*sqrt((q(t)**2))**-1*q(t)*PN.x)]",
  )

  let p_c = @symvector.point("pC")
  p_c.set_pos(p_b, n.y())
  let obstacle = obstacle_set_pathway([p_a, p_b, p_c])
  inspect(obstacle.repr(), content="ObstacleSetPathway(pA, pB, pC)")
  inspect(@symprint.pretty_string(obstacle.length()), content="sqrt((q(t)**2)) + 1")
}
