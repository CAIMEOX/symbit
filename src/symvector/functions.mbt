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
pub fn outer(lhs : Vector, rhs : Vector) -> Dyadic raise @rawvec.VectorError {
  lhs.outer(rhs)
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
pub fn express_dyadic(
  expr : Dyadic,
  system : CoordSys3D,
  system2? : CoordSys3D? = None,
  variables? : Bool = false,
) -> Dyadic raise @rawvec.VectorError {
  expr.express(system, system2~, variables~)
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

///|
pub fn matrix_to_dyadic(
  matrix : @symphysics.ExplicitMatrix,
  system : CoordSys3D,
) -> Dyadic {
  let rows = matrix.rows_copy()
  if rows.length() != 3 ||
    rows[0].length() != 3 ||
    rows[1].length() != 3 ||
    rows[2].length() != 3 {
    abort("matrix must be 3x3")
  }
  let mut out = dyadic_zero()
  let basis = system.base_vectors()
  for i in 0..<3 {
    for j in 0..<3 {
      let coeff = rows[i][j]
      if !@symcore.is_zero(coeff) {
        out = out +
          (basis[i].outer(basis[j]) catch { _ => abort("matrix_to_dyadic") }).scale(
            coeff,
          )
      }
    }
  }
  out
}
