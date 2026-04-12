///|
/// Predicates on raw `mpf` values.
pub fn is_zero(x : Mpf) -> Bool {
  @mpf.is_zero(x)
}

///|
pub fn is_finite(x : Mpf) -> Bool {
  @mpf.is_finite(x)
}

///|
pub fn is_inf(x : Mpf) -> Bool {
  @mpf.is_inf(x)
}

///|
pub fn is_nan(x : Mpf) -> Bool {
  @mpf.is_nan(x)
}

///|
pub fn mpf_pos(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_pos(x, prec, rnd)
}

///|
pub fn mpf_neg(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_neg(x, prec, rnd)
}

///|
pub fn mpf_abs(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_abs(x, prec, rnd)
}

///|
pub fn mpf_sign(x : Mpf) -> Int {
  @mpf.mpf_sign(x)
}

///|
pub fn mpf_eq(x : Mpf, y : Mpf) -> Bool {
  @mpf.mpf_eq(x, y)
}

///|
pub fn mpf_cmp(x : Mpf, y : Mpf) -> Int {
  @mpf.mpf_cmp(x, y)
}

///|
pub fn mpf_lt(x : Mpf, y : Mpf) -> Bool {
  @mpf.mpf_lt(x, y)
}

///|
pub fn mpf_le(x : Mpf, y : Mpf) -> Bool {
  @mpf.mpf_le(x, y)
}

///|
pub fn mpf_gt(x : Mpf, y : Mpf) -> Bool {
  @mpf.mpf_gt(x, y)
}

///|
pub fn mpf_ge(x : Mpf, y : Mpf) -> Bool {
  @mpf.mpf_ge(x, y)
}

///|
pub fn mpf_shift(x : Mpf, n : Int) -> Mpf {
  @mpf.mpf_shift(x, n)
}

///|
pub fn mpf_add(x : Mpf, y : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_add(x, y, prec, rnd)
}

///|
pub fn mpf_sub(x : Mpf, y : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_sub(x, y, prec, rnd)
}

///|
pub fn mpf_mul(x : Mpf, y : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_mul(x, y, prec, rnd)
}

///|
pub fn mpf_div(
  x : Mpf,
  y : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise MpfError {
  @mpf.mpf_div(x, y, prec, rnd)
}

///|
pub fn mpf_mul_int(x : Mpf, n : Int, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_mul_int(x, n, prec, rnd)
}

///|
pub fn mpf_rdiv_int(
  n : Int,
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise MpfError {
  @mpf.mpf_rdiv_int(n, x, prec, rnd)
}

///|
pub fn mpf_mod(
  x : Mpf,
  y : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise MpfError {
  @mpf.mpf_mod(x, y, prec, rnd)
}

///|
pub fn mpf_pow_int(
  x : Mpf,
  n : Int,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise MpfError {
  @mpf.mpf_pow_int(x, n, prec, rnd)
}

///|
pub fn mpf_sqrt(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf raise MpfError {
  @mpf.mpf_sqrt(x, prec, rnd)
}

///|
pub fn mpf_floor(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_floor(x, prec, rnd)
}

///|
pub fn mpf_ceil(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_ceil(x, prec, rnd)
}

///|
pub fn mpf_nint(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_nint(x, prec, rnd)
}

///|
pub fn mpf_frac(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @mpf.mpf_frac(x, prec, rnd)
}

///|
pub fn mpf_pi(prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_pi(prec, rnd)
}

///|
pub fn mpf_e(prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_e(prec, rnd)
}

///|
pub fn mpf_exp(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_exp(x, prec, rnd)
}

///|
pub fn mpf_log(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @libelefun.LibElefunError {
  @libelefun.mpf_log(x, prec, rnd)
}

///|
pub fn mpf_ln(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @libelefun.LibElefunError {
  @libelefun.mpf_ln(x, prec, rnd)
}

///|
pub fn mpf_sin(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_sin(x, prec, rnd)
}

///|
pub fn mpf_cos(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_cos(x, prec, rnd)
}

///|
pub fn mpf_tan(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_tan(x, prec, rnd)
}

///|
pub fn mpf_atan(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_atan(x, prec, rnd)
}

///|
pub fn mpf_atan2(y : Mpf, x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_atan2(y, x, prec, rnd)
}

///|
pub fn mpf_sinh(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_sinh(x, prec, rnd)
}

///|
pub fn mpf_cosh(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_cosh(x, prec, rnd)
}

///|
pub fn mpf_tanh(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libelefun.mpf_tanh(x, prec, rnd)
}

///|
pub fn mpf_pow(x : Mpf, y : Mpf, prec : Int, rnd : RoundMode) -> Mpf raise {
  @libelefun.mpf_pow(x, y, prec, rnd)
}

///|
pub fn mpf_gamma(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @gammazeta.GammaZetaError {
  @gammazeta.mpf_gamma(x, prec, rnd)
}

///|
pub fn mpf_rgamma(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @gammazeta.GammaZetaError {
  @gammazeta.mpf_rgamma(x, prec, rnd)
}

///|
pub fn mpf_loggamma(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @gammazeta.GammaZetaError {
  @gammazeta.mpf_loggamma(x, prec, rnd)
}

///|
pub fn mpf_zeta(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @gammazeta.GammaZetaError {
  @gammazeta.mpf_zeta(x, prec, rnd)
}

///|
pub fn mpf_psi(
  m : Int,
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @gammazeta.GammaZetaError {
  @gammazeta.mpf_psi(m, x, prec, rnd)
}

///|
pub fn mpf_factorial(
  n : Int,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @gammazeta.GammaZetaError {
  @gammazeta.mpf_factorial(n, prec, rnd)
}

///|
pub fn mpf_erf(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libhyper.mpf_erf(x, prec, rnd)
}

///|
pub fn mpf_erfc(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libhyper.mpf_erfc(x, prec, rnd)
}

///|
pub fn mpf_e1(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @libhyper.LibHyperError {
  @libhyper.mpf_e1(x, prec, rnd)
}

///|
pub fn mpf_expint(
  n : Int,
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
  gamma? : Bool = false,
) -> Mpf raise @libhyper.LibHyperError {
  @libhyper.mpf_expint(n, x, prec, rnd, gamma~)
}

///|
pub fn mpf_si(x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libhyper.mpf_si(x, prec, rnd)
}

///|
pub fn mpf_ci(
  x : Mpf,
  prec : Int,
  rnd : RoundMode,
) -> Mpf raise @libhyper.LibHyperError {
  @libhyper.mpf_ci(x, prec, rnd)
}

///|
pub fn mpf_besseljn(n : Int, x : Mpf, prec : Int, rnd : RoundMode) -> Mpf {
  @libhyper.mpf_besseljn(n, x, prec, rnd)
}

///|
pub fn mpc_is_inf(z : Mpc) -> Bool {
  @mpc.mpc_is_inf(z)
}

///|
pub fn mpc_is_infnan(z : Mpc) -> Bool {
  @mpc.mpc_is_infnan(z)
}

///|
pub fn mpc_pos(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_pos(z, prec, rnd)
}

///|
pub fn mpc_neg(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_neg(z, prec, rnd)
}

///|
pub fn mpc_add(z : Mpc, w : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_add(z, w, prec, rnd)
}

///|
pub fn mpc_sub(z : Mpc, w : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_sub(z, w, prec, rnd)
}

///|
pub fn mpc_mul(z : Mpc, w : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_mul(z, w, prec, rnd)
}

///|
pub fn mpc_div(z : Mpc, w : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_div(z, w, prec, rnd)
}

///|
pub fn mpc_conjugate(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_conjugate(z, prec, rnd)
}

///|
pub fn mpc_abs(z : Mpc, prec : Int, rnd : RoundMode) -> Mpf {
  @mpc.mpc_abs(z, prec, rnd)
}

///|
pub fn mpc_arg(z : Mpc, prec : Int, rnd : RoundMode) -> Mpf {
  @mpc.mpc_arg(z, prec, rnd)
}

///|
pub fn mpc_sqrt(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_sqrt(z, prec, rnd)
}

///|
pub fn mpc_exp(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_exp(z, prec, rnd)
}

///|
pub fn mpc_log(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc raise MpcError {
  @mpc.mpc_log(z, prec, rnd)
}

///|
pub fn mpc_pow(
  z : Mpc,
  w : Mpc,
  prec : Int,
  rnd : RoundMode,
) -> Mpc raise MpcError {
  @mpc.mpc_pow(z, w, prec, rnd)
}

///|
pub fn mpc_pow_int(z : Mpc, n : Int, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_pow_int(z, n, prec, rnd)
}

///|
pub fn mpc_sin(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_sin(z, prec, rnd)
}

///|
pub fn mpc_cos(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_cos(z, prec, rnd)
}

///|
pub fn mpc_tan(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_tan(z, prec, rnd)
}

///|
pub fn mpc_sinh(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_sinh(z, prec, rnd)
}

///|
pub fn mpc_cosh(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_cosh(z, prec, rnd)
}

///|
pub fn mpc_tanh(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_tanh(z, prec, rnd)
}

///|
pub fn mpc_atan(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_atan(z, prec, rnd)
}

///|
pub fn mpc_asin(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_asin(z, prec, rnd)
}

///|
pub fn mpc_acos(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_acos(z, prec, rnd)
}

///|
pub fn mpc_asinh(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_asinh(z, prec, rnd)
}

///|
pub fn mpc_acosh(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_acosh(z, prec, rnd)
}

///|
pub fn mpc_atanh(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_atanh(z, prec, rnd)
}

///|
pub fn mpc_e1(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_e1(z, prec, rnd)
}

///|
pub fn mpc_ci(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_ci(z, prec, rnd)
}

///|
pub fn mpc_si(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_si(z, prec, rnd)
}

///|
pub fn mpc_gamma(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_gamma(z, prec, rnd)
}

///|
pub fn mpc_loggamma(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_loggamma(z, prec, rnd)
}

///|
pub fn mpc_zeta(z : Mpc, prec : Int, rnd : RoundMode) -> Mpc {
  @mpc.mpc_zeta(z, prec, rnd)
}

///|
pub fn mpc_to_str(z : Mpc, dps? : Int = 15) -> String {
  @mpc.mpc_to_str(z, dps~)
}

///|
/// Integer square root.
pub fn isqrt(n : BigInt) -> BigInt raise IntMathError {
  @intmath.isqrt(n)
}

///|
/// Integer square root with remainder.
pub fn sqrtrem(n : BigInt) -> (BigInt, BigInt) raise IntMathError {
  @intmath.sqrtrem(n)
}

///|
/// Big-integer factorial.
pub fn ifac(n : Int) -> BigInt raise IntMathError {
  if n < 0 {
    raise @intmath.IntMathError::ValueError("ifac: n must be non-negative")
  }
  let mut acc = 1N
  for i in 2..<=n {
    acc = acc * BigInt::from_int(i)
  }
  acc
}

///|
/// Big-integer Fibonacci number.
pub fn ifib(n : Int) -> BigInt raise IntMathError {
  if n < 0 {
    raise @intmath.IntMathError::ValueError("ifib: n must be non-negative")
  }
  // Dijkstra's logarithmic algorithm, matching mpmath.ifib used by SymPy.
  let mut m = n
  let mut a = 1N
  let mut b = 0N
  let mut p = 0N
  let mut q = 1N
  while m > 0 {
    if (m & 1) == 1 {
      let aq = a * q
      a = b * q + aq + a * p
      b = b * p + aq
      m -= 1
    } else {
      let qq = q * q
      let old_p = p
      let old_q = q
      p = old_p * old_p + qq
      q = qq + 2N * old_p * old_q
      m = m >> 1
    }
  }
  b
}

///|
/// Precision schedule helper copied from mpmath's `giant_steps`.
pub fn giant_steps(start : Int, target : Int, n? : Int = 2) -> Array[Int] {
  let desc : Array[Int] = [target]
  while desc[desc.length() - 1] > start * n {
    desc.push(desc[desc.length() - 1] / n + 2)
  }
  let out : Array[Int] = []
  let mut i = desc.length() - 1
  while i >= 0 {
    out.push(desc[i])
    i -= 1
  }
  out
}
