///|
fn compat_signed_man(x : Mpf) -> BigInt {
  if x.sign == 1 {
    -x.man
  } else {
    x.man
  }
}

///|
/// Normalize a raw mantissa/exponent tuple with explicit precision and rounding.
pub fn mpf_normalize(
  sign : Int,
  man : BigInt,
  exp : Int,
  bc : Int,
  prec : Int,
  rnd : RoundMode,
) -> Mpf {
  @mpf.normalize(sign, man, exp, bc, prec, rnd)
}

///|
/// Construct an `mpf` from a signed mantissa and power-of-two exponent.
pub fn from_man_exp(
  man : BigInt,
  exp : Int,
  prec? : Int = 0,
  rnd? : RoundMode = round_down,
) -> Mpf {
  @mpf.from_man_exp(man, exp, prec, rnd)
}

///|
/// Construct an exact `mpf` from a machine integer.
pub fn from_int(n : Int) -> Mpf {
  @mpf.from_int(n)
}

///|
/// Parse a decimal string into an `mpf`.
pub fn from_str(
  s : String,
  prec? : Int = 53,
  rnd? : RoundMode = round_nearest,
) -> Mpf raise MpfError {
  @mpf.from_str(s, prec~, rnd~)
}

///|
/// Construct an `mpf` from an exact rational `p/q`.
pub fn from_rational(
  p : BigInt,
  q : BigInt,
  prec : Int,
  rnd? : RoundMode = round_nearest,
) -> Mpf raise MpfError {
  if q == 0N {
    raise @mpf.MpfError::DivisionByZero("from_rational: denominator is zero")
  }
  @mpf.mpf_div(from_man_exp(p, 0), from_man_exp(q, 0), prec, rnd)
}

///|
/// Exact conversion from a machine `Double` into an `mpf`.
pub fn from_float(
  x : Double,
  prec? : Int = 53,
  rnd? : RoundMode = round_nearest,
) -> Mpf {
  let bits = Double::reinterpret_as_uint64(x)
  let zero_u = UInt64::default()
  let one_u = UInt64::extend_uint(1)
  let sign = (bits >> 63) & one_u
  let exp_mask = (one_u << 11) - one_u
  let frac_mask = (one_u << 52) - one_u
  let exp_u = (bits >> 52) & exp_mask
  let frac_u = bits & frac_mask
  let exp_bits = exp_u.to_int()
  if exp_bits == 0x7ff {
    if frac_u == zero_u {
      if sign == zero_u {
        finf
      } else {
        fninf
      }
    } else {
      fnan
    }
  } else if exp_bits == 0 {
    if frac_u == zero_u {
      fzero
    } else {
      let man0 = BigInt::from_uint64(frac_u)
      let man = if sign == zero_u { man0 } else { -man0 }
      @mpf.from_man_exp(man, -1074, prec, rnd)
    }
  } else {
    let man0 = BigInt::from_uint64(frac_u) + (1N << 52)
    let man = if sign == zero_u { man0 } else { -man0 }
    @mpf.from_man_exp(man, exp_bits - 1075, prec, rnd)
  }
}

///|
/// Convert an `mpf` into an exact rational pair `(p, q)`.
pub fn to_rational(x : Mpf) -> (BigInt, BigInt) raise MpfError {
  if @mpf.is_nan(x) || @mpf.is_inf(x) {
    raise @mpf.MpfError::ValueError("to_rational: cannot convert nan/inf")
  }
  let man = compat_signed_man(x)
  if x.exp >= 0 {
    (man << x.exp, 1N)
  } else {
    (man, 1N << -x.exp)
  }
}

///|
/// Convert an `mpf` to an arbitrary-precision integer.
pub fn to_int(x : Mpf, rnd? : RoundMode = round_down) -> BigInt raise MpfError {
  if @mpf.is_nan(x) || @mpf.is_inf(x) {
    raise @mpf.MpfError::ValueError("to_int: cannot convert nan/inf")
  }
  if x.exp >= 0 {
    compat_signed_man(x) << x.exp
  } else {
    let shift = -x.exp
    let mag = x.man
    match rnd {
      RoundMode::Down =>
        if x.sign == 1 {
          -(mag >> shift)
        } else {
          mag >> shift
        }
      RoundMode::Floor =>
        if x.sign == 1 {
          -((mag + ((1N << shift) - 1N)) >> shift)
        } else {
          mag >> shift
        }
      RoundMode::Ceiling =>
        if x.sign == 1 {
          -(mag >> shift)
        } else {
          (mag + ((1N << shift) - 1N)) >> shift
        }
      RoundMode::Up =>
        if (mag & ((1N << shift) - 1N)) == 0N {
          if x.sign == 1 {
            -(mag >> shift)
          } else {
            mag >> shift
          }
        } else if x.sign == 1 {
          -((mag + ((1N << shift) - 1N)) >> shift)
        } else {
          (mag + ((1N << shift) - 1N)) >> shift
        }
      RoundMode::Nearest => {
        let int_part = mag >> shift
        let rem_mask = (1N << shift) - 1N
        let rem = mag & rem_mask
        let half = 1N << (shift - 1)
        let rounded = if rem > half || (rem == half && (int_part & 1N) == 1N) {
          int_part + 1N
        } else {
          int_part
        }
        if x.sign == 1 {
          -rounded
        } else {
          rounded
        }
      }
    }
  }
}

///|
/// Convert an `mpf` to the nearest machine `Double`.
pub fn to_float(
  x : Mpf,
  strict? : Bool = false,
  rnd? : RoundMode = round_nearest,
) -> Double raise MpfError {
  if @mpf.is_zero(x) {
    return 0.0
  }
  if x == finf {
    return 1.0 / 0.0
  }
  if x == fninf {
    return -1.0 / 0.0
  }
  if @mpf.is_nan(x) {
    return 0.0 / 0.0
  }
  let y = if x.bc > 53 {
    @mpf.normalize(x.sign, x.man, x.exp, x.bc, 53, rnd)
  } else {
    x
  }
  let value = @string.parse_double(@mpf.to_str_opts(y, dps=17)) catch {
    _ =>
      raise @mpf.MpfError::ValueError(
        "to_float: failed to parse decimal rendering",
      )
  }
  if strict && value == 0.0 {
    raise @mpf.MpfError::ValueError("to_float: underflow")
  }
  if strict && (value == 1.0 / 0.0 || value == -1.0 / 0.0) {
    raise @mpf.MpfError::ValueError("to_float: overflow")
  }
  value
}

///|
/// Convert an `mpf` to a printable decimal or radix string.
pub fn to_str(
  x : Mpf,
  dps? : Int = 15,
  base? : Int = 10,
  binary_exp? : Bool = false,
) -> String raise MpfError {
  @mpf.to_str_opts(x, dps~, base~, binary_exp~)
}

///|
/// Format an `mpf` using the libmp formatting mini-language.
pub fn format_mpf(
  x : Mpf,
  format_spec : String,
  dps? : Int = 15,
) -> String raise MpfError {
  @mpf.format_mpf(x, format_spec, dps~)
}

///|
/// Convenience alias mirroring mpmath's `make_mpf` naming.
pub fn make_mpf(
  s : String,
  prec? : Int = 53,
  rnd? : RoundMode = round_nearest,
) -> Mpf raise MpfError {
  from_str(s, prec~, rnd~)
}

///|
/// Build a complex value from real and imaginary parts.
pub fn make_mpc(real : Mpf, imag? : Mpf = fzero) -> Mpc {
  @mpc.from_parts(real, imag)
}
