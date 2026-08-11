///|
fn mechanics_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
fn mechanics_assert_summary(
  lhs : String,
  rhs : String,
  _context : String,
) -> Unit raise {
  assert_eq(mechanics_compact(lhs), mechanics_compact(rhs))
}

///|
test "physics.mechanics parity inertia and particles" {
  let n = @symvector.reference_frame("ON")
  let ixx = @symcore.Expr::Symbol("ixx")
  let iyy = @symcore.Expr::Symbol("iyy")
  let izz = @symcore.Expr::Symbol("izz")
  let ixy = @symcore.Expr::Symbol("ixy")
  let iyz = @symcore.Expr::Symbol("iyz")
  let izx = @symcore.Expr::Symbol("izx")
  mechanics_assert_summary(
    @symvector.vsprint_dyadic(inertia(n, ixx, iyy, izz, ixy~, iyz~, izx~)),
    mechanics_summary(
      "N=ReferenceFrame('ON'); ixx,iyy,izz,ixy,iyz,izx=symbols('ixx iyy izz ixy iyz izx'); inertia(N, ixx, iyy, izz, ixy, iyz, izx)",
    ),
    "inertia parity",
  )

  let o = @symvector.point("OO")
  let p = o.locatenew("OP", n.y().scale(Symbol("r")))
  p.set_vel(n, n.x().scale(Symbol("v")))
  let part = particle("P", point=Some(p), mass=Some(Symbol("m")))
  mechanics_assert_summary(
    @symvector.vsprint(part.linear_momentum(n)),
    mechanics_summary(
      "N=ReferenceFrame('ON'); O=Point('OO'); r,v,m=symbols('r v m'); P=O.locatenew('OP', r*N.y); P.set_vel(N, v*N.x); Particle('P', P, m).linear_momentum(N)",
    ),
    "particle linear momentum parity",
  )
  mechanics_assert_summary(
    @symvector.vsprint(part.angular_momentum(o, n)),
    mechanics_summary(
      "N=ReferenceFrame('ON'); O=Point('OO'); r,v,m=symbols('r v m'); P=O.locatenew('OP', r*N.y); P.set_vel(N, v*N.x); Particle('P', P, m).angular_momentum(O, N)",
    ),
    "particle angular momentum parity",
  )
}

///|
test "physics.mechanics parity rigidbody wrappers and body loads" {
  let n = @symvector.reference_frame("RN")
  let p = @symvector.point("RP")
  p.set_vel(n, n.x().scale(Symbol("v")))
  let b = @symvector.reference_frame("Rb")
  b.set_ang_vel(n, b.x().scale(Symbol("omega")))
  let rb = rigid_body(
    "RB",
    masscenter=Some(p),
    frame=Some(b),
    mass=Some(Symbol("m")),
    inertia=Some(inertia_tuple(@symvector.outer(b.x(), b.x()), p)),
  )
  assert_true(
    expr_equal(
      @symprint.pretty_string(rb.kinetic_energy(n)),
      mechanics_eval(
        "m,v,omega=symbols('m v omega'); N=ReferenceFrame('RN'); b=ReferenceFrame('Rb'); b.set_ang_vel(N, omega*b.x); P=Point('RP'); P.set_vel(N, v*N.x); RB=RigidBody('RB', P, b, m, (outer(b.x, b.x), P)); RB.kinetic_energy(N)",
      ),
    ),
  )

  let legacy = body("LB")
  legacy.apply_force(legacy.x())
  legacy.apply_torque(legacy.z())
  mechanics_assert_summary(
    "[" +
    legacy
    .loads()
    .map(fn(load) {
      match load {
        ForceLoad(value) =>
          "(" +
          value.point.name() +
          ", " +
          @symvector.vsprint(value.force) +
          ")"
        TorqueLoad(value) =>
          "(" +
          value.frame.name() +
          ", " +
          @symvector.vsprint(value.torque) +
          ")"
      }
    })
    .join(", ") +
    "]",
    mechanics_summary(
      "B=Body('LB'); B.apply_force(B.x); B.apply_torque(B.z); B.loads",
    ),
    "legacy body loads parity",
  )
}
