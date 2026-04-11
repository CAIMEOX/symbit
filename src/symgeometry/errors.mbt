///|
/// Errors raised by the geometry package when a construction is invalid or a
/// symbolic relation cannot be decided from the available algebra.
pub suberror GeometryError {
  ValueError(String)
  TypeError(String)
  Undecidable(String)
} derive(Eq, Debug)
