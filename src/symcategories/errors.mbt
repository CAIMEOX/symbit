///|
pub(all) suberror CategoryError {
  ValueError(String)
  TypeError(String)
  NotImplemented(String)
  Unsupported(String)
} derive(Show, Eq)
