///|
test "physics.mechanics parity system assembly" {
  let n = try! @symvector.reference_frame("PSN")
  let origin = try! @symvector.point("PSO")
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

  let prefix = "from sympy import symbols; g,l=symbols('g l'); F=dynamicsymbols('F'); N=ReferenceFrame('PSN'); O=Point('PSO'); O.set_vel(N, 0); rail=RigidBody('rail', O, N); cart=RigidBody('cart'); bob=Particle('bob'); bob_frame=ReferenceFrame('bob_frame'); sys=System.from_newtonian(rail); sys.add_joints(PrismaticJoint('slider', rail, cart), PinJoint('pin', cart, bob, joint_axis=cart.frame.z, child_interframe=bob_frame, child_point=-l*bob_frame.y)); sys.apply_uniform_gravity(-g*N.y); sys.add_loads((cart.masscenter, F*N.x)); "
  let oracle_q = try! @sympy_physics.mechanics_summary(
    prefix + "[str(x) for x in sys.q_ind]",
  )
  let oracle_u = try! @sympy_physics.mechanics_summary(
    prefix + "[str(x) for x in sys.u_ind]",
  )
  let oracle_bodies = try! @sympy_physics.mechanics_summary(
    prefix + "[body.name for body in sys.bodies]",
  )
  let oracle_joints = try! @sympy_physics.mechanics_summary(
    prefix + "[str(j) for j in sys.joints]",
  )
  let oracle_loads = try! @sympy_physics.mechanics_summary(prefix + "sys.loads")
  guard "[" + sys.q_ind().map(@symprint.to_string).join(", ") + "]" == oracle_q else {
    fail("system q_ind parity mismatch")
  }
  guard "[" + sys.u_ind().map(@symprint.to_string).join(", ") + "]" == oracle_u else {
    fail("system u_ind parity mismatch")
  }
  let oracle_kdes = [
    "u_slider(t) - Derivative(q_slider(t), t)", "u_pin(t) - Derivative(q_pin(t), t)",
  ]
  for i in 0..<sys.kdes().length() {
    guard (try! @sympy_physics.mechanics_expr_equal(
      @symprint.to_string(sys.kdes()[i]),
      oracle_kdes[i],
    )) else {
      fail("system kde parity mismatch")
    }
  }
  guard "[" + sys.bodies().map(fn(body) { body.name() }).join(", ") + "]" ==
    oracle_bodies else {
    fail("system bodies parity mismatch")
  }
  guard "[" + sys.joints().map(fn(joint) { joint.repr() }).join(", ") + "]" ==
    oracle_joints else {
    fail("system joints parity mismatch")
  }
  guard sys.loads().length() == 4 else { fail("system load count mismatch") }
  let mut gravity_count = 0
  let mut found_external = false
  for load in sys.loads() {
    match load {
      Load::ForceLoad(value) =>
        if value.point == cart.masscenter() {
          let is_external = @symvector.vsprint(value.force) == "F(t)*PSN.x"
          if is_external {
            found_external = true
          } else {
            gravity_count += 1
          }
        } else {
          gravity_count += 1
        }
      _ => fail("system should only create force loads")
    }
  }
  guard found_external && gravity_count == 3 && oracle_loads.contains("F(t)") else {
    fail("system load parity mismatch")
  }
}

///|
test "physics.mechanics parity system form_eoms lagrange" {
  let q = @symvector.dynamicsymbol("q")
  let qd = @symcalculus.diff(q, @symvector.dynamicsymbols_t)
  let wall = try! rigid_body("wall")
  let bob = try! particle("bob", mass=Some(@symcore.symbol("m")))
  bob.set_potential_energy(
    @symcore.symbol("k") *
    (q ^ @symcore.int(2)) *
    (try! @symcore.rational_from_ints(1, 2)),
  )
  let sys = system_from_newtonian(wall.as_bodylike())
  let joint = try! prismatic_joint(
    "slide",
    wall.as_bodylike(),
    bob.as_bodylike(),
    coordinates=Some([q]),
    speeds=Some([qd]),
  )
  try! sys.add_joints([joint.as_joint()])
  sys.add_loads([
    force_load(bob.point(), sys.x().scale(@symcore.symbol("b") * qd)),
  ])
  ignore(try! sys.form_eoms(use_lagrange=true))

  let prefix = "q=dynamicsymbols('q'); qd=q.diff(t); m,k,b=symbols('m k b'); wall=RigidBody('wall'); bob=Particle('bob', mass=m); bob.potential_energy = k*q**2/2; sys=System.from_newtonian(wall); sys.add_joints(PrismaticJoint('slide', wall, bob, coordinates=q, speeds=qd)); sys.add_loads((bob.masscenter, b*qd*sys.x)); sys.form_eoms(LagrangesMethod); "
  let oracle_mass = try! @sympy_physics.mechanics_summary(
    prefix + "sys.mass_matrix[0, 0]",
  )
  let oracle_forcing = try! @sympy_physics.mechanics_summary(
    prefix + "sys.forcing[0, 0]",
  )
  guard @symprint.to_string(try! sys.mass_matrix().get(0, 0)) == oracle_mass else {
    fail("system lagrange mass matrix parity mismatch")
  }
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! sys.forcing().get(0, 0)),
    oracle_forcing,
  )) else {
    fail("system lagrange forcing parity mismatch")
  }
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(try! sys.rhs()),
    prefix + "sys.rhs()",
  )) else {
    fail("system lagrange rhs parity mismatch")
  }
}
