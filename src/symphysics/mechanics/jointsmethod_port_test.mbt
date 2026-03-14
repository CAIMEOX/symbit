///|
fn jointsmethod_matrix_entry_summary(
  matrix : @symphysics.ExplicitMatrix,
) -> String {
  let rows : Array[String] = []
  for i in 0..<matrix.height() {
    let row : Array[String] = []
    for j in 0..<matrix.width() {
      row.push(@symprint.to_string(try! matrix.get(i, j)))
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
  let ceiling = try! body("PC")
  let bob = try! body("Pb", mass=Some(m))
  let joint = try! pin_joint(
    "PP",
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
  guard jointsmethod_matrix_entry_summary(jm.q()) == "[[q(t)]]" else {
    fail("jointsmethod q parity mismatch")
  }
  guard jointsmethod_matrix_entry_summary(jm.u()) == "[[Derivative(q(t), t)]]" else {
    fail("jointsmethod u parity mismatch")
  }
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! jm.mass_matrix().get(0, 0)),
    "l**2*m",
  )) else {
    fail("jointsmethod mass matrix parity mismatch")
  }
  let rhs = try! jm.rhs()
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! rhs.get(1, 0)),
    "-g*sin(q(t))/l",
  )) else {
    fail("jointsmethod rhs parity mismatch")
  }
}
