///|
/// Build an exact interval from lower and upper endpoints.
pub fn mpi(lo : Mpf, hi : Mpf) -> Mpi {
  @libmpi.mpi_make(lo, hi)
}

///|
/// Parse an interval literal.
pub fn mpi_from_str(s : String, prec? : Int = 0) -> Mpi raise MpiError {
  @libmpi.mpi_from_str(s, prec~)
}

///|
/// Parse a degenerate interval from a decimal literal.
pub fn MPIntervalContext::make_float(
  self : MPIntervalContext,
  s : String,
) -> Mpi raise MpiError {
  @libmpi.mpi_from_str(s, prec=self.prec)
}

///|
/// Construct a closed interval from real endpoints.
pub fn MPIntervalContext::make_interval(
  self : MPIntervalContext,
  lo : Mpf,
  hi : Mpf,
) -> Mpi {
  ignore(self)
  @libmpi.mpi_make(lo, hi)
}

///|
/// Convert an interval to text using the configured precision.
pub fn MPIntervalContext::to_string(
  self : MPIntervalContext,
  value : Mpi,
  dps? : Int = 15,
) -> String raise MpiError {
  ignore(self)
  @libmpi.mpi_to_str(value, dps~)
}

///|
/// Interval addition.
pub fn MPIntervalContext::add(
  self : MPIntervalContext,
  a : Mpi,
  b : Mpi,
) -> Mpi {
  @libmpi.mpi_add(a, b, prec=self.prec)
}

///|
/// Interval subtraction.
pub fn MPIntervalContext::sub(
  self : MPIntervalContext,
  a : Mpi,
  b : Mpi,
) -> Mpi {
  @libmpi.mpi_sub(a, b, prec=self.prec)
}

///|
/// Interval multiplication.
pub fn MPIntervalContext::mul(
  self : MPIntervalContext,
  a : Mpi,
  b : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_mul(a, b, prec=self.prec)
}

///|
/// Interval division.
pub fn MPIntervalContext::div(
  self : MPIntervalContext,
  a : Mpi,
  b : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_div(a, b, self.prec)
}

///|
/// Interval negation.
pub fn MPIntervalContext::neg(self : MPIntervalContext, a : Mpi) -> Mpi {
  @libmpi.mpi_neg(a, prec=self.prec)
}

///|
/// Interval absolute value.
pub fn MPIntervalContext::abs(self : MPIntervalContext, a : Mpi) -> Mpi {
  @libmpi.mpi_abs(a, prec=self.prec)
}

///|
/// Interval square root.
pub fn MPIntervalContext::sqrt(
  self : MPIntervalContext,
  a : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_sqrt(a, self.prec)
}

///|
/// Interval exponential.
pub fn MPIntervalContext::exp(self : MPIntervalContext, a : Mpi) -> Mpi {
  @libmpi.mpi_exp(a, self.prec)
}

///|
/// Interval logarithm.
pub fn MPIntervalContext::log(
  self : MPIntervalContext,
  a : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_log(a, self.prec)
}

///|
/// Interval sine.
pub fn MPIntervalContext::sin(
  self : MPIntervalContext,
  a : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_sin(a, self.prec)
}

///|
/// Interval cosine.
pub fn MPIntervalContext::cos(
  self : MPIntervalContext,
  a : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_cos(a, self.prec)
}

///|
/// Interval tangent.
pub fn MPIntervalContext::tan(
  self : MPIntervalContext,
  a : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_tan(a, self.prec)
}

///|
/// Interval gamma function.
pub fn MPIntervalContext::gamma(
  self : MPIntervalContext,
  a : Mpi,
) -> Mpi raise MpiError {
  @libmpi.mpi_gamma(a, self.prec)
}
