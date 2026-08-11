///|
/// Dense floating-point matrix type used by the mpmath-style compatibility API.
pub type MpfMatrix = @mp.MpfMatrix

///|
/// Compatibility alias matching `mpmath.libmp.normalize`.
pub fn normalize(
  sign : Int,
  man : BigInt,
  exp : Int,
  bc : Int,
  prec : Int,
  rnd : RoundMode,
) -> Mpf {
  mpf_normalize(sign, man, exp, bc, prec, rnd)
}

///|
/// Minimal `mpmath.mpf(...)`-style constructor subset using string input.
pub fn mpf(
  value : String,
  prec? : Int = 53,
  rnd? : RoundMode = round_nearest,
) -> Mpf raise MpfError {
  from_str(value, prec~, rnd~)
}

///|
/// Minimal `mpmath.mpc(...)`-style constructor subset from real/imag parts.
pub fn mpc(real : Mpf, imag? : Mpf = fzero) -> Mpc {
  make_mpc(real, imag~)
}

///|
/// Real square root wrapper over a temporary context.
pub fn sqrt(
  x : Mpf,
  prec? : Int = 53,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  mp(prec~, rounding~).sqrt(x)
}

///|
/// Factorial wrapper matching mpmath's real-valued `fac(x) = gamma(x + 1)`.
pub fn fac(
  x : Mpf,
  prec? : Int = 53,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let p = prec
  let r = rounding
  let shifted = mpf_add(x, fone, p, r)
  mp(prec=p, rounding=r).gamma(shifted)
}

///|
/// Low-level helper returning `(cosh(x), sinh(x))` in one pass.
pub fn mpf_cosh_sinh(x : Mpf, prec : Int, rnd : RoundMode) -> (Mpf, Mpf) {
  @libelefun.mpf_cosh_sinh(x, prec, rnd)
}

///|
/// Raise a complex number to a real floating-point power.
pub fn mpc_pow_mpf(z : Mpc, w : Mpf, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_pow_mpf(z, w, prec, rnd)
}

///|
/// Construct a dense real matrix from row-major `mpf` data.
pub fn _matrix(
  rows_data : ArrayView[Array[Mpf]],
  prec? : Int = 53,
  rounding? : RoundMode = round_nearest,
) -> MpfMatrix raise MPError {
  mp(prec~, rounding~).matrix_from_rows(rows_data)
}

///|
fn fixed_from_mpf(x : Mpf, prec : Int) -> BigInt raise MpfError {
  to_int(mpf_shift(x, prec), rnd=round_nearest)
}

///|
/// Golden ratio in fixed-point form scaled by `2**prec`.
pub fn phi_fixed(prec : Int) -> BigInt raise MpfError {
  fixed_from_mpf(@libelefun.mpf_phi(prec, round_nearest), prec)
}

///|
/// Catalan's constant in fixed-point form scaled by `2**prec`.
pub fn catalan_fixed(prec : Int) -> BigInt raise MpfError {
  fixed_from_mpf(@gammazeta.mpf_catalan(prec, round_nearest), prec)
}

///|
/// Euler-Mascheroni constant in fixed-point form scaled by `2**prec`.
pub fn euler_fixed(prec : Int) -> BigInt raise MpfError {
  fixed_from_mpf(@gammazeta.mpf_euler(prec, round_nearest), prec)
}

///|
/// Compatibility probe for callers that used `except NoConvergence`.
pub fn is_no_convergence(err : MPError) -> Bool {
  match err {
    ConvergenceError(_) => true
    _ => false
  }
}

///|
/// Compatibility probe for callers that used `except ComplexResult`.
pub fn is_complex_result(err : MPError) -> Bool {
  match err {
    ComplexResult(_) => true
    _ => false
  }
}
