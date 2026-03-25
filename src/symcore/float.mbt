///|
/// Minimal arbitrary-precision floating literal backed by `symnum`'s
/// mpmath-compatible `Mpf`.
pub struct Float {
  value : @symnum.Mpf
  prec : Int
} derive(Eq)

///|
fn float_default_prec(prec : Int) -> Int {
  if prec > 0 {
    prec
  } else {
    53
  }
}

///|
fn float_common_prec(lhs : Float, rhs : Float) -> Int {
  if lhs.precision() > rhs.precision() {
    lhs.precision()
  } else {
    rhs.precision()
  }
}

///|
fn float_promote(value : Float, prec : Int) -> Float {
  if value.precision() >= prec {
    value
  } else {
    Float::from_mpf(
      @symnum.mpf_pos(value.to_mpf(), prec, @symnum.round_nearest),
      prec~,
    )
  }
}

///|
/// Wrap an existing raw `Mpf` together with the precision it should carry in
/// Symbit's core object layer.
pub fn Float::from_mpf(value : @symnum.Mpf, prec? : Int = 53) -> Float {
  { value, prec: float_default_prec(prec) }
}

///|
/// Parse a decimal string into a core `Float`.
pub fn Float::from_str(
  text : String,
  prec? : Int = 53,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float raise @symnum.MpfError {
  let p = float_default_prec(prec)
  { value: @symnum.from_str(text, prec=p, rnd~), prec: p }
}

///|
/// Convert a machine `Double` into a core `Float`.
pub fn Float::from_double(
  value : Double,
  prec? : Int = 53,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float {
  let p = float_default_prec(prec)
  { value: @symnum.from_float(value, prec=p, rnd~), prec: p }
}

///|
/// Convert an exact rational into a core `Float` at the requested precision.
pub fn Float::from_rational(
  num : BigInt,
  den : BigInt,
  prec : Int,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float raise @symnum.MpfError {
  let p = float_default_prec(prec)
  { value: @symnum.from_rational(num, den, p, rnd~), prec: p }
}

///|
/// Convert a `BigRational` into a floating literal.
pub fn Float::from_exact(
  value : @symnum.BigRational,
  prec? : Int = 53,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float raise @symnum.MpfError {
  let p = float_default_prec(prec)
  Float::from_rational(value.numerator(), value.denominator(), p, rnd~)
}

///|
/// Construct a floating literal from an integer.
pub fn Float::from_int(value : Int, prec? : Int = 53) -> Float {
  let p = float_default_prec(prec)
  { value: @symnum.from_int(value), prec: p }
}

///|
/// Return the underlying raw `Mpf` payload.
pub fn Float::to_mpf(self : Float) -> @symnum.Mpf {
  self.value
}

///|
/// Return the tracked binary precision.
pub fn Float::precision(self : Float) -> Int {
  self.prec
}

///|
/// True when the underlying payload is finite.
pub fn Float::is_finite(self : Float) -> Bool {
  @symnum.is_finite(self.value)
}

///|
/// Convert the floating literal back into an exact rational pair when finite.
pub fn Float::to_rational(
  self : Float,
) -> (BigInt, BigInt) raise @symnum.MpfError {
  @symnum.to_rational(self.value)
}

///|
/// Convert the floating literal to a machine `Double`.
pub fn Float::to_double(
  self : Float,
  strict? : Bool = false,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Double raise @symnum.MpfError {
  @symnum.to_float(self.value, strict~, rnd~)
}

///|
/// Render the floating literal with a stable decimal representation.
pub fn Float::format(self : Float, dps? : Int) -> String {
  let digits = match dps {
    Some(v) if v > 0 => v
    _ => @symnum.repr_dps(self.prec)
  }
  @symnum.to_str(self.value, dps=digits) catch {
    _ => "<float>"
  }
}

///|
pub fn Float::reciprocal(self : Float) -> Float raise @symnum.MpfError {
  Float::from_mpf(
    @symnum.mpf_div(@symnum.fone, self.value, self.prec, @symnum.round_nearest),
    prec=self.prec,
  )
}

///|
pub impl Add for Float with add(self, other : Float) -> Float {
  let p = float_common_prec(self, other)
  let lhs = float_promote(self, p)
  let rhs = float_promote(other, p)
  Float::from_mpf(
    @symnum.mpf_add(lhs.to_mpf(), rhs.to_mpf(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
pub impl Mul for Float with mul(self, other : Float) -> Float {
  let p = float_common_prec(self, other)
  let lhs = float_promote(self, p)
  let rhs = float_promote(other, p)
  Float::from_mpf(
    @symnum.mpf_mul(lhs.to_mpf(), rhs.to_mpf(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
pub impl Neg for Float with neg(self) -> Float {
  Float::from_mpf(
    @symnum.mpf_neg(self.to_mpf(), self.prec, @symnum.round_nearest),
    prec=self.prec,
  )
}

///|
pub impl Show for Float with to_string(self) {
  self.format()
}

///|
pub impl Show for Float with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// Top-level convenience wrapper matching the rest of `symcore`.
pub fn float_from_str(
  text : String,
  prec? : Int = 53,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float raise @symnum.MpfError {
  Float::from_str(text, prec~, rnd~)
}

///|
/// Top-level convenience wrapper from `Double`.
pub fn float_from_double(
  value : Double,
  prec? : Int = 53,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float {
  Float::from_double(value, prec~, rnd~)
}

///|
/// Top-level convenience wrapper from an exact rational.
pub fn float_from_exact(
  value : @symnum.BigRational,
  prec? : Int = 53,
  rnd? : @symnum.RoundMode = @symnum.round_nearest,
) -> Float raise @symnum.MpfError {
  Float::from_exact(value, prec~, rnd~)
}
