///|
/// Error types for discrete algorithms.

///|
pub(all) suberror DiscreteError {
  TypeError(String)
  ValueError(String)
} derive(Debug, Eq)

///|
pub impl Show for DiscreteError with fn output(self, logger : &Logger) -> Unit {
  match self {
    DiscreteError::TypeError(msg) => logger.write_string("TypeError(\{msg})")
    DiscreteError::ValueError(msg) => logger.write_string("ValueError(\{msg})")
  }
}
