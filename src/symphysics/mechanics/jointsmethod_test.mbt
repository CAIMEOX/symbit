///|
test "physics.mechanics jointsmethod: simple pendulum lagrange backend" {
  let m = @symcore.symbol("m")
  let l = @symcore.symbol("l")
  let g = @symcore.symbol("g")
  let q = @symvector.dynamicsymbol("q")
  let ceiling = try! body("C")
  let bob = try! body("b", mass=Some(m))
  let joint = try! pin_joint(
    "P",
    ceiling.as_bodylike(),
    bob.as_bodylike(),
    coordinates=Some([q]),
    speeds=Some([@symcalculus.diff(q, @symvector.dynamicsymbols_t)]),
    child_point=Some(joint_attachment_offset(bob.x().scale(l).neg())),
    joint_axis=Some(ceiling.z()),
  )
  bob.set_potential_energy(@symcore.int(-1) * m * g * l * @symelem.cos(q))
  let jm = try! joints_method(ceiling.as_bodylike(), [joint.as_joint()])
  ignore(try! jm.form_eoms(use_lagrange=true))
  guard jm.bodies().length() == 2 else { fail("jointsmethod bodies") }
  let rhs = try! jm.rhs()
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! rhs.get(1, 0)),
    "-g*sin(q(t))/l",
  )) else {
    fail("jointsmethod pendulum acceleration mismatch")
  }
}
