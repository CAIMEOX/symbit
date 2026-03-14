///|
fn system_exprs_summary(exprs : Array[@symcore.Expr]) -> String {
  "[" + exprs.map(@symprint.to_string).join(", ") + "]"
}

///|
fn system_bodies_summary(bodies : Array[BodyLike]) -> String {
  "[" + bodies.map(fn(body) { body.name() }).join(", ") + "]"
}

///|
test "physics.mechanics system core" {
  let n = try! @symvector.reference_frame("SN")
  let origin = try! @symvector.point("SO")
  origin.set_vel(n, @symvector.vector_zero())
  let rail = try! rigid_body("rail", masscenter=Some(origin), frame=Some(n))
  let cart = try! rigid_body("cart")
  let bob = try! particle("bob")
  let bob_frame = try! @symvector.reference_frame("bob_frame")

  let sys = system_from_newtonian(rail.as_bodylike())
  let slider = try! prismatic_joint(
    "slider",
    rail.as_bodylike(),
    cart.as_bodylike(),
  )
  let pin = try! pin_joint(
    "pin",
    cart.as_bodylike(),
    bob.as_bodylike(),
    child_interframe=Some(joint_interframe_frame(bob_frame)),
    child_point=Some(
      joint_attachment_offset(bob_frame.y().scale(@symcore.symbol("l")).neg()),
    ),
    joint_axis=Some(cart.frame().z()),
  )
  try! sys.add_joints([slider.as_joint(), pin.as_joint()])
  sys.apply_uniform_gravity(n.y().scale(@symcore.symbol("g")).neg())
  sys.add_loads([
    force_load(cart.masscenter(), n.x().scale(@symvector.dynamicsymbol("F"))),
  ])
  try! sys.validate_system()

  inspect(system_bodies_summary(sys.bodies()), content="[rail, cart, bob]")
  inspect(system_exprs_summary(sys.q_ind()), content="[q_slider(t), q_pin(t)]")
  inspect(system_exprs_summary(sys.u_ind()), content="[u_slider(t), u_pin(t)]")
  inspect(
    system_exprs_summary(sys.kdes()),
    content="[-1*Derivative(q_slider(t), t) + u_slider(t), -1*Derivative(q_pin(t), t) + u_pin(t)]",
  )
  inspect(
    sys.joints().map(fn(joint) { joint.repr() }).join(" | "),
    content="PrismaticJoint: slider  parent: rail  child: cart | PinJoint: pin  parent: cart  child: bob",
  )
  guard sys.loads().length() == 4 else {
    fail("system should include 3 gravity loads and one external force")
  }
}

///|
test "physics.mechanics system backend equations" {
  let wall = try! rigid_body("wall")
  let bob = try! particle("bob", mass=Some(@symcore.symbol("m")))
  bob.set_potential_energy(
    @symcore.symbol("k") *
    (@symvector.dynamicsymbol("q") ^ @symcore.int(2)) *
    (try! @symcore.rational_from_ints(1, 2)),
  )
  let sys = system_from_newtonian(wall.as_bodylike())
  let joint = try! prismatic_joint(
    "slide",
    wall.as_bodylike(),
    bob.as_bodylike(),
    coordinates=Some([@symvector.dynamicsymbol("q")]),
    speeds=Some([
      @symcalculus.diff(
        @symvector.dynamicsymbol("q"),
        @symvector.dynamicsymbols_t,
      ),
    ]),
  )
  try! sys.add_joints([joint.as_joint()])
  sys.add_loads([
    force_load(
      bob.point(),
      sys
      .x()
      .scale(
        @symcore.symbol("b") *
        @symcalculus.diff(
          @symvector.dynamicsymbol("q"),
          @symvector.dynamicsymbols_t,
        ),
      ),
    ),
  ])

  ignore(try! sys.form_eoms(use_lagrange=true))
  inspect(@symprint.to_string(try! sys.mass_matrix().get(0, 0)), content="m")
  let forcing_expr = try! sys.forcing().get(0, 0)
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(forcing_expr),
    "b*Derivative(q(t), t) - k*q(t)",
  )) else {
    fail("system lagrange forcing mismatch")
  }
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! (try! sys.rhs()).get(1, 0)),
    "(b*Derivative(q(t), t) - k*q(t))/m",
  )) else {
    fail("system lagrange rhs mismatch")
  }
}
