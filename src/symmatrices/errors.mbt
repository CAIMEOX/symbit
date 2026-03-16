///|
/// Matrix package errors aligned with the common SymPy matrix failure modes.
pub(all) suberror MatrixError {
  ShapeError(String)
  ValueError(String)
  NonSquareMatrixError(String)
  SingularMatrixError(String)
  IndexError(String)
} derive(Show, Eq)
