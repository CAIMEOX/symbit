///|
fn vector_list_summary_port(items : Array[Vector]) -> String {
  "[" + items.map(vsprint).join(", ") + "]"
}

///|
fn vector_tuple_summary_port(items : Array[Vector]) -> String {
  "(" + items.map(vsprint).join(", ") + ")"
}

///|
fn vector_nested_summary_port(items : Array[Array[Vector]]) -> String {
  "[" + items.map(vector_list_summary_port).join(", ") + "]"
}

///|
test "physics.vector parity axis orientation and express" {
  let n = reference_frame("PN")
  let q = dynamicsymbol("qp")
  let b = n.orientnew("PB", orient_axis(q, n.z()))
  assert_eq(
    vsprint(b.x().express(n)),
    vector_eval(
      "N=ReferenceFrame('PN'); q=dynamicsymbols('qp'); B=N.orientnew('PB','Axis',[q,N.z]); B.x.express(N)",
    ),
  )
  assert_eq(
    @symphysics.explicit_matrix_rows_string(n.dcm(b)),
    "[" +
    vector_matrix_rows(
      "N=ReferenceFrame('PN'); q=dynamicsymbols('qp'); B=N.orientnew('PB','Axis',[q,N.z]); N.dcm(B)",
    ).join(", ") +
    "]",
  )
}

///|
test "physics.vector parity named orientation APIs" {
  let n = reference_frame("PON")
  let q1 = dynamicsymbol("poq1")
  let q2 = dynamicsymbol("poq2")
  let q3 = dynamicsymbol("poq3")
  let b = reference_frame("POB")
  b.orient_body_fixed(n, [q1, q2, q3], "313")
  assert_true(
    vector_matrix_equal(
      @symphysics.explicit_matrix_rows_string(n.dcm(b)),
      "N=ReferenceFrame('PON'); q1,q2,q3=dynamicsymbols('poq1 poq2 poq3'); B=ReferenceFrame('POB'); B.orient_body_fixed(N, (q1, q2, q3), '313'); N.dcm(B)",
    ),
  )

  let dcm_rows = [
    [@symcore.int(0), @symcore.int(-1), @symcore.int(0)],
    [@symcore.int(1), @symcore.int(0), @symcore.int(0)],
    [@symcore.int(0), @symcore.int(0), @symcore.int(1)],
  ]
  let c = reference_frame("POC")
  c.orient_explicit(n, @symphysics.explicit_matrix_from_rows(dcm_rows))
  assert_eq(
    vsprint(c.x().express(n)),
    vector_eval(
      "N=ReferenceFrame('PON'); C=ReferenceFrame('POC'); C.orient_explicit(N, Matrix([[0,-1,0],[1,0,0],[0,0,1]])); C.x.express(N)",
    ),
  )
}

///|
test "physics.vector parity kinematics helpers" {
  let q0 = dynamicsymbol("pq0")
  let q1 = dynamicsymbol("pq1")
  let q2 = dynamicsymbol("pq2")
  let q3 = dynamicsymbol("pq3")
  let u1 = dynamicsymbol("pu1")
  let u2 = dynamicsymbol("pu2")
  let u3 = dynamicsymbol("pu3")
  let body_ke = kinematic_equations(
    [u1, u2, u3],
    [q1, q2, q3],
    "body",
    rot_order="313",
  )
  assert_true(
    vector_expr_equal(
      @symprint.pretty_string(body_ke[0]),
      "u1,u2,u3=dynamicsymbols('pu1 pu2 pu3'); q1,q2,q3=dynamicsymbols('pq1 pq2 pq3'); kinematic_equations([u1,u2,u3], [q1,q2,q3], 'body', 313)[0]",
    ),
  )
  assert_true(
    vector_expr_equal(
      @symprint.pretty_string(body_ke[1]),
      "u1,u2,u3=dynamicsymbols('pu1 pu2 pu3'); q1,q2,q3=dynamicsymbols('pq1 pq2 pq3'); kinematic_equations([u1,u2,u3], [q1,q2,q3], 'body', 313)[1]",
    ),
  )
  assert_true(
    vector_expr_equal(
      @symprint.pretty_string(body_ke[2]),
      "u1,u2,u3=dynamicsymbols('pu1 pu2 pu3'); q1,q2,q3=dynamicsymbols('pq1 pq2 pq3'); kinematic_equations([u1,u2,u3], [q1,q2,q3], 'body', 313)[2]",
    ),
  )
  let quat_ke = kinematic_equations(
    [u1, u2, u3],
    [q0, q1, q2, q3],
    "quaternion",
  )
  assert_true(
    vector_expr_equal(
      @symprint.pretty_string(quat_ke[0]),
      "u1,u2,u3=dynamicsymbols('pu1 pu2 pu3'); q0,q1,q2,q3=dynamicsymbols('pq0 pq1 pq2 pq3'); kinematic_equations([u1,u2,u3], [q0,q1,q2,q3], 'quaternion')[0]",
    ),
  )
  assert_true(
    vector_expr_equal(
      @symprint.pretty_string(quat_ke[3]),
      "u1,u2,u3=dynamicsymbols('pu1 pu2 pu3'); q0,q1,q2,q3=dynamicsymbols('pq0 pq1 pq2 pq3'); kinematic_equations([u1,u2,u3], [q0,q1,q2,q3], 'quaternion')[3]",
    ),
  )

  let n = reference_frame("PVN")
  let a = reference_frame("PVA")
  a.set_ang_vel(n, a.x().scale(u1) + n.y().scale(u2))
  assert_eq(
    vector_tuple_summary_port(a.partial_velocity(n, [u1, u2])),
    vector_summary(
      "u1,u2=dynamicsymbols('pu1 pu2'); N=ReferenceFrame('PVN'); A=ReferenceFrame('PVA'); A.set_ang_vel(N, u1*A.x + u2*N.y); A.partial_velocity(N, u1, u2)",
    ),
  )
  assert_eq(
    vector_nested_summary_port(
      partial_velocity(
        [a.x().scale(u1) + n.z().scale(u2), n.x().scale(u3)],
        [u1, u2, u3],
        n,
      ),
    ),
    vector_summary(
      "u1,u2,u3=dynamicsymbols('pu1 pu2 pu3'); N=ReferenceFrame('PVN'); A=ReferenceFrame('PVA'); partial_velocity([u1*A.x + u2*N.z, u3*N.x], [u1, u2, u3], N)",
    ),
  )
  let sx = @symcore.Expr::Symbol("psx")
  let sy = @symcore.Expr::Symbol("psy")
  let motion = get_motion_params(
    n,
    velocity=Some(n.x().scale(sx) + n.y().scale(sy)),
  )
  assert_true(motion.0.is_zero())
  assert_true(
    vector_matrix_equal(
      @symphysics.explicit_matrix_rows_string(motion.1.to_matrix(n)),
      "psx,psy=symbols('psx psy'); N=ReferenceFrame('PVN'); get_motion_params(N, velocity=psx*N.x + psy*N.y)[1].to_matrix(N)",
    ),
  )
  assert_true(
    vector_matrix_equal(
      @symphysics.explicit_matrix_rows_string(motion.2.to_matrix(n)),
      "psx,psy=symbols('psx psy'); N=ReferenceFrame('PVN'); get_motion_params(N, velocity=psx*N.x + psy*N.y)[2].to_matrix(N)",
    ),
  )
}

///|
test "physics.vector parity dyadic and derivatives" {
  let n = reference_frame("DN")
  let q = dynamicsymbol("dq")
  let b = n.orientnew("DB", orient_axis(q, n.z()))
  let dy = n.x().outer(n.x())
  assert_true(
    vector_matrix_equal(
      @symphysics.explicit_matrix_rows_string(dy.express(b).to_matrix(b)),
      "N=ReferenceFrame('DN'); q=dynamicsymbols('dq'); B=N.orientnew('DB','Axis',[q,N.z]); ((N.x|N.x).express(B)).to_matrix(B)",
    ),
  )
  assert_eq(
    vsprint(b.x().dt(n)),
    vector_eval(
      "N=ReferenceFrame('DN'); q=dynamicsymbols('dq'); B=N.orientnew('DB','Axis',[q,N.z]); B.x.dt(N)",
    ),
  )
}

///|
test "physics.vector parity points and fieldfunctions" {
  let n = reference_frame("QN")
  let q = dynamicsymbol("qq")
  let b = n.orientnew("QB", orient_axis(q, n.z()))
  let o = point("QO")
  let p = o.locatenew("QP", b.x())
  o.set_vel(n, vector_zero())
  assert_eq(
    vsprint(p.v2pt_theory(o, n, b)),
    vector_eval(
      "N=ReferenceFrame('QN'); q=dynamicsymbols('qq'); B=N.orientnew('QB','Axis',[q,N.z]); O=Point('QO'); P=O.locatenew('QP', B.x); O.set_vel(N, 0); P.v2pt_theory(O, N, B)",
    ),
  )

  let r = reference_frame("QR")
  let rx = r.coord(0)
  let ry = r.coord(1)
  let rz = r.coord(2)
  let scalar = rx * ry * rz
  assert_eq(
    vsprint(gradient(scalar, r)),
    vector_eval("R=ReferenceFrame('QR'); gradient(R[0]*R[1]*R[2], R)"),
  )
  assert_eq(
    @symprint.pretty_string(
      divergence(r.x().scale(rx * ry) + r.z().scale(rx * ry * rz), r),
    ),
    vector_eval(
      "R=ReferenceFrame('QR'); divergence(R[0]*R[1]*R.x + R[0]*R[1]*R[2]*R.z, R)",
    ),
  )
}
