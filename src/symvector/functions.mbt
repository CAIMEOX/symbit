///|
pub fn dot(
  lhs : Vector,
  rhs : Vector,
) -> @symcore.Expr raise @rawvec.VectorError {
  lhs.dot(rhs)
}

///|
pub fn cross(lhs : Vector, rhs : Vector) -> Vector raise @rawvec.VectorError {
  lhs.cross(rhs)
}

///|
pub fn express(
  expr : Vector,
  system : CoordSys3D,
  variables? : Bool = false,
) -> Vector raise @rawvec.VectorError {
  expr.express(system, variables~)
}

///|
pub fn express_scalar(
  expr : @symcore.Expr,
  system : CoordSys3D,
  variables? : Bool = false,
) -> @symcore.Expr {
  @rawvec.express_scalar(expr, system.frame_, variables~)
}

///|
pub fn matrix_to_vector(
  matrix : @symphysics.ExplicitMatrix,
  system : CoordSys3D,
) -> Vector raise @rawvec.VectorError {
  let rows = matrix.rows_copy()
  if rows.length() != 3 ||
    rows[0].length() != 1 ||
    rows[1].length() != 1 ||
    rows[2].length() != 1 {
    abort("matrix must be 3x1")
  }
  vector_from_terms([
    (rows[0][0], system.i()),
    (rows[1][0], system.j()),
    (rows[2][0], system.k()),
  ])
}
