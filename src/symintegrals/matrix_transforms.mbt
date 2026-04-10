///|
/// Matrix-valued transform helpers.
///
/// These helpers apply scalar transform rules entry-by-entry and rebuild the
/// matrix result explicitly.

///|
/// Apply the Laplace transform elementwise to a matrix and immediately
/// evaluate each entry.
pub fn laplace_transform_matrix(
  mat : @symmatrices.Matrix,
  t : Expr,
  s : Expr,
) -> @symmatrices.Matrix raise @symmatrices.MatrixError {
  mat.applyfunc(fn(cell) { doit(laplace_transform(cell, t, s)) })
}

///|
/// Compute the matrix-valued Laplace transform together with a shared region of
/// convergence and condition.
///
/// The matrix entries are transformed independently and their individual ROC /
/// condition metadata are aggregated with `Max` / logical `And`.
pub fn laplace_transform_matrix_result(
  mat : @symmatrices.Matrix,
  t : Expr,
  s : Expr,
) -> (@symmatrices.Matrix, Expr, Expr) raise @symmatrices.MatrixError {
  let mut plane = @symcore.Expr::NumberSymbol(
    @symcore.NumberSymbolKind::NegativeInfinity,
  )
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
/// Apply the inverse Laplace transform elementwise to a matrix and evaluate
/// each entry.
pub fn inverse_laplace_transform_matrix(
  mat : @symmatrices.Matrix,
  s : Expr,
  t : Expr,
) -> @symmatrices.Matrix raise @symmatrices.MatrixError {
  mat.applyfunc(fn(cell) { doit(inverse_laplace_transform(cell, s, t)) })
}
