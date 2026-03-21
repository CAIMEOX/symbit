///|
/// Inertia dyadic constructors aligned with `sympy.physics.mechanics.inertia`.

///|
pub fn inertia(
  frame : @symvector.ReferenceFrame,
  ixx : Expr,
  iyy : Expr,
  izz : Expr,
  ixy? : Expr = int(0),
  iyz? : Expr = int(0),
  izx? : Expr = int(0),
) -> @symvector.Dyadic raise @symvector.VectorError {
  @symvector.outer(frame.x(), frame.x()).scale(ixx) +
  @symvector.outer(frame.x(), frame.y()).scale(ixy) +
  @symvector.outer(frame.x(), frame.z()).scale(izx) +
  @symvector.outer(frame.y(), frame.x()).scale(ixy) +
  @symvector.outer(frame.y(), frame.y()).scale(iyy) +
  @symvector.outer(frame.y(), frame.z()).scale(iyz) +
  @symvector.outer(frame.z(), frame.x()).scale(izx) +
  @symvector.outer(frame.z(), frame.y()).scale(iyz) +
  @symvector.outer(frame.z(), frame.z()).scale(izz)
}

///|
pub fn inertia_of_point_mass(
  mass : Expr,
  pos_vec : @symvector.Vector,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Dyadic raise @symvector.VectorError {
  let eye = frame.u()
  eye.scale(pos_vec.dot(pos_vec) * mass) - pos_vec.outer(pos_vec).scale(mass)
}
