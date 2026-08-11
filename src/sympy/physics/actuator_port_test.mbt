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
    ForceLoad(value) => {
      assert_eq(value.point.name(), point_name)
      let comps = value.force.to_matrix(frame)
      let ours_x = @symprint.pretty_string(comps.get(0, 0))
      let ours_y = @symprint.pretty_string(comps.get(1, 0))
      let ours_z = @symprint.pretty_string(comps.get(2, 0))
      assert_true(mechanics_expr_equal(ours_x, rhs_x))
      assert_true(mechanics_expr_equal(ours_y, rhs_y))
      assert_true(mechanics_expr_equal(ours_z, rhs_z))
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
    TorqueLoad(value) => {
      assert_eq(value.frame.name(), frame_name)
      let comps = value.torque.to_matrix(basis_frame)
      let ours_x = @symprint.pretty_string(comps.get(0, 0))
      let ours_y = @symprint.pretty_string(comps.get(1, 0))
      let ours_z = @symprint.pretty_string(comps.get(2, 0))
      assert_true(mechanics_expr_equal(ours_x, rhs_x))
      assert_true(mechanics_expr_equal(ours_y, rhs_y))
      assert_true(mechanics_expr_equal(ours_z, rhs_z))
    }
    _ => fail(context + ": expected torque load")
  }
}

///|
test "physics.mechanics parity actuators" {
  let n = @symvector.reference_frame("APN")
  let p_a = @symvector.point("Ap1")
  let p_b = @symvector.point("Ap2")
  let q = @symvector.dynamicsymbol("q")
  p_b.set_pos(p_a, n.x().scale(q))
  let pathway = linear_pathway(p_a, p_b).as_pathway()

  let actuator = force_actuator(Symbol("F"), pathway)
  let force_loads = actuator.to_loads()
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
    Symbol("k"),
    pathway,
    equilibrium_length=Symbol("l"),
  )
  let spring_force_oracle = mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); k,l=symbols('k l'); pB.set_pos(pA, q*N.x); LinearSpring(k, LinearPathway(pA, pB), equilibrium_length=l).force",
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(spring.force()),
      spring_force_oracle,
    ),
  )

  let damper = linear_damper(Symbol("c"), pathway)
  let damper_force_oracle = mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); c=symbols('c'); pB.set_pos(pA, q*N.x); LinearDamper(c, LinearPathway(pA, pB)).force",
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(damper.force()),
      damper_force_oracle,
    ),
  )

  let duffing = duffing_spring(Symbol("k_lin"), Symbol("k_nl"), pathway)
  let duffing_force_oracle = mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); k_lin,k_nl=symbols('k_lin k_nl'); pB.set_pos(pA, q*N.x); DuffingSpring(k_lin, k_nl, LinearPathway(pA, pB)).force",
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(duffing.force()),
      duffing_force_oracle,
    ),
  )

  let friction = coulomb_kinetic_friction(
    Symbol("mu_k"),
    Symbol("Nf"),
    pathway,
    sigma=Symbol("sigma"),
  )
  let friction_force_oracle = mechanics_summary(
    "N=ReferenceFrame('APN'); pA=Point('Ap1'); pB=Point('Ap2'); q=dynamicsymbols('q'); mu_k,Nf,sigma=symbols('mu_k Nf sigma'); pB.set_pos(pA, q*N.x); CoulombKineticFriction(mu_k, Nf, LinearPathway(pA, pB), sigma=sigma).force",
  )
  assert_true(
    mechanics_expr_equal(
      @symprint.pretty_string(friction.force()),
      friction_force_oracle,
    ),
  )

  let target = @symvector.reference_frame("TA")
  let reaction = @symvector.reference_frame("RA")
  let torque = torque_actuator(
    Symbol("T"),
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
