///|
/// Elementary exponential functions.
///
/// Current Limits:
/// - The front doors mostly build symbolic applications.
/// - Only exact `exp(0)` and `log(1)` simplifications are handled here.
/// - Branch analysis, logarithm expansion, and Lambert W branch selection are
///   not complete.

///|
/// Build a symbolic exponential expression.
///
/// - Does: Returns `1` for exact zero input, otherwise builds `exp(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the exponential of the input.
/// - Limits: Does not simplify logarithmic inverses, powers, or branch-sensitive
///   forms.
pub fn exp(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(1)
  }
  @symcore.function("exp", [expr])
}

///|
/// Build a symbolic polar exponential expression.
///
/// - Does: Builds `exp_polar(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression on the polar exponential surface.
/// - Limits: Does not currently canonicalize polar branches.
pub fn exp_polar(expr : Expr) -> Expr {
  @symcore.function("exp_polar", [expr])
}

///|
/// Build a symbolic natural logarithm expression.
///
/// - Does: Returns `0` for exact one input, otherwise builds `log(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the natural logarithm.
/// - Limits: Does not expand products, powers, or branch-sensitive logarithms.
pub fn log(expr : Expr) -> Expr {
  if is_one_expr(expr) {
    return int(0)
  }
  @symcore.function("log", [expr])
}

///|
/// Build a symbolic natural logarithm expression.
///
/// - Does: Alias for [`log`](#log).
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the natural logarithm.
/// - Limits: Has the same evaluation limits as `log`.
pub fn ln(expr : Expr) -> Expr {
  log(expr)
}

///|
/// Build a symbolic Lambert W expression.
///
/// - Does: Builds `LambertW(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the principal Lambert W front door.
/// - Limits: Does not expose non-principal branch selection or numeric
///   evaluation.
pub fn lambert_w(expr : Expr) -> Expr {
  @symcore.function("LambertW", [expr])
}
