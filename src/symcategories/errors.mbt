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
    CategoryError::ValueError(msg) => logger.write_string("ValueError(\{msg})")
    CategoryError::TypeError(msg) => logger.write_string("TypeError(\{msg})")
    CategoryError::NotImplemented(msg) =>
      logger.write_string("NotImplemented(\{msg})")
    CategoryError::Unsupported(msg) =>
      logger.write_string("Unsupported(\{msg})")
  }
}
