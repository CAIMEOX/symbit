///|
/// Sample symbolic mechanics models aligned with the high-value surface of
/// `sympy.physics.mechanics.models`.
///
/// The upstream helpers return equation-of-motion backends. In Symbit these
/// constructors return the fully assembled `System`, which keeps the model
/// structure, coordinates, speeds, joints, loads, and actuators explicit.

///|
fn model_dynamicsymbol(prefix : String, index : Int) -> Expr {
  @symvector.dynamicsymbol(prefix + index.to_string())
}

///|
fn model_symbol(prefix : String, index : Int) -> Expr {
  symbol(prefix + index.to_string())
}

///|
pub fn multi_mass_spring_damper(
  n? : Int = 1,
  apply_gravity? : Bool = false,
  apply_external_forces? : Bool = false,
) -> System raise {
  guard n > 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "number of masses must be positive",
    )
  }

  let n_frame = @symvector.reference_frame("N")
  let origin = @symvector.point("origin")
  origin.set_vel(n_frame, @symvector.vector_zero())
  let ground = rigid_body(
    "ground",
    masscenter=Some(origin),
    frame=Some(n_frame),
  )
  let sys = system_from_newtonian(ground.as_bodylike())

  let mut parent_body : BodyLike = ground.as_bodylike()
  let mut parent_point = origin
  let bodies : Array[BodyLike] = []
  let actuators : Array[ActuatorLike] = []
  let loads : Array[Load] = []

  for i in 0..<n {
    let body_name = "block" + i.to_string()
    let body = rigid_body(body_name, mass=Some(model_symbol("m", i)))
    let q = model_dynamicsymbol("x", i)
    let u = model_dynamicsymbol("v", i)
    let joint = prismatic_joint(
      "J" + i.to_string(),
      parent_body,
      body.as_bodylike(),
      coordinates=Some([q]),
      speeds=Some([u]),
      joint_axis=Some(n_frame.x()),
    )
    let pathway = linear_pathway(parent_point, body.masscenter()).as_pathway()
    actuators.push(linear_spring(model_symbol("k", i), pathway).as_actuator())
    actuators.push(linear_damper(model_symbol("c", i), pathway).as_actuator())
    if apply_external_forces {
      loads.push(
        force_load(
          body.masscenter(),
          n_frame.x().scale(model_dynamicsymbol("f", i)),
        ),
      )
    }
    bodies.push(body.as_bodylike())
    sys.add_joints([joint.as_joint()])
    parent_body = body.as_bodylike()
    parent_point = body.masscenter()
  }

  sys.add_bodies(bodies)
  sys.add_actuators(actuators)
  sys.add_loads(loads)
  if apply_gravity {
    sys.apply_uniform_gravity(n_frame.y().scale(symbol("g")).neg())
  }
  sys.validate_system()
  sys
}

///|
pub fn n_link_pendulum_on_cart(
  n? : Int = 1,
  cart_force? : Bool = true,
  joint_torques? : Bool = false,
) -> System raise {
  guard n > 0 else {
    raise @symphysics.PhysicsError::ValueError(
      "number of links must be positive",
    )
  }

  let i_frame = @symvector.reference_frame("I")
  let origin = @symvector.point("O")
  origin.set_vel(i_frame, @symvector.vector_zero())
  let rail = rigid_body("rail", masscenter=Some(origin), frame=Some(i_frame))
  let cart = rigid_body("cart", mass=Some(model_symbol("m", 0)))
  let sys = system_from_newtonian(rail.as_bodylike())

  let slider = prismatic_joint(
    "slider",
    rail.as_bodylike(),
    cart.as_bodylike(),
    coordinates=Some([model_dynamicsymbol("q", 0)]),
    speeds=Some([model_dynamicsymbol("u", 0)]),
    joint_axis=Some(i_frame.x()),
  )
  sys.add_joints([slider.as_joint()])

  let bodies : Array[BodyLike] = [cart.as_bodylike()]
  let loads : Array[Load] = []
  let mut parent_body : BodyLike = cart.as_bodylike()
  let mut parent_joint_frame = i_frame

  for i in 0..<n {
    let bob = particle(
      "bob" + i.to_string(),
      mass=Some(model_symbol("m", i + 1)),
    )
    let bob_frame = @symvector.reference_frame("B" + i.to_string())
    let length = model_symbol("l", i)
    let pin = pin_joint(
      "pin" + i.to_string(),
      parent_body,
      bob.as_bodylike(),
      coordinates=Some([model_dynamicsymbol("q", i + 1)]),
      speeds=Some([model_dynamicsymbol("u", i + 1)]),
      parent_interframe=Some(joint_interframe_frame(parent_joint_frame)),
      child_point=Some(
        joint_attachment_offset(bob_frame.y().scale(length).neg()),
      ),
      child_interframe=Some(joint_interframe_frame(bob_frame)),
      joint_axis=Some(parent_joint_frame.z()),
    )
    sys.add_joints([pin.as_joint()])
    bodies.push(bob.as_bodylike())
    if joint_torques {
      let torque_symbol = model_dynamicsymbol("T", i)
      loads.push(
        torque_load(
          pin.parent_interframe(),
          pin.joint_axis().scale(int(-1) * torque_symbol),
        ),
      )
      loads.push(
        torque_load(
          pin.child_interframe(),
          pin.joint_axis().scale(torque_symbol),
        ),
      )
    }
    parent_body = bob.as_bodylike()
    parent_joint_frame = bob_frame
  }

  sys.add_bodies(bodies)
  sys.apply_uniform_gravity(i_frame.y().scale(symbol("g")).neg())
  if cart_force {
    sys.add_loads([
      force_load(
        cart.masscenter(),
        i_frame.x().scale(@symvector.dynamicsymbol("F")),
      ),
    ])
  }
  sys.add_loads(loads)
  sys.validate_system()
  sys
}
