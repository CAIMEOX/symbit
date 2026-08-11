///|
/// Load objects and gravity helpers aligned with `sympy.physics.mechanics.loads`.

///|
pub fn force_load(point : @symvector.Point, value : @symvector.Vector) -> Load {
  ForceLoad(force(point, value))
}

///|
pub fn torque_load(
  frame : @symvector.ReferenceFrame,
  value : @symvector.Vector,
) -> Load {
  TorqueLoad(torque(frame, value))
}

///|
pub fn force_on_body(body : BodyLike, value : @symvector.Vector) -> Force {
  force(mech_bodylike_masscenter(body), value)
}

///|
pub fn torque_on_body(body : Body, value : @symvector.Vector) -> Torque {
  torque(body.frame(), value)
}

///|
pub fn gravity(
  acceleration : @symvector.Vector,
  bodies : Array[BodyLike],
) -> Array[Force] {
  let out : Array[Force] = []
  for body in bodies {
    out.push(
      force(
        mech_bodylike_masscenter(body),
        acceleration.scale(mech_bodylike_mass(body)),
      ),
    )
  }
  out
}
