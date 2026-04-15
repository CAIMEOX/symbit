///|
fn system_exprs_summary(exprs : Array[@symcore.Expr]) -> String {
  "[" + exprs.map(@symprint.pretty_string).join(", ") + "]"
}

///|
fn system_bodies_summary(bodies : Array[BodyLike]) -> String {
  "[" + bodies.map(fn(body) { body.name() }).join(", ") + "]"
}

///|
test "physics.mechanics system core" {
  let n = @symvector.reference_frame("SN")
  let origin = @symvector.point("SO")
  origin.set_vel(n, @symvector.vector_zero())
  let rail = rigid_body("rail", masscenter=Some(origin), frame=Some(n))
  let cart = rigid_body("cart")
  let bob = particle("bob")
  let bob_frame = @symvector.reference_frame("bob_frame")

  let sys = system_from_newtonian(rail.as_bodylike())
  let slider = prismatic_joint("slider", rail.as_bodylike(), cart.as_bodylike())
  let pin = pin_joint(
    "pin",
    cart.as_bodylike(),
    bob.as_bodylike(),
    child_interframe=Some(joint_interframe_frame(bob_frame)),
    child_point=Some(
      joint_attachment_offset(
        bob_frame.y().scale(@symcore.Expr::Symbol("l")).neg(),
      ),
    ),
    joint_axis=Some(cart.frame().z()),
  )
  sys.add_joints([slider.as_joint(), pin.as_joint()])
  sys.apply_uniform_gravity(n.y().scale(@symcore.Expr::Symbol("g")).neg())
  sys.add_loads([
    force_load(cart.masscenter(), n.x().scale(@symvector.dynamicsymbol("F"))),
  ])
  let validation : Result[Unit, @symphysics.PhysicsError] = try? sys.validate_system()
  match validation {
    Ok(_) => ()
    Err(err) => fail("system should validate: " + err.to_string())
  }

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
  assert_eq(sys.loads().length(), 4)
}

///|
test "physics.mechanics system backend equations" {
  let wall = rigid_body("wall")
  let bob = particle("bob", mass=Some(@symcore.Expr::Symbol("m")))
  bob.set_potential_energy(
    @symcore.Expr::Symbol("k") *
    (@symvector.dynamicsymbol("q") ^ @symcore.int(2)) *
    @symcore.rational_from_ints(1, 2),
  )
  let sys = system_from_newtonian(wall.as_bodylike())
  let joint = prismatic_joint(
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
  sys.add_joints([joint.as_joint()])
  sys.add_loads([
    force_load(
      bob.point(),
      sys
      .x()
      .scale(
        @symcore.Expr::Symbol("b") *
        @symcalculus.diff(
          @symvector.dynamicsymbol("q"),
          @symvector.dynamicsymbols_t,
        ),
      ),
    ),
  ])

  ignore(sys.form_eoms(use_lagrange=true))
  inspect(@symprint.pretty_string(sys.mass_matrix().get(0, 0)), content="m")
  let forcing_expr = sys.forcing().get(0, 0)
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(forcing_expr),
      "b*Derivative(q(t), t) - k*q(t)",
    ),
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(sys.rhs().get(1, 0)),
      "(b*Derivative(q(t), t) - k*q(t))/m",
    ),
  )
}

///|
test "physics.mechanics system validation semantics" {
  let n = @symvector.reference_frame("SVN")
  let origin = @symvector.point("SVO")
  origin.set_vel(n, @symvector.vector_zero())
  let wall = rigid_body("wall", masscenter=Some(origin), frame=Some(n))
  let bob = particle("bob", mass=Some(@symcore.Expr::Symbol("m")))
  let q = @symvector.dynamicsymbol("q")
  let qd = @symcalculus.diff(q, @symvector.dynamicsymbols_t)

  let valid_lagrange = system_from_newtonian(wall.as_bodylike())
  let lag_joint = prismatic_joint(
    "slide_l",
    wall.as_bodylike(),
    bob.as_bodylike(),
    coordinates=Some([q]),
    speeds=Some([qd]),
  )
  valid_lagrange.add_joints([lag_joint.as_joint()])
  valid_lagrange.validate_system(use_lagrange=true)

  let missing_kde = system_from_newtonian(wall.as_bodylike())
  let kane_joint = prismatic_joint(
    "slide_k",
    wall.as_bodylike(),
    bob.as_bodylike(),
  )
  missing_kde.add_bodies([wall.as_bodylike(), bob.as_bodylike()])
  missing_kde.add_coordinates(kane_joint.coordinates())
  missing_kde.add_speeds(kane_joint.speeds())
  let bad_kane : Result[Unit, @symphysics.PhysicsError] = try? missing_kde.validate_system()
  assert_true(bad_kane is Err(@symphysics.PhysicsError::ValueError(_)))

  let invalid_lagrange = system_from_newtonian(wall.as_bodylike())
  let bad_joint = prismatic_joint(
    "slide_bad",
    wall.as_bodylike(),
    bob.as_bodylike(),
    coordinates=Some([q]),
    speeds=Some([@symvector.dynamicsymbol("u_bad")]),
  )
  invalid_lagrange.add_joints([bad_joint.as_joint()])
  let bad_lagrange : Result[Unit, @symphysics.PhysicsError] = try? invalid_lagrange.validate_system(
    use_lagrange=true,
  )
  assert_true(bad_lagrange is Err(@symphysics.PhysicsError::ValueError(_)))
}
