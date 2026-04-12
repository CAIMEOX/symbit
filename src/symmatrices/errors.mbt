///|
/// Matrix package errors aligned with the common SymPy matrix failure modes.
pub(all) suberror MatrixError {
  ShapeError(String)
  ValueError(String)
  NonSquareMatrixError(String)
  SingularMatrixError(String)
  IndexError(String)
} derive(Debug, Eq)

///|
pub impl Show for MatrixError with output(self, logger : &Logger) -> Unit {
  match self {
    MatrixError::ShapeError(msg) => logger.write_string("ShapeError(\{msg})")
    MatrixError::ValueError(msg) => logger.write_string("ValueError(\{msg})")
    MatrixError::NonSquareMatrixError(msg) =>
      logger.write_string("NonSquareMatrixError(\{msg})")
    MatrixError::SingularMatrixError(msg) =>
      logger.write_string("SingularMatrixError(\{msg})")
    MatrixError::IndexError(msg) => logger.write_string("IndexError(\{msg})")
  }
}
