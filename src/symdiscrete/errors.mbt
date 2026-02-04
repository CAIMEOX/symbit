///|
/// Error types for discrete algorithms.

///|
pub(all) suberror DiscreteError {
  TypeError(String)
  ValueError(String)
} derive(Show, Eq)
