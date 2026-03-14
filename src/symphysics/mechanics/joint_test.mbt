///|
test "physics.mechanics joints core" {
  let n = try! @symvector.reference_frame("JN")
  let origin = try! @symvector.point("JO")
  origin.set_vel(n, @symvector.vector_zero())

  let parent = try! rigid_body("P", masscenter=Some(origin), frame=Some(n))
  let child = try! rigid_body("C")
  let pin = try! pin_joint("PC", parent.as_bodylike(), child.as_bodylike())
  inspect(pin.repr(), content="PinJoint: PC  parent: P  child: C")
  inspect(@symprint.to_string(pin.coordinates()[0]), content="q_PC(t)")
  inspect(@symprint.to_string(pin.speeds()[0]), content="u_PC(t)")
  inspect(
    @symvector.vsprint(child.frame().ang_vel_in(parent.frame())),
    content="u_PC(t)*JN.x",
  )
  inspect(
    @symvector.vsprint(try! pin.child_point().pos_from(pin.parent_point())),
    content="0",
  )

  let slider_child = try! rigid_body("S")
  let prism = try! prismatic_joint(
    "PS",
    parent.as_bodylike(),
    slider_child.as_bodylike(),
  )
  inspect(prism.repr(), content="PrismaticJoint: PS  parent: P  child: S")
  inspect(@symprint.to_string(prism.coordinates()[0]), content="q_PS(t)")
  inspect(
    @symvector.vsprint(slider_child.frame().ang_vel_in(parent.frame())),
    content="0",
  )
  inspect(
    @symvector.vsprint(try! prism.child_point().pos_from(prism.parent_point())),
    content="q_PS(t)*JN.x",
  )
}

///|
test "physics.mechanics advanced joints core" {
  let n = try! @symvector.reference_frame("AJN")
  let origin = try! @symvector.point("AJO")
  origin.set_vel(n, @symvector.vector_zero())
  let parent = try! rigid_body("AP", masscenter=Some(origin), frame=Some(n))
  let child = try! rigid_body("AC")

  let cyl = try! cylindrical_joint(
    "Cyl",
    parent.as_bodylike(),
    child.as_bodylike(),
  )
  inspect(cyl.repr(), content="CylindricalJoint: Cyl  parent: AP  child: AC")
  inspect(
    @symvector.vsprint(try! cyl.child_point().pos_from(cyl.parent_point())),
    content="q1_Cyl(t)*AJN.x",
  )
  inspect(
    @symvector.vsprint(child.frame().ang_vel_in(parent.frame())),
    content="u0_Cyl(t)*AJN.x",
  )

  let planar_child = try! rigid_body("APL")
  let planar = try! planar_joint(
    "Plan",
    parent.as_bodylike(),
    planar_child.as_bodylike(),
  )
  inspect(planar.repr(), content="PlanarJoint: Plan  parent: AP  child: APL")
  inspect(
    @symvector.vsprint(
      try! planar.child_point().pos_from(planar.parent_point()),
    ),
    content="q1_Plan(t)*AJN.y + q2_Plan(t)*AJN.z",
  )
  inspect(
    @symvector.vsprint(planar_child.frame().ang_vel_in(parent.frame())),
    content="u0_Plan(t)*AJN.x",
  )

  let spherical_child = try! rigid_body("AS")
  let spherical = try! spherical_joint(
    "Ball",
    parent.as_bodylike(),
    spherical_child.as_bodylike(),
  )
  inspect(
    spherical.repr(),
    content="SphericalJoint: Ball  parent: AP  child: AS",
  )
  inspect(
    @symvector.vsprint(
      try! spherical.child_point().pos_from(spherical.parent_point()),
    ),
    content="0",
  )
  guard spherical.coordinates().length() == 3 &&
    spherical.speeds().length() == 3 else {
    fail("spherical joint should use three coordinates and speeds")
  }

  let weld_child = try! rigid_body("AW")
  let weld = try! weld_joint(
    "Fix",
    parent.as_bodylike(),
    weld_child.as_bodylike(),
  )
  inspect(weld.repr(), content="WeldJoint: Fix  parent: AP  child: AW")
  inspect(
    @symvector.vsprint(weld_child.frame().ang_vel_in(parent.frame())),
    content="0",
  )
  inspect(
    @symvector.vsprint(try! weld.child_point().pos_from(weld.parent_point())),
    content="0",
  )
}
