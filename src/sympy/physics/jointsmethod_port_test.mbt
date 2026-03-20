///|
fn jointsmethod_matrix_entry_summary(
  matrix : @symphysics.ExplicitMatrix,
) -> String {
  let entries = matrix.rows_copy()
  let rows : Array[String] = []
  for i in 0..<matrix.height() {
    let row : Array[String] = []
    for j in 0..<matrix.width() {
      row.push(@symprint.to_string(entries[i][j]))
    }
    rows.push("[" + row.join(", ") + "]")
  }
  "[" + rows.join(", ") + "]"
}

///|
test "physics.mechanics parity jointsmethod simple pendulum" {
  let m = @symcore.symbol("m")
  let l = @symcore.symbol("l")
  let g = @symcore.symbol("g")
  let q = @symvector.dynamicsymbol("q")
  let ceiling = body("PC")
  let bob = body("Pb", mass=Some(m))
  let joint = pin_joint(
    "PP",
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
  assert_eq(jointsmethod_matrix_entry_summary(jm.q()), "[[q(t)]]")
  assert_eq(jointsmethod_matrix_entry_summary(jm.u()), "[[Derivative(q(t), t)]]")
  assert_true(
    mechanics_expr_equal(
        @symprint.to_string(jm.mass_matrix().get(0, 0)),
        "l**2*m",
      )
  )
  let rhs = jm.rhs()
  assert_true(
    mechanics_expr_equal(
        @symprint.to_string(rhs.get(1, 0)),
        "-g*sin(q(t))/l",
      )
  )
}
