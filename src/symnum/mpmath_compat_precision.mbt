///|
let log2_10 : Double = 3.3219280948873626

///|
/// Convert decimal digits to binary precision using mpmath's formula.
pub fn dps_to_prec(n : Int) -> Int {
  let bits = @math.floor((n + 1).to_double() * log2_10 + 0.5).to_int()
  if bits > 1 {
    bits
  } else {
    1
  }
}

///|
/// Convert binary precision to reliable decimal digits using mpmath's formula.
pub fn prec_to_dps(n : Int) -> Int {
  let digits = @math.floor(n.to_double() / log2_10 - 0.5).to_int()
  if digits > 1 {
    digits
  } else {
    1
  }
}

///|
/// Digits needed to print an `mpf` uniquely for round-tripping.
pub fn repr_dps(n : Int) -> Int {
  let dps = prec_to_dps(n)
  if dps == 15 {
    17
  } else {
    dps + 3
  }
}

///|
/// Create a high-level numeric context from binary precision.
pub fn mp(prec? : Int = 53, rounding? : RoundMode = round_nearest) -> MPContext {
  @mp.new(prec, rounding)
}

///|
/// Create a high-level numeric context from decimal digits.
pub fn mp_dps(dps : Int, rounding? : RoundMode = round_nearest) -> MPContext {
  mp(prec=dps_to_prec(dps), rounding~)
}

///|
/// Build a temporary context with explicit working precision.
pub fn workprec(prec : Int, rounding? : RoundMode = round_nearest) -> MPContext {
  mp(prec~, rounding~)
}

///|
/// Build a temporary context from decimal digits.
pub fn workdps(dps : Int, rounding? : RoundMode = round_nearest) -> MPContext {
  mp_dps(dps, rounding~)
}

///|
/// Function-style replacement for mpmath's `local_workprec` context manager.
pub fn[T] local_workprec(
  prec : Int,
  f : (MPContext) -> T,
  rounding? : RoundMode = round_nearest,
) -> T {
  f(workprec(prec, rounding~))
}

///|
/// Function-style replacement for mpmath's `local_workdps` context manager.
pub fn[T] local_workdps(
  dps : Int,
  f : (MPContext) -> T,
  rounding? : RoundMode = round_nearest,
) -> T {
  f(workdps(dps, rounding~))
}
