///|
test "physics.mechanics jointsmethod: simple pendulum lagrange backend" {
  let m = @symcore.symbol("m")
  let l = @symcore.symbol("l")
  let g = @symcore.symbol("g")
  let q = @symvector.dynamicsymbol("q")
  let ceiling = body("C")
  let bob = body("b", mass=Some(m))
  let joint = pin_joint(
    "P",
    ceiling.as_bodylike(),
    bob.as_bodylike(),
    coordinates=Some([q]),
    speeds=Some([@symcalculus.diff(q, @symvector.dynamicsymbols_t)]),
    child_point=Some(joint_attachment_offset(bob.x().scale(l).neg())),
    joint_axis=Some(ceiling.z()),
  )
  bob.set_potential_energy(@symcore.int(-1) * m * g * l * @symelem.cos(q))
  let jm = joints_method(ceiling.as_bodylike(), [joint.as_joint()])
  ignore(jm.form_eoms(use_lagrange=true))
  guard jm.bodies().length() == 2 else { fail("jointsmethod bodies") }
  let rhs = jm.rhs()
  guard @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(rhs.get(1, 0)),
    "-g*sin(q(t))/l",
  ) else {
    fail("jointsmethod pendulum acceleration mismatch")
  }
}
