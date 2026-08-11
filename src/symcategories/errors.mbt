///|
pub(all) suberror CategoryError {
  ValueError(String)
  TypeError(String)
  NotImplemented(String)
  Unsupported(String)
} derive(Debug, Eq)

///|
pub impl Show for CategoryError with fn output(self, logger : &Logger) -> Unit {
  match self {
    ValueError(msg) => logger.write_string("ValueError(\{msg})")
    TypeError(msg) => logger.write_string("TypeError(\{msg})")
    NotImplemented(msg) => logger.write_string("NotImplemented(\{msg})")
    Unsupported(msg) => logger.write_string("Unsupported(\{msg})")
  }
}
