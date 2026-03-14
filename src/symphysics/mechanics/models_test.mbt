///|
test "physics.mechanics models core" {
  let chain = try! multi_mass_spring_damper(
    n=2,
    apply_gravity=true,
    apply_external_forces=true,
  )
  guard chain.q_ind().length() == 2 else {
    fail("spring-damper model q length")
  }
  guard chain.u_ind().length() == 2 else {
    fail("spring-damper model u length")
  }
  guard chain.joints().length() == 2 else { fail("spring-damper model joints") }
  guard chain.actuators().length() == 4 else {
    fail("spring-damper model actuators")
  }
  guard chain.loads().length() == 5 else {
    fail("spring-damper model explicit loads")
  }

  let pendulum = try! n_link_pendulum_on_cart(
    n=2,
    cart_force=true,
    joint_torques=true,
  )
  guard pendulum.q_ind().length() == 3 else { fail("pendulum model q length") }
  guard pendulum.u_ind().length() == 3 else { fail("pendulum model u length") }
  guard pendulum.joints().length() == 3 else { fail("pendulum model joints") }
  guard pendulum.bodies().length() == 4 else { fail("pendulum model bodies") }
  guard pendulum.loads().length() == 9 else { fail("pendulum model loads") }
}
