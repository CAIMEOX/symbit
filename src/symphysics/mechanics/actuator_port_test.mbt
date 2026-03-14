///|
fn actuator_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
fn actuator_assert_summary(
  lhs : String,
  rhs : String,
  context : String,
) -> Unit raise {
  guard actuator_compact(lhs) == actuator_compact(rhs) else {
    fail(context + ": ours=" + lhs + "; oracle=" + rhs)
  }
}

///|
fn actuator_load_summary(loads : Array[Load]) -> String {
  "[" +
  loads
  .map(fn(load) {
    match load {
      Load::ForceLoad(value) => value.repr()
      Load::TorqueLoad(value) => value.repr()
    }
  })
  .join(", ") +
  "]"
}

///|
fn actuator_assert_force_load(
  load : Load,
  point_name : String,
  frame : @symvector.ReferenceFrame,
  rhs_x : String,
  rhs_y : String,
  rhs_z : String,
  context : String,
) -> Unit raise {
  match load {
    Load::ForceLoad(value) => {
      guard value.point.name() == point_name else {
        fail(context + ": unexpected point " + value.point.name())
      }
      let comps = value.force.to_matrix(frame)
      let ours_x = @symprint.to_string(try! comps.get(0, 0))
      let ours_y = @symprint.to_string(try! comps.get(1, 0))
      let ours_z = @symprint.to_string(try! comps.get(2, 0))
      guard (try! @sympy_physics.mechanics_expr_equal(ours_x, rhs_x)) else {
        fail(context + ": x mismatch " + ours_x)
      }
      guard (try! @sympy_physics.mechanics_expr_equal(ours_y, rhs_y)) else {
        fail(context + ": y mismatch " + ours_y)
      }
      guard (try! @sympy_physics.mechanics_expr_equal(ours_z, rhs_z)) else {
        fail(context + ": z mismatch " + ours_z)
      }
    }
    _ => fail(context + ": expected force load")
  }
}

///|
fn actuator_assert_torque_load(
  load : Load,
  frame_name : String,
  basis_frame : @symvector.ReferenceFrame,
  rhs_x : String,
  rhs_y : String,
  rhs_z : String,
  context : String,
) -> Unit raise {
  match load {
    Load::TorqueLoad(value) => {
      guard value.frame.name() == frame_name else {
        fail(context + ": unexpected frame " + value.frame.name())
      }
      let comps = value.torque.to_matrix(basis_frame)
      let ours_x = @symprint.to_string(try! comps.get(0, 0))
      let ours_y = @symprint.to_string(try! comps.get(1, 0))
      let ours_z = @symprint.to_string(try! comps.get(2, 0))
      guard (try! @sympy_physics.mechanics_expr_equal(ours_x, rhs_x)) else {
        fail(context + ": x mismatch " + ours_x)
      }
      guard (try! @sympy_physics.mechanics_expr_equal(ours_y, rhs_y)) else {
        fail(context + ": y mismatch " + ours_y)
      }
      guard (try! @sympy_physics.mechanics_expr_equal(ours_z, rhs_z)) else {
        fail(context + ": z mismatch " + ours_z)
      }
    }
    _ => fail(context + ": expected torque load")
  }
}

///|
test "physics.mechanics parity actuators" {
  let n = try! @symvector.reference_frame("APN")
  let p_a = try! @symvector.point("Ap1")
  let p_b = try! @symvector.point("Ap2")
  let q = @symvector.dynamicsymbol("q")
  p_b.set_pos(p_a, n.x().scale(q))
  let pathway = linear_pathway(p_a, p_b).as_pathway()

  let actuator = force_actuator(@symcore.symbol("F"), pathway)
  let force_loads = try! actuator.to_loads()
  actuator_assert_force_load(
    force_loads[0],
    "Ap1",
    n,
    "-F*q(t)/sqrt(q(t)**2)",
    "0",
    "0",
    "force actuator load 0 parity",
  )
  actuator_assert_force_load(
    force_loads[1],
    "Ap2",
    n,
    "F*q(t)/sqrt(q(t)**2)",
    "0",
    "0",
    "force actuator load 1 parity",
  )

  let spring = linear_spring(
    @symcore.symbol("k"),
    pathway,
    equilibrium_length=@symcore.symbol("l"),
  )
  let spring_force_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); k,l=symbols('k l'); pB.set_pos(pA, q*N.x); LinearSpring(k, LinearPathway(pA, pB), equilibrium_length=l).force",
  )
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! spring.force()),
    spring_force_oracle,
  )) else {
    fail("linear spring force parity")
  }

  let damper = linear_damper(@symcore.symbol("c"), pathway)
  let damper_force_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); c=symbols('c'); pB.set_pos(pA, q*N.x); LinearDamper(c, LinearPathway(pA, pB)).force",
  )
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! damper.force()),
    damper_force_oracle,
  )) else {
    fail("linear damper force parity")
  }

  let duffing = duffing_spring(
    @symcore.symbol("k_lin"),
    @symcore.symbol("k_nl"),
    pathway,
  )
  let duffing_force_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); k_lin,k_nl=symbols('k_lin k_nl'); pB.set_pos(pA, q*N.x); DuffingSpring(k_lin, k_nl, LinearPathway(pA, pB)).force",
  )
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! duffing.force()),
    duffing_force_oracle,
  )) else {
    fail("duffing spring force parity")
  }

  let friction = coulomb_kinetic_friction(
    @symcore.symbol("mu_k"),
    @symcore.symbol("Nf"),
    pathway,
    sigma=@symcore.symbol("sigma"),
  )
  let friction_force_oracle = try! @sympy_physics.mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); mu_k,Nf,sigma=symbols('mu_k Nf sigma'); pB.set_pos(pA, q*N.x); CoulombKineticFriction(mu_k, Nf, LinearPathway(pA, pB), sigma=sigma).force",
  )
  guard (try! @sympy_physics.mechanics_expr_equal(
    @symprint.to_string(try! friction.force()),
    friction_force_oracle,
  )) else {
    fail("coulomb friction force parity")
  }

  let target = try! @symvector.reference_frame("TA")
  let reaction = try! @symvector.reference_frame("RA")
  let torque = try! torque_actuator(
    @symcore.symbol("T"),
    n.z(),
    target,
    reaction_frame=Some(reaction),
  )
  let torque_loads = torque.to_loads()
  actuator_assert_torque_load(
    torque_loads[0],
    "TA",
    n,
    "0",
    "0",
    "T",
    "torque actuator load 0 parity",
  )
  actuator_assert_torque_load(
    torque_loads[1],
    "RA",
    n,
    "0",
    "0",
    "-T",
    "torque actuator load 1 parity",
  )
}
