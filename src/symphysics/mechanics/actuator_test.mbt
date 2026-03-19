///|
fn mechanics_load_summary_mixed(loads : Array[Load]) -> String {
  "[" +
  loads
  .map(fn(load) {
    match load {
      Load::ForceLoad(value) => value.repr()
      Load::TorqueLoad(value) => value.repr()
    }
  })
  .join(", ") +
  "]"
}

///|
test "physics.mechanics actuator core" {
  let n = @symvector.reference_frame("AN")
  let p_a = @symvector.point("ApA")
  let p_b = @symvector.point("ApB")
  let q = @symvector.dynamicsymbol("q")
  p_b.set_pos(p_a, n.x().scale(q))
  let pathway = linear_pathway(p_a, p_b).as_pathway()

  let spring = linear_spring(@symcore.symbol("k"), pathway)
  inspect(@symprint.to_string(spring.force()), content="-1*k*sqrt((q(t)**2))")

  let damper = linear_damper(@symcore.symbol("c"), pathway)
  inspect(
    @symprint.to_string(damper.force()),
    content="-1*c*Derivative(sqrt((q(t)**2)), t)",
  )

  let torque = torque_actuator(
    @symcore.symbol("T"),
    n.z(),
    n,
    reaction_frame=Some(@symvector.reference_frame("AT")),
  )
  inspect(
    mechanics_load_summary_mixed(torque.to_loads()),
    content="[Torque(frame=AN, torque=T*AN.z), Torque(frame=AT, torque=-T*AN.z)]",
  )
}
