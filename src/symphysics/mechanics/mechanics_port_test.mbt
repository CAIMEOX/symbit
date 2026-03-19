///|
fn mechanics_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
fn mechanics_assert_summary(
  lhs : String,
  rhs : String,
  context : String,
) -> Unit raise {
  guard mechanics_compact(lhs) == mechanics_compact(rhs) else {
    fail(context + ": ours=" + lhs + "; oracle=" + rhs)
  }
}

///|
test "physics.mechanics parity inertia and particles" {
  let n = @symvector.reference_frame("ON")
  let ixx = @symcore.symbol("ixx")
  let iyy = @symcore.symbol("iyy")
  let izz = @symcore.symbol("izz")
  let ixy = @symcore.symbol("ixy")
  let iyz = @symcore.symbol("iyz")
  let izx = @symcore.symbol("izx")
  mechanics_assert_summary(
    @symvector.vsprint_dyadic(inertia(n, ixx, iyy, izz, ixy~, iyz~, izx~)),
    @sympy_physics.mechanics_summary(
      "N=ReferenceFrame('ON'); ixx,iyy,izz,ixy,iyz,izx=symbols('ixx iyy izz ixy iyz izx'); inertia(N, ixx, iyy, izz, ixy, iyz, izx)",
    ),
    "inertia parity",
  )

  let o = @symvector.point("OO")
  let p = o.locatenew("OP", n.y().scale(@symcore.symbol("r")))
  p.set_vel(n, n.x().scale(@symcore.symbol("v")))
  let part = particle("P", point=Some(p), mass=Some(@symcore.symbol("m")))
  mechanics_assert_summary(
    @symvector.vsprint(part.linear_momentum(n)),
    @sympy_physics.mechanics_summary(
      "N=ReferenceFrame('ON'); O=Point('OO'); r,v,m=symbols('r v m'); P=O.locatenew('OP', r*N.y); P.set_vel(N, v*N.x); Particle('P', P, m).linear_momentum(N)",
    ),
    "particle linear momentum parity",
  )
  mechanics_assert_summary(
    @symvector.vsprint(part.angular_momentum(o, n)),
    @sympy_physics.mechanics_summary(
      "N=ReferenceFrame('ON'); O=Point('OO'); r,v,m=symbols('r v m'); P=O.locatenew('OP', r*N.y); P.set_vel(N, v*N.x); Particle('P', P, m).angular_momentum(O, N)",
    ),
    "particle angular momentum parity",
  )
}

///|
test "physics.mechanics parity rigidbody wrappers and body loads" {
  let n = @symvector.reference_frame("RN")
  let p = @symvector.point("RP")
  p.set_vel(n, n.x().scale(@symcore.symbol("v")))
  let b = @symvector.reference_frame("Rb")
  b.set_ang_vel(n, b.x().scale(@symcore.symbol("omega")))
  let rb = rigid_body(
    "RB",
    masscenter=Some(p),
    frame=Some(b),
    mass=Some(@symcore.symbol("m")),
    inertia=Some(inertia_tuple(@symvector.outer(b.x(), b.x()), p)),
  )
  guard @sympy_physics.expr_equal(
    @symprint.to_string(rb.kinetic_energy(n)),
    @sympy_physics.mechanics_eval(
      "m,v,omega=symbols('m v omega'); N=ReferenceFrame('RN'); b=ReferenceFrame('Rb'); b.set_ang_vel(N, omega*b.x); P=Point('RP'); P.set_vel(N, v*N.x); RB=RigidBody('RB', P, b, m, (outer(b.x, b.x), P)); RB.kinetic_energy(N)",
    ),
  ) else {
    fail("rigidbody kinetic energy parity")
  }

  let legacy = body("LB")
  legacy.apply_force(legacy.x())
  legacy.apply_torque(legacy.z())
  mechanics_assert_summary(
    "[" +
    legacy
    .loads()
    .map(fn(load) {
      match load {
        Load::ForceLoad(value) =>
          "(" +
          value.point.name() +
          ", " +
          @symvector.vsprint(value.force) +
          ")"
        Load::TorqueLoad(value) =>
          "(" +
          value.frame.name() +
          ", " +
          @symvector.vsprint(value.torque) +
          ")"
      }
    })
    .join(", ") +
    "]",
    @sympy_physics.mechanics_summary(
      "B=Body('LB'); B.apply_force(B.x); B.apply_torque(B.z); B.loads",
    ),
    "legacy body loads parity",
  )
}
