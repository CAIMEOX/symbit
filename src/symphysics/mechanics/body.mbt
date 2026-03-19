///|
/// Legacy `Body` convenience wrapper aligned with the still-used surface in
/// `sympy.physics.mechanics.body`.

///|
pub fn body(
  name : String,
  masscenter? : @symvector.Point? = None,
  mass? : Expr? = None,
  frame? : @symvector.ReferenceFrame? = None,
  central_inertia? : @symvector.Dyadic? = None,
) -> Body raise @symvector.VectorError {
  let fr = frame.unwrap_or(try! @symvector.reference_frame(name + "_frame"))
  let mc = masscenter.unwrap_or(try! @symvector.point(name + "_masscenter"))
  let m = mass.unwrap_or(symbol(name + "_mass"))
  mc.set_vel(fr, @symvector.vector_zero())
  let default_inertia = Inertia::from_inertia_scalars(
    mc,
    fr,
    symbol(name + "_ixx"),
    symbol(name + "_iyy"),
    symbol(name + "_izz"),
    ixy=symbol(name + "_ixy"),
    iyz=symbol(name + "_iyz"),
    izx=symbol(name + "_izx"),
  )
  let is_rb = match central_inertia {
    Some(_) => true
    None => mass is None
  }
  let central = match central_inertia {
    Some(value) => value
    None =>
      if is_rb {
        default_inertia.dyadic
      } else {
        @symvector.dyadic_zero()
      }
  }
  let inertia_value = if is_rb {
    inertia_tuple(central, mc)
  } else {
    inertia_tuple(@symvector.dyadic_zero(), mc)
  }
  Body::{
    name_: name,
    masscenter_: mc,
    frame_: fr,
    mass_: m,
    inertia_: inertia_value,
    central_inertia_: central,
    potential_energy_: mech_zero_expr(),
    loads_: [],
    is_rigidbody_: is_rb,
  }
}

///|
pub fn Body::name(self : Body) -> String {
  self.name_
}

///|
pub fn Body::masscenter(self : Body) -> @symvector.Point {
  self.masscenter_
}

///|
pub fn Body::mass(self : Body) -> Expr {
  self.mass_
}

///|
pub fn Body::frame(self : Body) -> @symvector.ReferenceFrame {
  self.frame_
}

///|
pub fn Body::potential_energy(self : Body) -> Expr {
  self.potential_energy_
}

///|
pub fn Body::set_potential_energy(self : Body, value : Expr) -> Unit {
  self.potential_energy_ = value
}

///|
pub fn Body::loads(self : Body) -> Array[Load] {
  self.loads_.copy()
}

///|
pub fn Body::is_rigidbody(self : Body) -> Bool {
  self.is_rigidbody_
}

///|
pub fn Body::x(self : Body) -> @symvector.Vector {
  self.frame_.x()
}

///|
pub fn Body::y(self : Body) -> @symvector.Vector {
  self.frame_.y()
}

///|
pub fn Body::z(self : Body) -> @symvector.Vector {
  self.frame_.z()
}

///|
pub fn Body::inertia(self : Body) -> Inertia {
  self.inertia_
}

///|
pub fn Body::central_inertia(self : Body) -> @symvector.Dyadic {
  self.central_inertia_
}

///|
pub fn Body::set_central_inertia(
  self : Body,
  value : @symvector.Dyadic,
) -> Unit {
  self.central_inertia_ = value
  self.inertia_ = inertia_tuple(value, self.masscenter_)
  self.is_rigidbody_ = true
}

///|
pub fn Body::set_inertia(self : Body, value : Inertia) -> Unit {
  self.inertia_ = value
  self.central_inertia_ = try! rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    value,
  )
  self.is_rigidbody_ = true
}

///|
pub fn Body::repr(self : Body) -> String {
  if self.is_rigidbody_ {
    "RigidBody('" +
    self.name_ +
    "', masscenter=" +
    self.masscenter_.name() +
    ", frame=" +
    self.frame_.name() +
    ", mass=" +
    @symprint.to_string(self.mass_) +
    ", inertia=" +
    self.inertia_.repr() +
    ")"
  } else {
    "Particle('" +
    self.name_ +
    "', masscenter=" +
    self.masscenter_.name() +
    ", mass=" +
    @symprint.to_string(self.mass_) +
    ")"
  }
}

///|
pub fn Body::linear_momentum(
  self : Body,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  if self.is_rigidbody_ {
    self.masscenter_.vel(frame).scale(self.mass_)
  } else {
    self.masscenter_.vel(frame).scale(self.mass_)
  }
}

///|
pub fn Body::angular_momentum(
  self : Body,
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  if self.is_rigidbody_ {
    let spin = try! self.central_inertia_.dot_vector(
      self.frame_.ang_vel_in(frame),
    )
    let r = self.masscenter_.pos_from(point)
    let p = try! self.linear_momentum(frame)
    spin + (try! r.cross(p))
  } else {
    let r = self.masscenter_.pos_from(point)
    let p = try! self.linear_momentum(frame)
    r.cross(p)
  }
}

///|
pub fn Body::kinetic_energy(
  self : Body,
  frame : @symvector.ReferenceFrame,
) -> Expr raise @symvector.VectorError {
  if self.is_rigidbody_ {
    let omega = self.frame_.ang_vel_in(frame)
    mech_simplify_expr(
      mech_half_expr() *
      self.mass_ *
      (try! self.masscenter_.vel(frame).dot(self.masscenter_.vel(frame))) +
      mech_half_expr() *
      (try! omega.dot(try! self.central_inertia_.dot_vector(omega))),
    )
  } else {
    mech_half_expr() *
    self.mass_ *
    (try! self.masscenter_.vel(frame).dot(self.masscenter_.vel(frame)))
  }
}

///|
pub fn Body::apply_force(
  self : Body,
  value : @symvector.Vector,
  point? : @symvector.Point? = None,
  reaction_body? : Body? = None,
  reaction_point? : @symvector.Point? = None,
) -> Unit {
  let at = point.unwrap_or(self.masscenter_)
  match reaction_body {
    Some(other) => other.apply_force(value.neg(), point=reaction_point)
    None => ()
  }
  let mut merged = false
  for i in 0..<self.loads_.length() {
    match self.loads_[i] {
      Load::ForceLoad(existing) if existing.point == at => {
        self.loads_[i] = Load::ForceLoad(force(at, existing.force + value))
        merged = true
      }
      _ => ()
    }
  }
  if !merged {
    self.loads_.push(Load::ForceLoad(force(at, value)))
  }
}

///|
pub fn Body::apply_torque(
  self : Body,
  value : @symvector.Vector,
  reaction_body? : Body? = None,
) -> Unit {
  match reaction_body {
    Some(other) => other.apply_torque(value.neg())
    None => ()
  }
  let mut merged = false
  for i in 0..<self.loads_.length() {
    match self.loads_[i] {
      Load::TorqueLoad(existing) if existing.frame == self.frame_ => {
        self.loads_[i] = Load::TorqueLoad(
          torque(self.frame_, existing.torque + value),
        )
        merged = true
      }
      _ => ()
    }
  }
  if !merged {
    self.loads_.push(Load::TorqueLoad(torque(self.frame_, value)))
  }
}

///|
pub fn Body::clear_loads(self : Body) -> Unit {
  self.loads_ = []
}

///|
pub fn Body::remove_load(
  self : Body,
  about? : @symvector.Point? = None,
) -> Unit {
  let kept : Array[Load] = []
  match about {
    Some(point) =>
      for load in self.loads_ {
        if !mech_load_at_point(load, point) {
          kept.push(load)
        }
      }
    None => {
      let mut removed = false
      for load in self.loads_ {
        if !removed && mech_load_at_frame(load, self.frame_) {
          removed = true
        } else {
          kept.push(load)
        }
      }
    }
  }
  self.loads_ = kept
}

///|
pub fn Body::masscenter_vel_in(
  self : Body,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  self.masscenter_.vel(frame)
}

///|
pub fn Body::ang_vel_in(
  self : Body,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  self.frame_.ang_vel_in(frame)
}

///|
pub fn Body::dcm(
  self : Body,
  frame : @symvector.ReferenceFrame,
) -> @symphysics.ExplicitMatrix raise @symvector.VectorError {
  self.frame_.dcm(frame)
}

///|
pub fn Body::parallel_axis(
  self : Body,
  point : @symvector.Point,
  frame? : @symvector.ReferenceFrame? = None,
) -> @symvector.Dyadic raise @symvector.VectorError {
  if self.is_rigidbody_ {
    let fr = frame.unwrap_or(self.frame_)
    self.central_inertia_ +
    inertia_of_point_mass(self.mass_, try! self.masscenter_.pos_from(point), fr)
  } else {
    inertia_of_point_mass(
      self.mass_,
      try! self.masscenter_.pos_from(point),
      frame.unwrap_or(self.frame_),
    )
  }
}
