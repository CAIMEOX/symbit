///|
/// Rigid body model aligned with the non-deprecated `sympy.physics.mechanics.RigidBody`.

///|
fn rigidbody_default_inertia(
  name : String,
  masscenter : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> Inertia raise @symvector.VectorError {
  Inertia::from_inertia_scalars(
    masscenter,
    frame,
    Symbol(name + "_ixx"),
    Symbol(name + "_iyy"),
    Symbol(name + "_izz"),
    ixy=Symbol(name + "_ixy"),
    iyz=Symbol(name + "_iyz"),
    izx=Symbol(name + "_izx"),
  )
}

///|
fn rigidbody_central_inertia(
  mass : Expr,
  masscenter : @symvector.Point,
  frame : @symvector.ReferenceFrame,
  value : Inertia,
) -> @symvector.Dyadic raise @symvector.VectorError {
  let shift = inertia_of_point_mass(
    mass,
    masscenter.pos_from(value.point),
    frame,
  )
  value.dyadic - shift
}

///|
pub fn rigid_body(
  name : String,
  masscenter? : @symvector.Point? = None,
  frame? : @symvector.ReferenceFrame? = None,
  mass? : Expr? = None,
  inertia? : Inertia? = None,
) -> RigidBody raise @symvector.VectorError {
  let mc = masscenter.unwrap_or(@symvector.point(name + "_masscenter"))
  let fr = frame.unwrap_or(@symvector.reference_frame(name + "_frame"))
  let m = mass.unwrap_or(Symbol(name + "_mass"))
  let inertia_value = inertia.unwrap_or(rigidbody_default_inertia(name, mc, fr))
  let central = rigidbody_central_inertia(m, mc, fr, inertia_value)
  {
    name_: name,
    masscenter_: mc,
    frame_: fr,
    mass_: m,
    inertia_: inertia_value,
    central_inertia_: central,
    potential_energy_: int(0),
  }
}

///|
pub fn RigidBody::name(self : RigidBody) -> String {
  self.name_
}

///|
pub fn RigidBody::masscenter(self : RigidBody) -> @symvector.Point {
  self.masscenter_
}

///|
pub fn RigidBody::set_masscenter(
  self : RigidBody,
  value : @symvector.Point,
) -> Unit raise @symvector.VectorError {
  self.masscenter_ = value
  self.central_inertia_ = rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    self.inertia_,
  )
}

///|
pub fn RigidBody::frame(self : RigidBody) -> @symvector.ReferenceFrame {
  self.frame_
}

///|
pub fn RigidBody::set_frame(
  self : RigidBody,
  value : @symvector.ReferenceFrame,
) -> Unit raise @symvector.VectorError {
  self.frame_ = value
  self.central_inertia_ = rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    self.inertia_,
  )
}

///|
pub fn RigidBody::mass(self : RigidBody) -> Expr {
  self.mass_
}

///|
pub fn RigidBody::set_mass(
  self : RigidBody,
  value : Expr,
) -> Unit raise @symvector.VectorError {
  self.mass_ = value
  self.central_inertia_ = rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    self.inertia_,
  )
}

///|
pub fn RigidBody::potential_energy(self : RigidBody) -> Expr {
  self.potential_energy_
}

///|
pub fn RigidBody::set_potential_energy(self : RigidBody, value : Expr) -> Unit {
  self.potential_energy_ = value
}

///|
pub fn RigidBody::inertia(self : RigidBody) -> Inertia {
  self.inertia_
}

///|
pub fn RigidBody::set_inertia(
  self : RigidBody,
  value : Inertia,
) -> Unit raise @symvector.VectorError {
  self.inertia_ = value
  self.central_inertia_ = rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    self.inertia_,
  )
}

///|
pub fn RigidBody::central_inertia(self : RigidBody) -> @symvector.Dyadic {
  self.central_inertia_
}

///|
pub fn RigidBody::set_central_inertia(
  self : RigidBody,
  value : @symvector.Dyadic,
) -> Unit {
  self.central_inertia_ = value
  self.inertia_ = inertia_tuple(value, self.masscenter_)
}

///|
pub fn RigidBody::x(self : RigidBody) -> @symvector.Vector {
  self.frame_.x()
}

///|
pub fn RigidBody::y(self : RigidBody) -> @symvector.Vector {
  self.frame_.y()
}

///|
pub fn RigidBody::z(self : RigidBody) -> @symvector.Vector {
  self.frame_.z()
}

///|
pub fn RigidBody::repr(self : RigidBody) -> String {
  "RigidBody('" +
  self.name_ +
  "', masscenter=" +
  self.masscenter_.name() +
  ", frame=" +
  self.frame_.name() +
  ", mass=" +
  @symprint.pretty_string(self.mass_) +
  ", inertia=" +
  self.inertia_.repr() +
  ")"
}

///|
pub fn RigidBody::linear_momentum(
  self : RigidBody,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  self.masscenter_.vel(frame).scale(self.mass_)
}

///|
pub fn RigidBody::angular_momentum(
  self : RigidBody,
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  let spin = self.central_inertia_.dot_vector(self.frame_.ang_vel_in(frame))
  let r = self.masscenter_.pos_from(point)
  let p = self.linear_momentum(frame)
  spin + r.cross(p)
}

///|
pub fn RigidBody::kinetic_energy(
  self : RigidBody,
  frame : @symvector.ReferenceFrame,
) -> Expr raise @symvector.VectorError {
  let omega = self.frame_.ang_vel_in(frame)
  let translational = mech_half_expr() *
    self.mass_ *
    self.masscenter_.vel(frame).dot(self.masscenter_.vel(frame))
  let rotational = mech_half_expr() *
    omega.dot(self.central_inertia_.dot_vector(omega))
  mech_simplify_expr(translational + rotational)
}

///|
pub fn RigidBody::parallel_axis(
  self : RigidBody,
  point : @symvector.Point,
  frame? : @symvector.ReferenceFrame? = None,
) -> @symvector.Dyadic raise @symvector.VectorError {
  let fr = frame.unwrap_or(self.frame_)
  self.central_inertia_ +
  inertia_of_point_mass(self.mass_, self.masscenter_.pos_from(point), fr)
}
