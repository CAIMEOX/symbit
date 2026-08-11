///|
/// Error types for symbolic physics helpers.

///|
pub(all) suberror PhysicsError {
  ValueError(String)
  IndexError(String)
  ShapeError(String)
} derive(Debug, Eq)

///|
pub impl Show for PhysicsError with fn output(self, logger : &Logger) -> Unit {
  match self {
    PhysicsError::ValueError(msg) => logger.write_string("ValueError(\{msg})")
    PhysicsError::IndexError(msg) => logger.write_string("IndexError(\{msg})")
    PhysicsError::ShapeError(msg) => logger.write_string("ShapeError(\{msg})")
  }
}
