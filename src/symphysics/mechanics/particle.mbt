///|
/// Particle model aligned with the non-deprecated `sympy.physics.mechanics.Particle`.

///|
pub fn particle(
  name : String,
  point? : @symvector.Point? = None,
  mass? : Expr? = None,
) -> Particle raise @symvector.VectorError {
  let p = point.unwrap_or(@symvector.point(name + "_masscenter"))
  let m = mass.unwrap_or(symbol(name + "_mass"))
  Particle::{
    name_: name,
    point_: p,
    mass_: m,
    potential_energy_: mech_zero_expr(),
  }
}

///|
pub fn Particle::name(self : Particle) -> String {
  self.name_
}

///|
pub fn Particle::point(self : Particle) -> @symvector.Point {
  self.point_
}

///|
pub fn Particle::set_point(self : Particle, value : @symvector.Point) -> Unit {
  self.point_ = value
}

///|
pub fn Particle::mass(self : Particle) -> Expr {
  self.mass_
}

///|
pub fn Particle::set_mass(self : Particle, value : Expr) -> Unit {
  self.mass_ = value
}

///|
pub fn Particle::potential_energy(self : Particle) -> Expr {
  self.potential_energy_
}

///|
pub fn Particle::set_potential_energy(self : Particle, value : Expr) -> Unit {
  self.potential_energy_ = value
}

///|
pub fn Particle::repr(self : Particle) -> String {
  "Particle('" +
  self.name_ +
  "', masscenter=" +
  self.point_.name() +
  ", mass=" +
  @symprint.to_string(self.mass_) +
  ")"
}

///|
pub fn Particle::linear_momentum(
  self : Particle,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  self.point_.vel(frame).scale(self.mass_)
}

///|
pub fn Particle::angular_momentum(
  self : Particle,
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Vector raise @symvector.VectorError {
  let r = self.point_.pos_from(point)
  let p = self.linear_momentum(frame)
  r.cross(p)
}

///|
pub fn Particle::kinetic_energy(
  self : Particle,
  frame : @symvector.ReferenceFrame,
) -> Expr raise @symvector.VectorError {
  let v = self.point_.vel(frame)
  mech_half_expr() * self.mass_ * v.dot(v)
}

///|
pub fn Particle::parallel_axis(
  self : Particle,
  point : @symvector.Point,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Dyadic raise @symvector.VectorError {
  inertia_of_point_mass(self.mass_, self.point_.pos_from(point), frame)
}
