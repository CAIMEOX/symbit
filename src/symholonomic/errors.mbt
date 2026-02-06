///|
pub(all) suberror HolonomicError {
  NotPowerSeries(String)
  NotHyperSeries(String)
  Singularity(String)
  NotHolonomic(String)
}

///|
pub impl Show for HolonomicError with output(self, logger : &Logger) -> Unit {
  match self {
    HolonomicError::NotPowerSeries(msg) => logger.write_string(msg)
    HolonomicError::NotHyperSeries(msg) => logger.write_string(msg)
    HolonomicError::Singularity(msg) => logger.write_string(msg)
    HolonomicError::NotHolonomic(msg) => logger.write_string(msg)
  }
}
