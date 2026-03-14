///|
fn mechanics_load_summary(loads : Array[Force]) -> String {
  "[" + loads.map(fn(load) { load.repr() }).join(", ") + "]"
}

///|
test "physics.mechanics pathway core" {
  let n = try! @symvector.reference_frame("PN")
  let p_a = try! @symvector.point("pA")
  let p_b = try! @symvector.point("pB")
  let q = @symvector.dynamicsymbol("q")
  p_b.set_pos(p_a, n.x().scale(q))
  let linear = linear_pathway(p_a, p_b)
  inspect(linear.repr(), content="LinearPathway(pA, pB)")
  inspect(@symprint.to_string(try! linear.length()), content="sqrt((q(t)**2))")
  inspect(
    mechanics_load_summary(try! linear.to_loads(@symcore.symbol("F"))),
    content="[Force(point=pA, force=-F*sqrt((q(t)**2))**-1*q(t)*PN.x), Force(point=pB, force=F*sqrt((q(t)**2))**-1*q(t)*PN.x)]",
  )

  let p_c = try! @symvector.point("pC")
  p_c.set_pos(p_b, n.y())
  let obstacle = try! obstacle_set_pathway([p_a, p_b, p_c])
  inspect(obstacle.repr(), content="ObstacleSetPathway(pA, pB, pC)")
  inspect(
    @symprint.to_string(try! obstacle.length()),
    content="sqrt((q(t)**2)) + 1",
  )
}
