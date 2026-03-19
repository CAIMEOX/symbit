///|
fn models_compact(text : String) -> String {
  text.replace(old=" ", new="")
}

///|
test "physics.mechanics parity model coordinates and speeds" {
  let chain = multi_mass_spring_damper(
    n=2,
    apply_gravity=true,
    apply_external_forces=true,
  )
  let chain_q = "[" + chain.q_ind().map(@symprint.to_string).join(", ") + "]"
  let chain_u = "[" + chain.u_ind().map(@symprint.to_string).join(", ") + "]"
  let chain_summary = "[" + chain_q + ", " + chain_u + "]"
  let chain_oracle = @sympy_physics.mechanics_summary(
    "from sympy.physics.mechanics.models import multi_mass_spring_damper; km = multi_mass_spring_damper(2, apply_gravity=True, apply_external_forces=True); [[str(x) for x in km.q], [str(x) for x in km.u]]",
  )
  assert_eq(models_compact(chain_summary), models_compact(chain_oracle))

  let pendulum = n_link_pendulum_on_cart(
    n=2,
    cart_force=true,
    joint_torques=true,
  )
  let pendulum_q = "[" +
    pendulum.q_ind().map(@symprint.to_string).join(", ") +
    "]"
  let pendulum_u = "[" +
    pendulum.u_ind().map(@symprint.to_string).join(", ") +
    "]"
  let pendulum_summary = "[" + pendulum_q + ", " + pendulum_u + "]"
  let pendulum_oracle = @sympy_physics.mechanics_summary(
    "from sympy.physics.mechanics.models import n_link_pendulum_on_cart; km = n_link_pendulum_on_cart(2, cart_force=True, joint_torques=True); [[str(x) for x in km.q], [str(x) for x in km.u]]",
  )
  assert_eq(models_compact(pendulum_summary), models_compact(pendulum_oracle))
}
