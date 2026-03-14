///|
/// Inertia dyadic constructors aligned with `sympy.physics.mechanics.inertia`.

///|
pub fn inertia(
  frame : @symvector.ReferenceFrame,
  ixx : @symcore.Expr,
  iyy : @symcore.Expr,
  izz : @symcore.Expr,
  ixy? : @symcore.Expr = @symcore.int(0),
  iyz? : @symcore.Expr = @symcore.int(0),
  izx? : @symcore.Expr = @symcore.int(0),
) -> @symvector.Dyadic {
  (try! @symvector.outer(frame.x(), frame.x())).scale(ixx) +
  (try! @symvector.outer(frame.x(), frame.y())).scale(ixy) +
  (try! @symvector.outer(frame.x(), frame.z())).scale(izx) +
  (try! @symvector.outer(frame.y(), frame.x())).scale(ixy) +
  (try! @symvector.outer(frame.y(), frame.y())).scale(iyy) +
  (try! @symvector.outer(frame.y(), frame.z())).scale(iyz) +
  (try! @symvector.outer(frame.z(), frame.x())).scale(izx) +
  (try! @symvector.outer(frame.z(), frame.y())).scale(iyz) +
  (try! @symvector.outer(frame.z(), frame.z())).scale(izz)
}

///|
pub fn inertia_of_point_mass(
  mass : @symcore.Expr,
  pos_vec : @symvector.Vector,
  frame : @symvector.ReferenceFrame,
) -> @symvector.Dyadic raise @symvector.VectorError {
  let eye = frame.u()
  eye.scale(try! (pos_vec.dot(pos_vec) * mass)) -
  (try! pos_vec.outer(pos_vec)).scale(mass)
}
