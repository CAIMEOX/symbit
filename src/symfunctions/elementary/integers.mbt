///|
/// Elementary integer-valued functions.
///
/// Current Limits:
/// - Exact integral rationals simplify locally.
/// - Symbolic assumptions, inequalities, and piecewise real analysis are not
///   complete.

///|
/// Build or evaluate a floor expression.
///
/// - Does: Returns exact integral input unchanged, otherwise builds
///   `floor(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the greatest integer not exceeding the
///   input.
/// - Limits: Does not simplify non-integral rationals or assumption-derived
///   integer expressions.
pub fn floor(expr : Expr) -> Expr {
  if is_integral_expr(expr) {
    return expr
  }
  @symcore.function("floor", [expr])
}

///|
/// Build or evaluate a ceiling expression.
///
/// - Does: Returns exact integral input unchanged, otherwise builds
///   `ceiling(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the least integer not less than the
///   input.
/// - Limits: Does not simplify non-integral rationals or assumption-derived
///   integer expressions.
pub fn ceiling(expr : Expr) -> Expr {
  if is_integral_expr(expr) {
    return expr
  }
  @symcore.function("ceiling", [expr])
}

///|
/// Build or evaluate a fractional-part expression.
///
/// - Does: Returns `0` for exact integral input, otherwise builds `frac(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the fractional part.
/// - Limits: Does not simplify non-integral rationals or assumption-derived
///   integer expressions.
pub fn frac(expr : Expr) -> Expr {
  if is_integral_expr(expr) {
    return int(0)
  }
  @symcore.function("frac", [expr])
}
