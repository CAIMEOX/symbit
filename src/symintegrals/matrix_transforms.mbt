///|
/// Matrix-valued transform front doors.
///
/// Current Limits:
/// - The public API applies scalar transform rules entry by entry.
/// - It does not expose matrix-specific transform theory beyond this lifting step.

///|
/// Apply the Laplace transform elementwise to a matrix.
///
/// - Does: Builds and evaluates the Laplace transform of each matrix entry independently.
/// - Input: One `Matrix`, a time variable `t`, and a transform variable `s`.
/// - Returns: One transformed `Matrix`.
/// - Limits: Raises `MatrixError` if applying the transform across the matrix fails.
pub fn laplace_transform_matrix(
  mat : @symmatrices.Matrix,
  t : Expr,
  s : Expr,
) -> @symmatrices.Matrix raise @symmatrices.MatrixError {
  mat.applyfunc(fn(cell) { doit(laplace_transform(cell, t, s)) })
}

///|
/// Evaluate a matrix-valued Laplace transform with metadata.
///
/// - Does: Transforms each matrix entry and aggregates the shared convergence plane and condition.
/// - Input: One `Matrix`, a time variable `t`, and a transform variable `s`.
/// - Returns: A triple `(matrix, plane, condition)`.
/// - Limits: Raises `MatrixError` if applying the transform across the matrix fails.
pub fn laplace_transform_matrix_result(
  mat : @symmatrices.Matrix,
  t : Expr,
  s : Expr,
) -> (@symmatrices.Matrix, Expr, Expr) raise @symmatrices.MatrixError {
  let mut plane = @symcore.Expr::NumberSymbol(NegativeInfinity)
  let mut cond = true_expr()
  let values = mat.applyfunc(fn(cell) {
    match laplace_transform_result(cell, t, s) {
      expr =>
        match @symcore.tuple_items(expr) {
          Some([value, roc, term_cond]) => {
            plane = max_expr(plane, roc)
            cond = and_expr(cond, term_cond)
            value
          }
          _ => expr
        }
    }
  })
  (values, plane, cond)
}

///|
/// Apply the inverse Laplace transform elementwise to a matrix.
///
/// - Does: Builds and evaluates the inverse Laplace transform of each matrix entry independently.
/// - Input: One `Matrix`, a transform variable `s`, and a time variable `t`.
/// - Returns: One transformed `Matrix`.
/// - Limits: Raises `MatrixError` if applying the transform across the matrix fails.
pub fn inverse_laplace_transform_matrix(
  mat : @symmatrices.Matrix,
  s : Expr,
  t : Expr,
) -> @symmatrices.Matrix raise @symmatrices.MatrixError {
  mat.applyfunc(fn(cell) { doit(inverse_laplace_transform(cell, s, t)) })
}
