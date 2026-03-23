///|
/// Minimal arbitrary-precision complex floating literal backed by `symnum`'s
/// mpmath-compatible `Mpc`.
pub struct ComplexFloat {
  value : @symnum.Mpc
  prec : Int
} derive(Eq)

///|
fn complex_float_default_prec(prec : Int) -> Int {
  if prec > 0 {
    prec
  } else {
    53
  }
}

///|
fn complex_common_prec(lhs : ComplexFloat, rhs : ComplexFloat) -> Int {
  if lhs.precision() > rhs.precision() {
    lhs.precision()
  } else {
    rhs.precision()
  }
}

///|
fn complex_promote(value : ComplexFloat, prec : Int) -> ComplexFloat {
  if value.precision() >= prec {
    value
  } else {
    ComplexFloat::from_parts(
      @symnum.mpf_pos(value.to_mpc().real, prec, @symnum.round_nearest),
      @symnum.mpf_pos(value.to_mpc().imag, prec, @symnum.round_nearest),
      prec=prec,
    )
  }
}

///|
pub fn ComplexFloat::from_mpc(
  value : @symnum.Mpc,
  prec? : Int = 53,
) -> ComplexFloat {
  { value, prec: complex_float_default_prec(prec) }
}

///|
pub fn ComplexFloat::from_parts(
  real : @symnum.Mpf,
  imag : @symnum.Mpf,
  prec? : Int = 53,
) -> ComplexFloat {
  let p = complex_float_default_prec(prec)
  { value: @symnum.make_mpc(real, imag=imag), prec: p }
}

///|
pub fn ComplexFloat::from_real(
  real : Float,
  imag? : Float = Float::from_int(0),
) -> ComplexFloat {
  let p = if real.precision() > imag.precision() {
    real.precision()
  } else {
    imag.precision()
  }
  {
    value: @symnum.make_mpc(
      @symnum.mpf_pos(real.to_mpf(), p, @symnum.round_nearest),
      imag=@symnum.mpf_pos(imag.to_mpf(), p, @symnum.round_nearest),
    ),
    prec: p,
  }
}

///|
pub fn ComplexFloat::from_exact_parts(
  real : @symnum.BigRational,
  imag : @symnum.BigRational,
  prec? : Int = 53,
) -> ComplexFloat {
  let p = complex_float_default_prec(prec)
  let real_float = Float::from_exact(real, prec=p) catch {
    _ => Float::from_mpf(@symnum.fnan, prec=p)
  }
  let imag_float = Float::from_exact(imag, prec=p) catch {
    _ => Float::from_mpf(@symnum.fnan, prec=p)
  }
  ComplexFloat::from_real(real_float, imag=imag_float)
}

///|
pub fn ComplexFloat::to_mpc(self : ComplexFloat) -> @symnum.Mpc {
  self.value
}

///|
pub fn ComplexFloat::precision(self : ComplexFloat) -> Int {
  self.prec
}

///|
pub fn ComplexFloat::real_part(self : ComplexFloat) -> Float {
  Float::from_mpf(
    @symnum.mpf_pos(self.value.real, self.prec, @symnum.round_nearest),
    prec=self.prec,
  )
}

///|
pub fn ComplexFloat::imag_part(self : ComplexFloat) -> Float {
  Float::from_mpf(
    @symnum.mpf_pos(self.value.imag, self.prec, @symnum.round_nearest),
    prec=self.prec,
  )
}

///|
pub fn ComplexFloat::is_finite(self : ComplexFloat) -> Bool {
  @symnum.is_finite(self.value.real) && @symnum.is_finite(self.value.imag)
}

///|
pub fn ComplexFloat::to_rational_parts(
  self : ComplexFloat,
) -> ((BigInt, BigInt), (BigInt, BigInt)) raise @symnum.MpfError {
  (@symnum.to_rational(self.value.real), @symnum.to_rational(self.value.imag))
}

///|
pub fn ComplexFloat::format(self : ComplexFloat, dps? : Int) -> String {
  let digits = match dps {
    Some(v) if v > 0 => v
    _ => @symnum.repr_dps(self.prec)
  }
  let real_s = self.real_part().format(dps=digits)
  let imag_s = self.imag_part().format(dps=digits)
  if @symnum.is_zero(self.value.imag) {
    real_s
  } else if @symnum.is_zero(self.value.real) {
    "\{imag_s}*I"
  } else if @symnum.mpf_sign(self.value.imag) < 0 {
    let imag_abs = Float::from_mpf(
      @symnum.mpf_abs(self.value.imag, self.prec, @symnum.round_nearest),
      prec=self.prec,
    )
    "\{real_s} - \{imag_abs.format(dps=digits)}*I"
  } else {
    "\{real_s} + \{imag_s}*I"
  }
}

///|
pub fn ComplexFloat::reciprocal(
  self : ComplexFloat,
) -> ComplexFloat {
  ComplexFloat::from_mpc(
    @symnum.mpc_div(
      @symnum.make_mpc(@symnum.fone, imag=@symnum.fzero),
      self.value,
      self.prec,
      @symnum.round_nearest,
    ),
    prec=self.prec,
  )
}

///|
pub impl Add for ComplexFloat with add(self, other : ComplexFloat) -> ComplexFloat {
  let p = complex_common_prec(self, other)
  let lhs = complex_promote(self, p)
  let rhs = complex_promote(other, p)
  ComplexFloat::from_mpc(
    @symnum.mpc_add(lhs.to_mpc(), rhs.to_mpc(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
pub impl Mul for ComplexFloat with mul(self, other : ComplexFloat) -> ComplexFloat {
  let p = complex_common_prec(self, other)
  let lhs = complex_promote(self, p)
  let rhs = complex_promote(other, p)
  ComplexFloat::from_mpc(
    @symnum.mpc_mul(lhs.to_mpc(), rhs.to_mpc(), p, @symnum.round_nearest),
    prec=p,
  )
}

///|
pub impl Neg for ComplexFloat with neg(self) -> ComplexFloat {
  ComplexFloat::from_mpc(
    @symnum.mpc_neg(self.to_mpc(), self.prec, @symnum.round_nearest),
    prec=self.prec,
  )
}

///|
pub impl Show for ComplexFloat with to_string(self) {
  self.format()
}

///|
pub impl Show for ComplexFloat with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn complex_float_from_exact_parts(
  real : @symnum.BigRational,
  imag : @symnum.BigRational,
  prec? : Int = 53,
) -> ComplexFloat {
  ComplexFloat::from_exact_parts(real, imag, prec~)
}
