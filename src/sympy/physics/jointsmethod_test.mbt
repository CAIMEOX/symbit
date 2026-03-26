///|
test "physics.mechanics jointsmethod: simple pendulum lagrange backend" {
  let m = @symcore.Expr::Symbol("m")
  let l = @symcore.Expr::Symbol("l")
  let g = @symcore.Expr::Symbol("g")
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
  assert_eq(jm.bodies().length(), 2)
  let rhs = jm.rhs()
  assert_true(
    mechanics_expr_equal(@symprint.to_string(rhs.get(1, 0)), "-g*sin(q(t))/l"),
  )
}
