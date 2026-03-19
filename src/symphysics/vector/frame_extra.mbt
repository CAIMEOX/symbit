///|
/// Extra `ReferenceFrame` helpers aligned with SymPy vector kinematics.

///|
pub fn ReferenceFrame::partial_velocity(
  self : ReferenceFrame,
  other : ReferenceFrame,
  speeds : Array[Expr],
) -> Array[Vector] raise VectorError {
  let omega = self.ang_vel_in(other)
  let out : Array[Vector] = []
  for speed in speeds {
    out.push(omega.diff(speed, self, var_in_dcm=false))
  }
  out
}

///|
pub fn ReferenceFrame::orient_dcm(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  matrix : @symphysics.ExplicitMatrix,
) -> Unit raise VectorError {
  self.orient(parent, OrientationSpec::DcmSpec(matrix))
}

///|
pub fn ReferenceFrame::orient_explicit(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  matrix : @symphysics.ExplicitMatrix,
) -> Unit raise VectorError {
  self.orient_dcm(parent, matrix)
}

///|
pub fn ReferenceFrame::orient_body_fixed(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  angles : Array[Expr],
  order : String,
) -> Unit raise VectorError {
  self.orient(parent, OrientationSpec::BodySpec(angles, order))
}

///|
pub fn ReferenceFrame::orient_space_fixed(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  angles : Array[Expr],
  order : String,
) -> Unit raise VectorError {
  self.orient(parent, OrientationSpec::SpaceSpec(angles, order))
}

///|
pub fn ReferenceFrame::orient_quaternion(
  self : ReferenceFrame,
  parent : ReferenceFrame,
  quat : (Expr, Expr, Expr, Expr),
) -> Unit raise VectorError {
  self.orient(
    parent,
    OrientationSpec::QuaternionSpec(quat.0, quat.1, quat.2, quat.3),
  )
}

///|
pub fn ReferenceFrame::item(
  self : ReferenceFrame,
  axis : Int,
) -> CoordinateSym raise VectorError {
  self.coord(axis)
}

///|
pub fn ReferenceFrame::iter_basis(self : ReferenceFrame) -> Array[Vector] {
  [self.x(), self.y(), self.z()]
}
