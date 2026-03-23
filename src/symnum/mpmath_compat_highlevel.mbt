///|
/// Identify a floating-point value as a small symbolic constant expression.
pub fn identify(
  x : Mpf,
  constants? : Map[String, Mpf] = {},
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> String raise MPError {
  let ctx = mp(prec~, rounding~)
  ctx.identify(x, constants~)
}

///|
/// Numerical derivative wrapper over a temporary context.
pub fn diff(
  f : UnaryMpfFn,
  x : Mpf,
  n? : Int = 1,
  direction? : Int = 0,
  algo? : String = "step",
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  ctx.diff(f, x, n~, direction~, algo~)
}

///|
/// Numerical root-finder wrapper over a temporary context.
pub fn findroot(
  f : UnaryMpfFn,
  x0 : Mpf,
  x1? : Mpf,
  tol? : Mpf,
  max_steps? : Int = 80,
  solver? : String = "auto",
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  match (x1, tol) {
    (Some(v1), Some(vtol)) =>
      ctx.findroot(f, x0, x1=v1, tol=vtol, max_steps~, solver~)
    (Some(v1), None) => ctx.findroot(f, x0, x1=v1, max_steps~, solver~)
    (None, Some(vtol)) => ctx.findroot(f, x0, tol=vtol, max_steps~, solver~)
    (None, None) => ctx.findroot(f, x0, max_steps~, solver~)
  }
}

///|
/// Finite or infinite-interval quadrature over breakpoints.
pub fn quad(
  f : UnaryMpfFn,
  points : ArrayView[Mpf],
  max_steps? : Int = 12,
  max_degree? : Int,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  match max_degree {
    Some(v) => ctx.quad(f, points, max_steps~, max_degree=v)
    None => ctx.quad(f, points, max_steps~)
  }
}

///|
/// Tanh-sinh style one-dimensional quadrature.
pub fn quadts(
  f : UnaryMpfFn,
  a : Mpf,
  b : Mpf,
  max_steps? : Int = 12,
  max_degree? : Int,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  match max_degree {
    Some(v) => ctx.quadts(f, a, b, max_steps~, max_degree=v)
    None => ctx.quadts(f, a, b, max_steps~)
  }
}

///|
/// Gauss-Legendre style one-dimensional quadrature.
pub fn quadgl(
  f : UnaryMpfFn,
  a : Mpf,
  b : Mpf,
  max_steps? : Int = 12,
  max_degree? : Int,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  match max_degree {
    Some(v) => ctx.quadgl(f, a, b, max_steps~, max_degree=v)
    None => ctx.quadgl(f, a, b, max_steps~)
  }
}

///|
/// Finite summation wrapper.
pub fn summation(
  f : SeriesTermFn,
  start : Int,
  stop : Int,
  step? : Int = 1,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  ctx.summation(f, start, stop, step~)
}

///|
/// Numerical summation wrapper with acceleration.
pub fn nsum(
  f : SeriesTermFn,
  start : Int,
  stop? : Int,
  algo? : String = "auto",
  tol? : Mpf,
  max_terms? : Int = 800,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  match (stop, tol) {
    (Some(vstop), Some(vtol)) =>
      ctx.nsum(f, start, stop=vstop, algo~, tol=vtol, max_terms~)
    (Some(vstop), None) => ctx.nsum(f, start, stop=vstop, algo~, max_terms~)
    (None, Some(vtol)) => ctx.nsum(f, start, algo~, tol=vtol, max_terms~)
    (None, None) => ctx.nsum(f, start, algo~, max_terms~)
  }
}

///|
/// Numerical product wrapper with acceleration.
pub fn nprod(
  f : SeriesTermFn,
  start : Int,
  stop? : Int,
  algo? : String = "auto",
  tol? : Mpf,
  max_terms? : Int = 800,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  match (stop, tol) {
    (Some(vstop), Some(vtol)) =>
      ctx.nprod(f, start, stop=vstop, algo~, tol=vtol, max_terms~)
    (Some(vstop), None) => ctx.nprod(f, start, stop=vstop, algo~, max_terms~)
    (None, Some(vtol)) => ctx.nprod(f, start, algo~, tol=vtol, max_terms~)
    (None, None) => ctx.nprod(f, start, algo~, max_terms~)
  }
}

///|
/// Numerical limit wrapper.
pub fn limit(
  f : UnaryMpfFn,
  x : Mpf,
  direction? : Int = 0,
  max_steps? : Int = 32,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Mpf raise MPError {
  let ctx = mp(prec~, rounding~)
  ctx.limit(f, x, direction~, max_steps~)
}

///|
/// Polynomial roots wrapper for real coefficients.
pub fn polyroots(
  coeffs : ArrayView[Mpf],
  asc? : Bool = true,
  max_steps? : Int = 60,
  cleanup? : Bool = true,
  extraprec? : Int = 0,
  prec? : Int = 80,
  rounding? : RoundMode = round_nearest,
) -> Array[Mpc] raise MPError {
  let ctx = mp(prec~, rounding~)
  ctx.polyroots(coeffs, asc~, max_steps~, cleanup~, extraprec~)
}
