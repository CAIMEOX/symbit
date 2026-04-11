///|
/// Low-level arbitrary-precision real backed by `moon_floating` libmp.
pub type Mpf = @mpf.RawMpf

///|
/// Low-level arbitrary-precision complex backed by `moon_floating` libmp.
pub type Mpc = @mpc.RawMpc

///|
/// Arbitrary-precision real interval backed by `moon_floating` libmpi.
pub type Mpi = @libmpi.RawMpi

///|
/// High-level numeric context mirroring the `mpmath.mp` runtime state.
pub type MPContext = @mp.MPContext

///|
/// Error family used by high-level context operations.
pub type MPError = @mp.MPError

///|
/// Raw `mpf` error surface.
pub type MpfError = @mpf.MpfError

///|
/// Raw `mpc` error surface.
pub type MpcError = @mpc.MpcError

///|
/// Raw interval error surface.
pub type MpiError = @libmpi.MpiError

///|
/// Integer-math error surface used by helpers like `isqrt`.
pub type IntMathError = @intmath.IntMathError

///|
/// Public alias for the raw rounding mode used by libmp functions.
pub type RoundMode = @mpf.RoundMode

///|
/// MoonBit replacement for mpmath's `MPZ` arbitrary-precision integer type.
pub type MPZ = BigInt

///|
/// Canonical `MPZ(1)`.
pub let mpz_one : BigInt = 1N

///|
/// Real unary callback used by `diff`, `findroot`, `quad`, and `limit` wrappers.
pub type UnaryMpfFn = (Mpf) -> Mpf

///|
/// Integer-indexed term callback used by `summation`, `nsum`, and `nprod`.
pub type SeriesTermFn = (Int) -> Mpf

///|
/// Interval context that carries precision for parse/format and interval ops.
pub struct MPIntervalContext {
  prec : Int
} derive(Debug, Eq)

///|
/// Default round-to-nearest mode.
pub let round_nearest : RoundMode = @mpf.round_nearest

///|
/// Round toward negative infinity.
pub let round_floor : RoundMode = @mpf.round_floor

///|
/// Round toward positive infinity.
pub let round_ceiling : RoundMode = @mpf.round_ceiling

///|
/// Round away from zero.
pub let round_up : RoundMode = @mpf.round_up

///|
/// Round toward zero.
pub let round_down : RoundMode = @mpf.round_down

///|
/// Canonical positive zero.
pub let fzero : Mpf = @mpf.fzero

///|
/// Canonical positive one.
pub let fone : Mpf = @mpf.fone

///|
/// Canonical negative one.
pub let fnone : Mpf = @mpf.fnone

///|
/// Canonical positive infinity.
pub let finf : Mpf = @mpf.finf

///|
/// Canonical negative infinity.
pub let fninf : Mpf = @mpf.fninf

///|
/// Canonical NaN sentinel.
pub let fnan : Mpf = @mpf.fnan

///|
/// Alias matching mpmath's positive infinity constant.
pub let inf : Mpf = @mpf.finf

///|
/// Alias matching mpmath's negative infinity constant.
pub let ninf : Mpf = @mpf.fninf

///|
/// Exact one-half.
pub let fhalf : Mpf = @mpf.from_man_exp(1N, -1, 0, @mpf.round_down)

///|
/// Construct an interval context with explicit binary precision.
pub fn interval_context(prec : Int) -> MPIntervalContext {
  { prec, }
}

///|
/// Return interval-context precision in bits.
pub fn MPIntervalContext::precision(self : MPIntervalContext) -> Int {
  self.prec
}
