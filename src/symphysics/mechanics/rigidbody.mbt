///|
/// Rigid body model aligned with the non-deprecated `sympy.physics.mechanics.RigidBody`.

///|
fn rigidbody_default_inertia(
  name : String,
  masscenter : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> Inertia {
  Inertia::from_inertia_scalars(
    masscenter,
    frame,
    @symcore.symbol(name + "_ixx"),
    @symcore.symbol(name + "_iyy"),
    @symcore.symbol(name + "_izz"),
    ixy=@symcore.symbol(name + "_ixy"),
    iyz=@symcore.symbol(name + "_iyz"),
    izx=@symcore.symbol(name + "_izx"),
  )
}

///|
fn rigidbody_central_inertia(
  mass : @symcore.Expr,
  masscenter : @symvector.Point,
  frame : @symvector.ReferenceFrame,
  value : Inertia,
) -> @symvector.Dyadic raise @symvector.VectorError {
  let shift = inertia_of_point_mass(
    mass,
    try! masscenter.pos_from(value.point),
    frame,
  )
  value.dyadic - shift
}

///|
pub fn rigid_body(
  name : String,
  masscenter? : @symvector.Point? = None,
  frame? : @symvector.ReferenceFrame? = None,
  mass? : @symcore.Expr? = None,
  inertia? : Inertia? = None,
) -> RigidBody raise @symvector.VectorError {
  let mc = masscenter.unwrap_or(try! @symvector.point(name + "_masscenter"))
  let fr = frame.unwrap_or(try! @symvector.reference_frame(name + "_frame"))
  let m = mass.unwrap_or(@symcore.symbol(name + "_mass"))
  let inertia_value = inertia.unwrap_or(rigidbody_default_inertia(name, mc, fr))
  let central = rigidbody_central_inertia(m, mc, fr, inertia_value)
  RigidBody::{
    name_: name,
    masscenter_: mc,
    frame_: fr,
    mass_: m,
    inertia_: inertia_value,
    central_inertia_: central,
    potential_energy_: mech_zero_expr(),
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
) -> Unit {
  self.masscenter_ = value
  self.central_inertia_ = try! rigidbody_central_inertia(
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
) -> Unit {
  self.frame_ = value
  self.central_inertia_ = try! rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    self.inertia_,
  )
}

///|
pub fn RigidBody::mass(self : RigidBody) -> @symcore.Expr {
  self.mass_
}

///|
pub fn RigidBody::set_mass(self : RigidBody, value : @symcore.Expr) -> Unit {
  self.mass_ = value
  self.central_inertia_ = try! rigidbody_central_inertia(
    self.mass_,
    self.masscenter_,
    self.frame_,
    self.inertia_,
  )
}

///|
pub fn RigidBody::potential_energy(self : RigidBody) -> @symcore.Expr {
  self.potential_energy_
}

///|
pub fn RigidBody::set_potential_energy(
  self : RigidBody,
  value : @symcore.Expr,
) -> Unit {
  self.potential_energy_ = value
}

///|
pub fn RigidBody::inertia(self : RigidBody) -> Inertia {
  self.inertia_
}

///|
pub fn RigidBody::set_inertia(self : RigidBody, value : Inertia) -> Unit {
  self.inertia_ = value
  self.central_inertia_ = try! rigidbody_central_inertia(
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
  @symprint.to_string(self.mass_) +
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
  let spin = try! self.central_inertia_.dot_vector(
    self.frame_.ang_vel_in(frame),
  )
  let r = self.masscenter_.pos_from(point)
  let p = try! self.linear_momentum(frame)
  spin + (try! r.cross(p))
}

///|
pub fn RigidBody::kinetic_energy(
  self : RigidBody,
  frame : @symvector.ReferenceFrame,
) -> @symcore.Expr raise @symvector.VectorError {
  let omega = self.frame_.ang_vel_in(frame)
  let translational = mech_half_expr() *
    self.mass_ *
    (try! self.masscenter_.vel(frame).dot(self.masscenter_.vel(frame)))
  let rotational = mech_half_expr() *
    (try! omega.dot(try! self.central_inertia_.dot_vector(omega)))
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
  inertia_of_point_mass(self.mass_, try! self.masscenter_.pos_from(point), fr)
}
