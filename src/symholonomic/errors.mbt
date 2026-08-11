///|
pub(all) suberror HolonomicError {
  NotPowerSeries(String)
  NotHyperSeries(String)
  Singularity(String)
  NotHolonomic(String)
}

///|
pub impl Show for HolonomicError with fn output(self, logger : &Logger) -> Unit {
  match self {
    NotPowerSeries(msg) => logger.write_string(msg)
    NotHyperSeries(msg) => logger.write_string(msg)
    Singularity(msg) => logger.write_string(msg)
    NotHolonomic(msg) => logger.write_string(msg)
  }
}
