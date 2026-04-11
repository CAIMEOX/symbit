///|
/// Error types for symbolic physics helpers.

///|
pub(all) suberror PhysicsError {
  ValueError(String)
  IndexError(String)
  ShapeError(String)
} derive(Debug, Eq)
