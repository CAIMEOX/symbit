///|
fn mechanics_joint_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
test "physics.mechanics parity joints" {
  let n = @symvector.reference_frame("QJN")
  let origin = @symvector.point("QJO")
  origin.set_vel(n, @symvector.vector_zero())
  let parent = rigid_body("QP", masscenter=Some(origin), frame=Some(n))
  let child = rigid_body("QC")
  let pin = pin_joint("QPC", parent.as_bodylike(), child.as_bodylike())

  assert_eq(pin.repr(), "PinJoint: QPC  parent: QP  child: QC")
  assert_eq(@symprint.to_string(pin.coordinates()[0]), "q_QPC(t)")
  assert_eq(@symprint.to_string(pin.speeds()[0]), "u_QPC(t)")
  let pin_ang_oracle = mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); C=RigidBody('QC'); J=PinJoint('QPC', P, C); [[str(x) for x in row] for row in C.frame.ang_vel_in(P.frame).to_matrix(P.frame).tolist()]",
  )
  assert_eq(mechanics_joint_compact(
          @symphysics.explicit_matrix_rows_string(
            child.frame().ang_vel_in(parent.frame()).to_matrix(parent.frame()),
          ),
        ), mechanics_joint_compact(pin_ang_oracle))
  let pin_pos_oracle = mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); C=RigidBody('QC'); J=PinJoint('QPC', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  assert_eq(mechanics_joint_compact(
          @symvector.vsprint(pin.child_point().pos_from(pin.parent_point())),
        ), mechanics_joint_compact(pin_pos_oracle))
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(child.frame().dcm(parent.frame())),
        "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); C=RigidBody('QC'); J=PinJoint('QPC', P, C); C.frame.dcm(P.frame)",
      )
  )

  let slider = rigid_body("QS")
  let prism = prismatic_joint("QPS", parent.as_bodylike(), slider.as_bodylike())
  assert_eq(prism.repr(), "PrismaticJoint: QPS  parent: QP  child: QS")
  assert_eq(@symprint.to_string(prism.coordinates()[0]), "q_QPS(t)")
  let prism_ang_oracle = mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); S=RigidBody('QS'); J=PrismaticJoint('QPS', P, S); [[str(x) for x in row] for row in S.frame.ang_vel_in(P.frame).to_matrix(P.frame).tolist()]",
  )
  assert_eq(mechanics_joint_compact(
          @symphysics.explicit_matrix_rows_string(
            slider.frame().ang_vel_in(parent.frame()).to_matrix(parent.frame()),
          ),
        ), mechanics_joint_compact(prism_ang_oracle))
  let prism_pos_oracle = mechanics_summary(
    "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); S=RigidBody('QS'); J=PrismaticJoint('QPS', P, S); str(J.child_point.pos_from(J.parent_point))",
  )
  assert_eq(mechanics_joint_compact(
          @symvector.vsprint(prism.child_point().pos_from(prism.parent_point())),
        ), mechanics_joint_compact(prism_pos_oracle))
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(slider.frame().dcm(parent.frame())),
        "N=ReferenceFrame('QJN'); O=Point('QJO'); O.set_vel(N, 0); P=RigidBody('QP', O, N); S=RigidBody('QS'); J=PrismaticJoint('QPS', P, S); S.frame.dcm(P.frame)",
      )
  )
}

///|
test "physics.mechanics parity advanced joints" {
  let n = @symvector.reference_frame("PJN")
  let origin = @symvector.point("PJO")
  origin.set_vel(n, @symvector.vector_zero())
  let parent = rigid_body("PP", masscenter=Some(origin), frame=Some(n))

  let cyl_child = rigid_body("PC")
  let cyl = cylindrical_joint(
    "QCY",
    parent.as_bodylike(),
    cyl_child.as_bodylike(),
  )
  assert_eq(@symprint.to_string(cyl.rotation_coordinate()), "q0_QCY(t)")
  assert_eq(@symprint.to_string(cyl.translation_coordinate()), "q1_QCY(t)")
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(
          cyl_child.frame().dcm(parent.frame()),
        ),
        "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PC'); J=CylindricalJoint('QCY', P, C); C.frame.dcm(P.frame)",
      )
  )
  let cyl_pos_oracle = mechanics_summary(
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PC'); J=CylindricalJoint('QCY', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  assert_eq(mechanics_joint_compact(
          @symvector.vsprint(cyl.child_point().pos_from(cyl.parent_point())),
        ), mechanics_joint_compact(cyl_pos_oracle))

  let planar_child = rigid_body("PL")
  let planar = planar_joint(
    "QPL",
    parent.as_bodylike(),
    planar_child.as_bodylike(),
  )
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(
          planar_child.frame().dcm(parent.frame()),
        ),
        "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PL'); J=PlanarJoint('QPL', P, C); C.frame.dcm(P.frame)",
      )
  )
  let planar_pos_oracle = mechanics_summary(
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PL'); J=PlanarJoint('QPL', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  assert_eq(mechanics_joint_compact(
          @symvector.vsprint(planar.child_point().pos_from(planar.parent_point())),
        ), mechanics_joint_compact(planar_pos_oracle))

  let spherical_child = rigid_body("PS")
  ignore(
    spherical_joint("QSP", parent.as_bodylike(), spherical_child.as_bodylike()),
  )
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(
          spherical_child.frame().dcm(parent.frame()),
        ),
        "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PS'); J=SphericalJoint('QSP', P, C); C.frame.dcm(P.frame)",
      )
  )
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(
          spherical_child
          .frame()
          .ang_vel_in(parent.frame())
          .to_matrix(spherical_child.frame()),
        ),
        "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PS'); J=SphericalJoint('QSP', P, C); C.frame.ang_vel_in(P.frame).to_matrix(C.frame)",
      )
  )

  let weld_child = rigid_body("PW")
  let weld = weld_joint("QWD", parent.as_bodylike(), weld_child.as_bodylike())
  assert_true(
    mechanics_matrix_equal(
        @symphysics.explicit_matrix_rows_string(
          weld_child.frame().dcm(parent.frame()),
        ),
        "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PW'); J=WeldJoint('QWD', P, C); C.frame.dcm(P.frame)",
      )
  )
  let weld_pos_oracle = mechanics_summary(
    "N=ReferenceFrame('PJN'); O=Point('PJO'); O.set_vel(N, 0); P=RigidBody('PP', O, N); C=RigidBody('PW'); J=WeldJoint('QWD', P, C); str(J.child_point.pos_from(J.parent_point))",
  )
  assert_eq(mechanics_joint_compact(
          @symvector.vsprint(weld.child_point().pos_from(weld.parent_point())),
        ), mechanics_joint_compact(weld_pos_oracle))
}
