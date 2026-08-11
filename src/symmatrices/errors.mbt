///|
/// Matrix package errors aligned with the common SymPy matrix failure modes.
///
/// - Does: Groups the front-door errors raised by dense, sparse, symbolic, and exact matrix operations.
/// - Input: Error constructors carry one explanatory `String`.
/// - Returns: A `MatrixError` value.
/// - Limits: Lower-level arithmetic failures are usually translated into one of these variants instead of being exposed directly.
pub(all) suberror MatrixError {
  ShapeError(String)
  ValueError(String)
  NonSquareMatrixError(String)
  SingularMatrixError(String)
  IndexError(String)
} derive(Debug, Eq)

///|
/// Render a matrix error in the package's stable textual form.
///
/// - Does: Formats the variant name together with its message.
/// - Input: One `MatrixError`.
/// - Returns: Text written into the supplied `Logger`.
/// - Limits: Output is intended for diagnostics and tests, so changing it can invalidate string-based assertions.
pub impl Show for MatrixError with fn output(self, logger : &Logger) -> Unit {
  match self {
    ShapeError(msg) => logger.write_string("ShapeError(\{msg})")
    ValueError(msg) => logger.write_string("ValueError(\{msg})")
    NonSquareMatrixError(msg) =>
      logger.write_string("NonSquareMatrixError(\{msg})")
    SingularMatrixError(msg) =>
      logger.write_string("SingularMatrixError(\{msg})")
    IndexError(msg) => logger.write_string("IndexError(\{msg})")
  }
}
