///|
/// Hypergeometric and Meijer G functions.
///
/// Current Limits:
/// - Parameter lists are packed into tuple expressions.
/// - Convergence checks, parameter cancellation, and special-function rewrites
///   are not implemented here.

///|
/// Build a generalized hypergeometric expression.
///
/// - Does: Builds `hyper(a, b, z)` with numerator and denominator parameter
///   arrays stored as tuples.
/// - Input: Numerator parameters, denominator parameters, and argument
///   expression.
/// - Returns: A symbolic hypergeometric expression.
/// - Limits: Does not validate convergence or simplify parameter overlaps.
pub fn hyper(a : Array[Expr], b : Array[Expr], z : Expr) -> Expr {
  let args : Array[Expr] = Array::new()
  args.push(@symcore.Expr::Tuple(a))
  args.push(@symcore.Expr::Tuple(b))
  args.push(z)
  @symcore.function("hyper", args)
}

///|
/// Build a Meijer G expression.
///
/// - Does: Builds `meijerg((a1, a2), (b1, b2), z)` using tuple-packed
///   parameter blocks.
/// - Input: Four parameter arrays and one argument expression.
/// - Returns: A symbolic Meijer G expression.
/// - Limits: Does not validate contour conditions or simplify parameter
///   collisions.
pub fn meijerg(
  a1 : Array[Expr],
  a2 : Array[Expr],
  b1 : Array[Expr],
  b2 : Array[Expr],
  z : Expr,
) -> Expr {
  let args : Array[Expr] = Array::new()
  let a = @symcore.Expr::Tuple([
    @symcore.Expr::Tuple(a1),
    @symcore.Expr::Tuple(a2),
  ])
  let b = @symcore.Expr::Tuple([
    @symcore.Expr::Tuple(b1),
    @symcore.Expr::Tuple(b2),
  ])
  args.push(a)
  args.push(b)
  args.push(z)
  @symcore.function("meijerg", args)
}

///|
/// Build an Appell F1 expression.
///
/// - Does: Builds `appellf1(a, b1, b2, c, x, y)`.
/// - Input: Four parameter expressions and two argument expressions.
/// - Returns: A symbolic Appell F1 expression.
/// - Limits: Does not validate convergence or reduce special parameter cases.
pub fn appellf1(
  a : Expr,
  b1 : Expr,
  b2 : Expr,
  c : Expr,
  x : Expr,
  y : Expr,
) -> Expr {
  @symcore.function("appellf1", [a, b1, b2, c, x, y])
}
