///|
fn mechanics_joint_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
test "physics.mechanics parity joints" {
  let n = try! @symvector.reference_frame("QJN")
  let origin = try! @symvector.point("QJO")
  origin.set_vel(n, @symvector.vector_zero())
  let parent = try! rigid_body("QP", masscenter=Some(origin), frame=Some(n))
  let child = try! rigid_body("QC")
  let pin = try! pin_joint("QPC", parent.as_bodylike(), child.as_bodylike())

  guard pin.repr() == "PinJoint: QPC  parent: QP  child: QC" else {
    fail("pin joint repr mismatch")
  }
  guard @symprint.to_string(pin.coordinates()[0]) == "q_QPC(t)" else {
    fail("pin joint coordinate mismatch")
  }
  guard @symprint.to_string(pin.speeds()[0]) == "u_QPC(t)" else {
    fail("pin joint speed mismatch")
  }
  let pin_ang_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); C=RigidBody('QC'); J=PinJoint('QPC', P, C); [[str(x) for x in row] for row in C.frame.ang_vel_in(P.frame).to_matrix(P.frame).tolist()]",
  )
  guard mechanics_joint_compact(
      @symphysics.explicit_matrix_rows_string(
        try! child.frame().ang_vel_in(parent.frame()).to_matrix(parent.frame()),
      ),
    ) ==
    mechanics_joint_compact(pin_ang_oracle) else {
    fail("pin joint angular velocity parity")
  }
  let pin_pos_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); C=RigidBody('QC'); J=PinJoint('QPC', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  guard mechanics_joint_compact(
      @symvector.vsprint(try! pin.child_point().pos_from(pin.parent_point())),
    ) ==
    mechanics_joint_compact(pin_pos_oracle) else {
    fail("pin joint position parity")
  }
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! child.frame().dcm(parent.frame()),
    ),
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); C=RigidBody('QC'); J=PinJoint('QPC', P, C); C.frame.dcm(P.frame)",
  )) else {
    fail("pin joint dcm parity")
  }

  let slider = try! rigid_body("QS")
  let prism = try! prismatic_joint(
    "QPS",
    parent.as_bodylike(),
    slider.as_bodylike(),
  )
  guard prism.repr() == "PrismaticJoint: QPS  parent: QP  child: QS" else {
    fail("prismatic joint repr mismatch")
  }
  guard @symprint.to_string(prism.coordinates()[0]) == "q_QPS(t)" else {
    fail("prismatic joint coordinate mismatch")
  }
  let prism_ang_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); S=RigidBody('QS'); J=PrismaticJoint('QPS', P, S); [[str(x) for x in row] for row in S.frame.ang_vel_in(P.frame).to_matrix(P.frame).tolist()]",
  )
  guard mechanics_joint_compact(
      @symphysics.explicit_matrix_rows_string(
        try! slider.frame().ang_vel_in(parent.frame()).to_matrix(parent.frame()),
      ),
    ) ==
    mechanics_joint_compact(prism_ang_oracle) else {
    fail("prismatic joint angular velocity parity")
  }
  let prism_pos_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); S=RigidBody('QS'); J=PrismaticJoint('QPS', P, S); str(J.child_point.pos_from(J.parent_point))",
  )
  guard mechanics_joint_compact(
      @symvector.vsprint(
        try! prism.child_point().pos_from(prism.parent_point()),
      ),
    ) ==
    mechanics_joint_compact(prism_pos_oracle) else {
    fail("prismatic joint position parity")
  }
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! slider.frame().dcm(parent.frame()),
    ),
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); S=RigidBody('QS'); J=PrismaticJoint('QPS', P, S); S.frame.dcm(P.frame)",
  )) else {
    fail("prismatic joint dcm parity")
  }
}

///|
test "physics.mechanics parity advanced joints" {
  let n = try! @symvector.reference_frame("PJN")
  let origin = try! @symvector.point("PJO")
  origin.set_vel(n, @symvector.vector_zero())
  let parent = try! rigid_body("PP", masscenter=Some(origin), frame=Some(n))

  let cyl_child = try! rigid_body("PC")
  let cyl = try! cylindrical_joint(
    "QCY",
    parent.as_bodylike(),
    cyl_child.as_bodylike(),
  )
  guard @symprint.to_string(cyl.rotation_coordinate()) == "q0_QCY(t)" else {
    fail("cylindrical rotation coordinate mismatch")
  }
  guard @symprint.to_string(cyl.translation_coordinate()) == "q1_QCY(t)" else {
    fail("cylindrical translation coordinate mismatch")
  }
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! cyl_child.frame().dcm(parent.frame()),
    ),
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PC'); J=CylindricalJoint('QCY', P, C); C.frame.dcm(P.frame)",
  )) else {
    fail("cylindrical dcm parity")
  }
  let cyl_pos_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PC'); J=CylindricalJoint('QCY', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  guard mechanics_joint_compact(
      @symvector.vsprint(try! cyl.child_point().pos_from(cyl.parent_point())),
    ) ==
    mechanics_joint_compact(cyl_pos_oracle) else {
    fail("cylindrical position parity")
  }

  let planar_child = try! rigid_body("PL")
  let planar = try! planar_joint(
    "QPL",
    parent.as_bodylike(),
    planar_child.as_bodylike(),
  )
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! planar_child.frame().dcm(parent.frame()),
    ),
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PL'); J=PlanarJoint('QPL', P, C); C.frame.dcm(P.frame)",
  )) else {
    fail("planar dcm parity")
  }
  let planar_pos_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PL'); J=PlanarJoint('QPL', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  guard mechanics_joint_compact(
      @symvector.vsprint(
        try! planar.child_point().pos_from(planar.parent_point()),
      ),
    ) ==
    mechanics_joint_compact(planar_pos_oracle) else {
    fail("planar position parity")
  }

  let spherical_child = try! rigid_body("PS")
  ignore(
    try! spherical_joint(
      "QSP",
      parent.as_bodylike(),
      spherical_child.as_bodylike(),
    ),
  )
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! spherical_child.frame().dcm(parent.frame()),
    ),
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PS'); J=SphericalJoint('QSP', P, C); C.frame.dcm(P.frame)",
  )) else {
    fail("spherical dcm parity")
  }
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! spherical_child
      .frame()
      .ang_vel_in(parent.frame())
      .to_matrix(spherical_child.frame()),
    ),
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PS'); J=SphericalJoint('QSP', P, C); C.frame.ang_vel_in(P.frame).to_matrix(C.frame)",
  )) else {
    fail("spherical angular velocity parity")
  }

  let weld_child = try! rigid_body("PW")
  let weld = try! weld_joint(
    "QWD",
    parent.as_bodylike(),
    weld_child.as_bodylike(),
  )
  guard (try! @sympy_physics.mechanics_matrix_equal(
    @symphysics.explicit_matrix_rows_string(
      try! weld_child.frame().dcm(parent.frame()),
    ),
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PW'); J=WeldJoint('QWD', P, C); C.frame.dcm(P.frame)",
  )) else {
    fail("weld dcm parity")
  }
  let weld_pos_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PW'); J=WeldJoint('QWD', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  guard mechanics_joint_compact(
      @symvector.vsprint(try! weld.child_point().pos_from(weld.parent_point())),
    ) ==
    mechanics_joint_compact(weld_pos_oracle) else {
    fail("weld position parity")
  }
}
