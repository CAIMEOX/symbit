///|
/// Force and torque actuator helpers aligned with the high-value surface of
/// `sympy.physics.mechanics.actuator`.

///|
pub struct ForceActuator {
  force_ : Expr
  pathway_ : PathwayLike
} derive(Eq)

///|
pub struct LinearSpring {
  stiffness_ : Expr
  pathway_ : PathwayLike
  equilibrium_length_ : Expr
} derive(Eq)

///|
pub struct LinearDamper {
  damping_ : Expr
  pathway_ : PathwayLike
} derive(Eq)

///|
pub struct DuffingSpring {
  linear_stiffness_ : Expr
  nonlinear_stiffness_ : Expr
  pathway_ : PathwayLike
  equilibrium_length_ : Expr
} derive(Eq)

///|
pub struct CoulombKineticFriction {
  mu_k_ : Expr
  mu_s_ : Expr
  f_n_ : Expr
  pathway_ : PathwayLike
  v_s_ : Expr
  sigma_ : Expr
} derive(Eq)

///|
pub struct TorqueActuator {
  torque_ : Expr
  axis_ : @symvector.Vector
  target_frame_ : @symvector.ReferenceFrame
  reaction_frame_ : @symvector.ReferenceFrame?
} derive(Eq)

///|
pub enum ActuatorLike {
  Force(ForceActuator)
  Spring(LinearSpring)
  Damper(LinearDamper)
  Duffing(DuffingSpring)
  Friction(CoulombKineticFriction)
  Torque(TorqueActuator)
} derive(Eq)

///|
pub fn force_actuator(
  force_value : Expr,
  pathway : PathwayLike,
) -> ForceActuator {
  ForceActuator::{ force_: force_value, pathway_: pathway }
}

///|
pub fn ForceActuator::force(self : ForceActuator) -> Expr {
  self.force_
}

///|
pub fn ForceActuator::pathway(self : ForceActuator) -> PathwayLike {
  self.pathway_
}

///|
pub fn ForceActuator::to_loads(self : ForceActuator) -> Array[Load] raise {
  self.pathway_.to_loads(self.force_).map(fn(load) { Load::ForceLoad(load) })
}

///|
pub fn ForceActuator::repr(self : ForceActuator) -> String {
  "ForceActuator(" +
  @symprint.to_string(self.force_) +
  ", " +
  self.pathway_.repr() +
  ")"
}

///|
pub fn ForceActuator::as_actuator(self : ForceActuator) -> ActuatorLike {
  ActuatorLike::Force(self)
}

///|
pub fn linear_spring(
  stiffness : Expr,
  pathway : PathwayLike,
  equilibrium_length? : Expr = int(0),
) -> LinearSpring {
  LinearSpring::{
    stiffness_: stiffness,
    pathway_: pathway,
    equilibrium_length_: equilibrium_length,
  }
}

///|
pub fn LinearSpring::stiffness(self : LinearSpring) -> Expr {
  self.stiffness_
}

///|
pub fn LinearSpring::pathway(self : LinearSpring) -> PathwayLike {
  self.pathway_
}

///|
pub fn LinearSpring::equilibrium_length(self : LinearSpring) -> Expr {
  self.equilibrium_length_
}

///|
pub fn LinearSpring::force(self : LinearSpring) -> Expr raise {
  mech_simplify_expr(
    int(-1) *
    self.stiffness_ *
    (self.pathway_.length() - self.equilibrium_length_),
  )
}

///|
pub fn LinearSpring::to_loads(self : LinearSpring) -> Array[Load] raise {
  self.pathway_.to_loads(self.force()).map(fn(load) { Load::ForceLoad(load) })
}

///|
pub fn LinearSpring::repr(self : LinearSpring) -> String {
  let base = "LinearSpring(" +
    @symprint.to_string(self.stiffness_) +
    ", " +
    self.pathway_.repr()
  if @symcore.compare_expr(self.equilibrium_length_, int(0)) == 0 {
    base + ")"
  } else {
    base +
    ", equilibrium_length=" +
    @symprint.to_string(self.equilibrium_length_) +
    ")"
  }
}

///|
pub fn LinearSpring::as_actuator(self : LinearSpring) -> ActuatorLike {
  ActuatorLike::Spring(self)
}

///|
pub fn linear_damper(damping : Expr, pathway : PathwayLike) -> LinearDamper {
  LinearDamper::{ damping_: damping, pathway_: pathway }
}

///|
pub fn LinearDamper::damping(self : LinearDamper) -> Expr {
  self.damping_
}

///|
pub fn LinearDamper::pathway(self : LinearDamper) -> PathwayLike {
  self.pathway_
}

///|
pub fn LinearDamper::force(self : LinearDamper) -> Expr raise {
  mech_simplify_expr(
    int(-1) * self.damping_ * self.pathway_.extension_velocity(),
  )
}

///|
pub fn LinearDamper::to_loads(self : LinearDamper) -> Array[Load] raise {
  self.pathway_.to_loads(self.force()).map(fn(load) { Load::ForceLoad(load) })
}

///|
pub fn LinearDamper::repr(self : LinearDamper) -> String {
  "LinearDamper(" +
  @symprint.to_string(self.damping_) +
  ", " +
  self.pathway_.repr() +
  ")"
}

///|
pub fn LinearDamper::as_actuator(self : LinearDamper) -> ActuatorLike {
  ActuatorLike::Damper(self)
}

///|
pub fn duffing_spring(
  linear_stiffness : Expr,
  nonlinear_stiffness : Expr,
  pathway : PathwayLike,
  equilibrium_length? : Expr = int(0),
) -> DuffingSpring {
  DuffingSpring::{
    linear_stiffness_: linear_stiffness,
    nonlinear_stiffness_: nonlinear_stiffness,
    pathway_: pathway,
    equilibrium_length_: equilibrium_length,
  }
}

///|
pub fn DuffingSpring::force(self : DuffingSpring) -> Expr raise {
  let displacement = mech_simplify_expr(
    self.pathway_.length() - self.equilibrium_length_,
  )
  mech_simplify_expr(
    int(-1) * self.linear_stiffness_ * displacement -
    self.nonlinear_stiffness_ * (displacement ^ int(3)),
  )
}

///|
pub fn DuffingSpring::to_loads(self : DuffingSpring) -> Array[Load] raise {
  self.pathway_.to_loads(self.force()).map(fn(load) { Load::ForceLoad(load) })
}

///|
pub fn DuffingSpring::repr(self : DuffingSpring) -> String {
  "DuffingSpring(" +
  @symprint.to_string(self.linear_stiffness_) +
  ", " +
  @symprint.to_string(self.nonlinear_stiffness_) +
  ", " +
  self.pathway_.repr() +
  ", equilibrium_length=" +
  @symprint.to_string(self.equilibrium_length_) +
  ")"
}

///|
pub fn DuffingSpring::as_actuator(self : DuffingSpring) -> ActuatorLike {
  ActuatorLike::Duffing(self)
}

///|
pub fn coulomb_kinetic_friction(
  mu_k : Expr,
  f_n : Expr,
  pathway : PathwayLike,
  v_s? : Expr = int(100) ^ int(-1),
  sigma? : Expr = int(0),
  mu_s? : Expr = mu_k,
) -> CoulombKineticFriction {
  CoulombKineticFriction::{
    mu_k_: mu_k,
    mu_s_: mu_s,
    f_n_: f_n,
    pathway_: pathway,
    v_s_: v_s,
    sigma_: sigma,
  }
}

///|
pub fn CoulombKineticFriction::force(
  self : CoulombKineticFriction,
) -> Expr raise {
  let v = self.pathway_.extension_velocity()
  let f_c = self.mu_k_ * self.f_n_
  let f_max = self.mu_s_ * self.f_n_
  let stribeck = mech_simplify_expr(
    (f_max - f_c) *
    @symelem.exp(
      mech_simplify_expr(int(-1) * ((v * (self.v_s_ ^ int(-1))) ^ int(2))),
    ),
  )
  let viscous = self.sigma_ * v
  mech_simplify_expr(int(-1) * (f_c + stribeck) * @symelem.sign(v) - viscous)
}

///|
pub fn CoulombKineticFriction::to_loads(
  self : CoulombKineticFriction,
) -> Array[Load] raise {
  self.pathway_.to_loads(self.force()).map(fn(load) { Load::ForceLoad(load) })
}

///|
pub fn CoulombKineticFriction::repr(self : CoulombKineticFriction) -> String {
  "CoulombKineticFriction(" +
  @symprint.to_string(self.mu_k_) +
  ", " +
  @symprint.to_string(self.mu_s_) +
  ", " +
  @symprint.to_string(self.f_n_) +
  ", " +
  self.pathway_.repr() +
  ", " +
  @symprint.to_string(self.v_s_) +
  ", " +
  @symprint.to_string(self.sigma_) +
  ")"
}

///|
pub fn CoulombKineticFriction::as_actuator(
  self : CoulombKineticFriction,
) -> ActuatorLike {
  ActuatorLike::Friction(self)
}

///|
pub fn torque_actuator(
  torque_value : Expr,
  axis : @symvector.Vector,
  target_frame : @symvector.ReferenceFrame,
  reaction_frame? : @symvector.ReferenceFrame? = None,
) -> TorqueActuator raise @symvector.VectorError {
  TorqueActuator::{
    torque_: torque_value,
    axis_: axis.normalize(),
    target_frame_: target_frame,
    reaction_frame_: reaction_frame,
  }
}

///|
pub fn TorqueActuator::torque(self : TorqueActuator) -> Expr {
  self.torque_
}

///|
pub fn TorqueActuator::axis(self : TorqueActuator) -> @symvector.Vector {
  self.axis_
}

///|
pub fn TorqueActuator::target_frame(
  self : TorqueActuator,
) -> @symvector.ReferenceFrame {
  self.target_frame_
}

///|
pub fn TorqueActuator::reaction_frame(
  self : TorqueActuator,
) -> @symvector.ReferenceFrame? {
  self.reaction_frame_
}

///|
pub fn TorqueActuator::to_loads(self : TorqueActuator) -> Array[Load] {
  let loads = [
    Load::TorqueLoad(torque(self.target_frame_, self.axis_.scale(self.torque_))),
  ]
  match self.reaction_frame_ {
    Some(frame) => {
      loads.push(
        Load::TorqueLoad(torque(frame, self.axis_.scale(self.torque_).neg())),
      )
      loads
    }
    None => loads
  }
}

///|
pub fn TorqueActuator::repr(self : TorqueActuator) -> String {
  let base = "TorqueActuator(" +
    @symprint.to_string(self.torque_) +
    ", axis=" +
    @symvector.vsprint(self.axis_) +
    ", target_frame=" +
    self.target_frame_.name()
  match self.reaction_frame_ {
    Some(frame) => base + ", reaction_frame=" + frame.name() + ")"
    None => base + ")"
  }
}

///|
pub fn TorqueActuator::as_actuator(self : TorqueActuator) -> ActuatorLike {
  ActuatorLike::Torque(self)
}

///|
pub fn ActuatorLike::to_loads(self : ActuatorLike) -> Array[Load] raise {
  match self {
    ActuatorLike::Force(value) => value.to_loads()
    ActuatorLike::Spring(value) => value.to_loads()
    ActuatorLike::Damper(value) => value.to_loads()
    ActuatorLike::Duffing(value) => value.to_loads()
    ActuatorLike::Friction(value) => value.to_loads()
    ActuatorLike::Torque(value) => value.to_loads()
  }
}

///|
pub fn ActuatorLike::repr(self : ActuatorLike) -> String {
  match self {
    ActuatorLike::Force(value) => value.repr()
    ActuatorLike::Spring(value) => value.repr()
    ActuatorLike::Damper(value) => value.repr()
    ActuatorLike::Duffing(value) => value.repr()
    ActuatorLike::Friction(value) => value.repr()
    ActuatorLike::Torque(value) => value.repr()
  }
}
