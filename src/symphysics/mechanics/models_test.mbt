///|
test "physics.mechanics models core" {
  let chain = multi_mass_spring_damper(
    n=2,
    apply_gravity=true,
    apply_external_forces=true,
  )
  assert_eq(chain.q_ind().length(), 2)
  assert_eq(chain.u_ind().length(), 2)
  assert_eq(chain.joints().length(), 2)
  assert_eq(chain.actuators().length(), 4)
  assert_eq(chain.loads().length(), 5)

  let pendulum = n_link_pendulum_on_cart(
    n=2,
    cart_force=true,
    joint_torques=true,
  )
  assert_eq(pendulum.q_ind().length(), 3)
  assert_eq(pendulum.u_ind().length(), 3)
  assert_eq(pendulum.joints().length(), 3)
  assert_eq(pendulum.bodies().length(), 4)
  assert_eq(pendulum.loads().length(), 9)
}
