///|
/// Beta functions.
///
/// Current Limits:
/// - These front doors build symbolic beta-family applications.
/// - Numeric evaluation, convergence checks, and analytic continuation are not
///   implemented here.

///|
/// Build a beta-function expression.
///
/// - Does: Builds `beta(x, y)`.
/// - Input: Two symbolic expressions.
/// - Returns: A symbolic beta-function expression.
/// - Limits: Does not simplify through gamma functions or evaluate special
///   numeric cases.
pub fn beta(x : Expr, y : Expr) -> Expr {
  @symcore.function("beta", [x, y])
}

///|
/// Build an incomplete beta-function expression.
///
/// - Does: Builds `betainc(a, b, x1, x2)`.
/// - Input: Two shape expressions and two interval endpoint expressions.
/// - Returns: A symbolic incomplete beta-function expression.
/// - Limits: Does not validate endpoint ordering or evaluate numeric cases.
pub fn betainc(a : Expr, b : Expr, x1 : Expr, x2 : Expr) -> Expr {
  @symcore.function("betainc", [a, b, x1, x2])
}

///|
/// Build a regularized incomplete beta-function expression.
///
/// - Does: Builds `betainc_regularized(a, b, x1, x2)`.
/// - Input: Two shape expressions and two interval endpoint expressions.
/// - Returns: A symbolic regularized incomplete beta-function expression.
/// - Limits: Does not validate endpoint ordering or evaluate numeric cases.
pub fn betainc_regularized(a : Expr, b : Expr, x1 : Expr, x2 : Expr) -> Expr {
  @symcore.function("betainc_regularized", [a, b, x1, x2])
}
