///|
fn vector_list_summary(items : Array[Vector]) -> String {
  "[" + items.map(vsprint).join(", ") + "]"
}

///|
fn vector_nested_summary(items : Array[Array[Vector]]) -> String {
  "[" + items.map(vector_list_summary).join(", ") + "]"
}

///|
test "physics.vector frame/vector core" {
  let n = try! reference_frame("N")
  let q = dynamicsymbol("q")
  let b = try! n.orientnew("B", orient_axis(q, n.z()))

  assert_eq(vsprint(try! b.x().express(n)), "cos(q(t))*N.x + sin(q(t))*N.y")
  assert_eq(vsprint(try! b.y().express(n)), "-sin(q(t))*N.x + cos(q(t))*N.y")
  assert_eq(vsprint(try! b.z().express(n)), "N.z")

  let dcm = try! n.dcm(b)
  assert_eq(
    @symphysics.explicit_matrix_rows_string(dcm),
    "[[cos(q(t)), -sin(q(t)), 0], [sin(q(t)), cos(q(t)), 0], [0, 0, 1]]",
  )

  assert_eq(@symprint.to_string(try! dot(b.x(), b.x())), "1")
  assert_eq(@symprint.to_string(try! dot(b.x(), b.y())), "0")
  assert_eq(vsprint(try! cross(n.x(), n.y())), "N.z")
  assert_eq(vsprint(try! b.x().dt(n)), "Derivative(q(t), t)*B.y")

  let vx = try! b.x().outer(b.y())
  assert_eq(vsprint_dyadic(vx), "(B.x|B.y)")
  assert_eq(
    @symphysics.explicit_matrix_rows_string(try! vx.to_matrix(b)),
    "[[0, 1, 0], [0, 0, 0], [0, 0, 0]]",
  )

  let mapping = try! b.variable_map(n)
  assert_eq(
    @symprint.to_string(mapping["B_x"]),
    "N_x*cos(q(t)) + N_y*sin(q(t))",
  )
  let by_txt = @symprint.to_string(mapping["B_y"])
  guard by_txt == "-N_x*sin(q(t)) + N_y*cos(q(t))" ||
    by_txt == "N_y*cos(q(t)) + -1*N_x*sin(q(t))" else {
    fail("variable_map(B_y)")
  }
}

///|
test "physics.vector named orientation APIs" {
  let n = try! reference_frame("ON")
  let q1 = dynamicsymbol("oq1")
  let q2 = dynamicsymbol("oq2")
  let q3 = dynamicsymbol("oq3")
  let b = try! reference_frame("OB")
  b.orient_body_fixed(n, [q1, q2, q3], "313")
  let b0 = try! b.coord(0)
  guard b.item(0) == b0 else { fail("frame item") }
  guard b.iter_basis().length() == 3 else { fail("frame iter_basis") }
  guard @symphysics.explicit_matrix_rows_string(try! n.dcm(b)).contains(
    "cos(oq1(t))",
  ) else {
    fail("orient_body_fixed")
  }

  let dcm_rows = [
    [@symcore.int(0), @symcore.int(-1), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  ]
  let c = try! reference_frame("OC")
  c.orient_dcm(n, try! @symphysics.explicit_matrix_from_rows(dcm_rows))
  assert_eq(vsprint(try! c.x().express(n)), "ON.y")
}

///|
test "physics.vector kinematics helpers" {
  let q0 = dynamicsymbol("q0")
  let q1 = dynamicsymbol("q1")
  let q2 = dynamicsymbol("q2")
  let q3 = dynamicsymbol("q3")
  let u1 = dynamicsymbol("u1")
  let u2 = dynamicsymbol("u2")
  let u3 = dynamicsymbol("u3")
  let body_ke = try! kinematic_equations(
    [u1, u2, u3],
    [q1, q2, q3],
    "body",
    rot_order="313",
  )
  let body_ok0 = try! @sympy_physics.vector_expr_equal(
    @symprint.to_string(body_ke[0]),
    "u1,u2,u3=dynamicsymbols('u1 u2 u3'); q1,q2,q3=dynamicsymbols('q1 q2 q3'); kinematic_equations([u1,u2,u3], [q1,q2,q3], 'body', 313)[0]",
  )
  let body_ok1 = try! @sympy_physics.vector_expr_equal(
    @symprint.to_string(body_ke[1]),
    "u1,u2,u3=dynamicsymbols('u1 u2 u3'); q1,q2,q3=dynamicsymbols('q1 q2 q3'); kinematic_equations([u1,u2,u3], [q1,q2,q3], 'body', 313)[1]",
  )
  let body_ok2 = try! @sympy_physics.vector_expr_equal(
    @symprint.to_string(body_ke[2]),
    "u1,u2,u3=dynamicsymbols('u1 u2 u3'); q1,q2,q3=dynamicsymbols('q1 q2 q3'); kinematic_equations([u1,u2,u3], [q1,q2,q3], 'body', 313)[2]",
  )
  guard body_ok0 && body_ok1 && body_ok2 else {
    fail("kinematic_equations(body,313)")
  }
  let quat_ke = try! kinematic_equations(
    [u1, u2, u3],
    [q0, q1, q2, q3],
    "quaternion",
  )
  let quat_ok0 = try! @sympy_physics.vector_expr_equal(
    @symprint.to_string(quat_ke[0]),
    "u1,u2,u3=dynamicsymbols('u1 u2 u3'); q0,q1,q2,q3=dynamicsymbols('q0 q1 q2 q3'); kinematic_equations([u1,u2,u3], [q0,q1,q2,q3], 'quaternion')[0]",
  )
  let quat_ok3 = try! @sympy_physics.vector_expr_equal(
    @symprint.to_string(quat_ke[3]),
    "u1,u2,u3=dynamicsymbols('u1 u2 u3'); q0,q1,q2,q3=dynamicsymbols('q0 q1 q2 q3'); kinematic_equations([u1,u2,u3], [q0,q1,q2,q3], 'quaternion')[3]",
  )
  guard quat_ok0 && quat_ok3 else { fail("kinematic_equations(quaternion)") }

  let n = try! reference_frame("KVN")
  let a = try! reference_frame("KVA")
  a.set_ang_vel(n, a.x().scale(u1) + n.y().scale(u2))
  assert_eq(vsprint((try! a.partial_velocity(n, [u1]))[0]), "KVA.x")
  assert_eq(
    vector_list_summary(try! a.partial_velocity(n, [u1, u2])),
    "[KVA.x, KVN.y]",
  )
  assert_eq(
    vector_list_summary(try! n.partial_velocity(a, [u1, u2])),
    "[-KVA.x, -KVN.y]",
  )

  let vel_partials = try! partial_velocity(
    [a.x().scale(u1) + n.z().scale(u2), n.x().scale(u3)],
    [u1, u2, u3],
    n,
  )
  assert_eq(
    vector_nested_summary(vel_partials),
    "[[KVA.x, KVN.z, 0], [0, 0, KVN.x]]",
  )

  let sx = @symcore.symbol("sx")
  let sy = @symcore.symbol("sy")
  let motion = try! get_motion_params(
    n,
    velocity=Some(n.x().scale(sx) + n.y().scale(sy)),
  )
  assert_eq(vsprint(motion.0), "0")
  assert_eq(vsprint(motion.1), "sx*KVN.x + sy*KVN.y")
  let motion_pos_txt = vsprint(motion.2)
  guard motion_pos_txt == "sx*t*KVN.x + sy*t*KVN.y" ||
    motion_pos_txt == "t*sx*KVN.x + t*sy*KVN.y" else {
    fail("get_motion_params")
  }
}

///|
test "physics.vector point kinematics" {
  let n = try! reference_frame("N2")
  let q = dynamicsymbol("q2")
  let b = try! n.orientnew("B2", orient_axis(q, n.z()))
  let o = try! point("O")
  let p = try! o.locatenew("P", b.x())
  o.set_vel(n, vector_zero())
  assert_eq(vsprint(try! p.v2pt_theory(o, n, b)), "Derivative(q2(t), t)*B2.y")
  assert_eq(
    vsprint(try! p.a2pt_theory(o, n, b)),
    "-Derivative(q2(t), t)**2*B2.x + Derivative(Derivative(q2(t), t), t)*B2.y",
  )

  let u = dynamicsymbol("u")
  let q3 = dynamicsymbol("q3")
  let qframe = try! reference_frame("N3")
  let base = try! point("Base")
  let child = try! point("Child")
  child.set_pos(base, qframe.x().scale(q3))
  base.set_vel(qframe, qframe.y().scale(u))
  assert_eq(
    vsprint(try! child.vel(qframe)),
    "Derivative(q3(t), t)*N3.x + u(t)*N3.y",
  )
  assert_eq(vsprint(try! child.partial_velocity(qframe, u)), "N3.y")
}

///|
test "physics.vector fieldfunctions" {
  let r = try! reference_frame("R")
  let rx = try! r.coord(0)
  let ry = try! r.coord(1)
  let rz = try! r.coord(2)
  let scalar = rx * ry * rz
  assert_eq(
    vsprint(gradient(scalar, r)),
    "R_y*R_z*R.x + R_x*R_z*R.y + R_x*R_y*R.z",
  )
  let field = r.x().scale(rx * ry) + r.z().scale(rx * ry * rz)
  assert_eq(vsprint(try! curl(field, r)), "R_x*R_z*R.x - R_y*R_z*R.y - R_x*R.z")
  let div_txt = @symprint.to_string(try! divergence(field, r))
  guard div_txt == "R_y + R_x*R_y" || div_txt == "R_x*R_y + R_y" else {
    fail("divergence")
  }
  assert_true(try! is_conservative(gradient(scalar, r)))
  assert_true(try! is_solenoidal(try! curl(field, r)))

  let pot = try! scalar_potential(gradient(scalar, r), r)
  assert_eq(@symprint.to_string(pot), "R_x*R_y*R_z")

  let origin = try! point("OR")
  let p1 = try! origin.locatenew(
    "P1",
    r.x().scale(@symcore.int(1)) +
    r.y().scale(@symcore.int(2)) +
    r.z().scale(@symcore.int(3)),
  )
  let p2 = try! origin.locatenew(
    "P2",
    r.x().scale(@symcore.int(4)) +
    r.y().scale(@symcore.int(5)) +
    r.z().scale(@symcore.int(6)),
  )
  assert_eq(
    @symprint.to_string(
      try! scalar_potential_difference_field(
        gradient(scalar, r),
        r,
        p1,
        p2,
        origin,
      ),
    ),
    "114",
  )

  let mag = try! (r.x() + r.y()).magnitude()
  assert_eq(@symprint.to_string(mag), "sqrt(2)")
  let angle = try! r.x().angle_between(r.y())
  let angle_txt = @symprint.to_string(angle)
  guard angle_txt == "pi/2" || angle_txt == "1/2*pi" else {
    fail("angle_between")
  }
}
