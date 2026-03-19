///|
/// High-value `JointsMethod` compatibility layer that assembles bodies,
/// generalized coordinates, speeds, and loads from a joint graph and delegates
/// equation formation to Kane/Lagrange style backends.

///|
pub enum MechanicsBackend {
  Kane(KanesMethod)
  Lagrange(LagrangesMethod)
} derive(Eq)

///|
pub struct JointsMethod {
  frame_ : @symvector.ReferenceFrame
  bodies_ : Array[BodyLike]
  mut loads_ : Array[Load]
  q_ : Array[Expr]
  u_ : Array[Expr]
  kdes_ : Array[Expr]
  mut backend_ : MechanicsBackend?
} derive(Eq)

///|
fn joints_collect_bodies(
  root : BodyLike,
  joints : Array[JointLike],
) -> Array[BodyLike] {
  let out : Array[BodyLike] = []
  for joint in joints {
    let child = joint.child()
    if !out.any(fn(item) { item.name() == child.name() }) {
      out.push(child)
    }
  }
  for joint in joints {
    let parent = joint.parent()
    if !out.any(fn(item) { item.name() == parent.name() }) {
      out.push(parent)
    }
  }
  if !out.any(fn(item) { item.name() == root.name() }) {
    out.push(root)
  }
  out
}

///|
fn joints_collect_loads(bodies : Array[BodyLike]) -> Array[Load] {
  let out : Array[Load] = []
  for body in bodies {
    match body {
      BodyLike::BodyLikeLegacy(value) =>
        system_append_loads_unique(out, value.loads())
      _ => ()
    }
  }
  out
}

///|
pub fn joints_method(
  root : BodyLike,
  joints : Array[JointLike],
) -> JointsMethod raise @symphysics.PhysicsError {
  let frame = match root.frame() {
    Some(value) => value
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "JointsMethod root body must provide a reference frame",
      )
  }
  let q : Array[Expr] = []
  let u : Array[Expr] = []
  let kdes : Array[Expr] = []
  for joint in joints {
    system_append_exprs_unique(q, joint.coordinates())
    system_append_exprs_unique(u, joint.speeds())
    system_append_exprs_unique(kdes, joint.kdes())
  }
  try! validate_coordinates(coordinates=q, speeds=u)
  let bodies = joints_collect_bodies(root, joints)
  JointsMethod::{
    frame_: frame,
    bodies_: bodies,
    loads_: joints_collect_loads(bodies),
    q_: q,
    u_: u,
    kdes_: kdes,
    backend_: None,
  }
}

///|
pub fn JointsMethod::frame(self : JointsMethod) -> @symvector.ReferenceFrame {
  self.frame_
}

///|
pub fn JointsMethod::bodies(self : JointsMethod) -> Array[BodyLike] {
  self.bodies_.copy()
}

///|
pub fn JointsMethod::loads(self : JointsMethod) -> Array[Load] {
  self.loads_.copy()
}

///|
pub fn JointsMethod::set_loads(
  self : JointsMethod,
  loads : Array[Load],
) -> Unit {
  self.loads_ = loads.copy()
}

///|
pub fn JointsMethod::add_loads(
  self : JointsMethod,
  loads : Array[Load],
) -> Unit {
  system_append_loads_unique(self.loads_, loads)
}

///|
pub fn JointsMethod::q(self : JointsMethod) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(self.q_)
}

///|
pub fn JointsMethod::u(self : JointsMethod) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(self.u_)
}

///|
pub fn JointsMethod::kdes(self : JointsMethod) -> @symphysics.ExplicitMatrix {
  mechanics_matrix_column(self.kdes_)
}

///|
pub fn JointsMethod::backend(self : JointsMethod) -> MechanicsBackend? {
  self.backend_
}

///|
pub fn JointsMethod::form_eoms(
  self : JointsMethod,
  use_lagrange? : Bool = false,
) -> @symphysics.ExplicitMatrix raise {
  if use_lagrange {
    let subs : Array[Substitution] = []
    for i in 0..<self.q_.length() {
      subs.push(
        (self.u_[i], @symcalculus.diff(self.q_[i], @symvector.dynamicsymbols_t)),
      )
    }
    let lagr = msubs_expr(try! lagrangian(self.frame_, self.bodies_), subs)
    let lagrange_loads : Array[Load] = []
    for load in self.loads_ {
      match load {
        Load::ForceLoad(value) =>
          lagrange_loads.push(
            Load::ForceLoad(force(value.point, msubs_vector(value.force, subs))),
          )
        Load::TorqueLoad(value) =>
          lagrange_loads.push(
            Load::TorqueLoad(
              torque(value.frame, msubs_vector(value.torque, subs)),
            ),
          )
      }
    }
    let backend = try! lagranges_method(
      lagr,
      self.q_,
      bodies=self.bodies_,
      forcelist=lagrange_loads,
      frame=Some(self.frame_),
    )
    let eom = try! backend.form_lagranges_equations()
    self.backend_ = Some(MechanicsBackend::Lagrange(backend))
    eom
  } else {
    let backend = try! kanes_method(
      self.frame_,
      self.q_,
      self.u_,
      self.kdes_,
      bodies=self.bodies_,
      forcelist=self.loads_,
    )
    let (_, fr) = try! backend.kanes_equations(self.bodies_, self.loads_)
    self.backend_ = Some(MechanicsBackend::Kane(backend))
    fr
  }
}

///|
pub fn JointsMethod::mass_matrix(
  self : JointsMethod,
) -> @symphysics.ExplicitMatrix {
  match self.backend_ {
    Some(MechanicsBackend::Kane(value)) => value.mass_matrix()
    Some(MechanicsBackend::Lagrange(value)) => value.mass_matrix()
    None => mechanics_zero_column(0)
  }
}

///|
pub fn JointsMethod::forcing(self : JointsMethod) -> @symphysics.ExplicitMatrix {
  match self.backend_ {
    Some(MechanicsBackend::Kane(value)) => value.forcing()
    Some(MechanicsBackend::Lagrange(value)) => value.forcing()
    None => mechanics_zero_column(0)
  }
}

///|
pub fn JointsMethod::mass_matrix_full(
  self : JointsMethod,
) -> @symphysics.ExplicitMatrix {
  match self.backend_ {
    Some(MechanicsBackend::Kane(value)) => value.mass_matrix_full()
    Some(MechanicsBackend::Lagrange(value)) => value.mass_matrix_full()
    None => mechanics_zero_column(0)
  }
}

///|
pub fn JointsMethod::forcing_full(
  self : JointsMethod,
) -> @symphysics.ExplicitMatrix {
  match self.backend_ {
    Some(MechanicsBackend::Kane(value)) => value.forcing_full()
    Some(MechanicsBackend::Lagrange(value)) => value.forcing_full()
    None => mechanics_zero_column(0)
  }
}

///|
pub fn JointsMethod::rhs(
  self : JointsMethod,
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  match self.backend_ {
    Some(MechanicsBackend::Kane(value)) => value.rhs()
    Some(MechanicsBackend::Lagrange(value)) => value.rhs()
    None =>
      raise @symphysics.PhysicsError::ValueError(
        "form_eoms must be called before rhs",
      )
  }
}
