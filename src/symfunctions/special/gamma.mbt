///|
/// Gamma and related special functions.
///
/// Current Limits:
/// - Positive integer `gamma(n)` is evaluated through `(n - 1)!`.
/// - Other gamma-family front doors are symbolic.
/// - Poles, derivatives, expansions, and branch-sensitive simplifications are
///   not complete.

///|
/// Build or evaluate a gamma-function expression.
///
/// - Does: Evaluates positive integer inputs as factorials, otherwise builds
///   `gamma(expr)`.
/// - Input: One symbolic expression.
/// - Returns: An exact integer expression or symbolic gamma expression.
/// - Limits: Non-positive integers, rationals, and symbolic arguments are not
///   evaluated.
pub fn gamma(expr : Expr) -> Expr {
  match int_value(expr) {
    Some(bi) => {
      let n = bi.to_int()
      if n > 0 {
        return expr_from_bigint(factorial_bigint(n - 1))
      }
      @symcore.function("gamma", [expr])
    }
    None => @symcore.function("gamma", [expr])
  }
}

///|
/// Build a lower incomplete gamma expression.
///
/// - Does: Builds `lowergamma(a, z)`.
/// - Input: Shape and argument expressions.
/// - Returns: A symbolic lower incomplete gamma expression.
/// - Limits: Does not evaluate special parameters or rewrite to gamma/exp.
pub fn lowergamma(a : Expr, z : Expr) -> Expr {
  @symcore.function("lowergamma", [a, z])
}

///|
/// Build an upper incomplete gamma expression.
///
/// - Does: Builds `uppergamma(a, z)`.
/// - Input: Shape and argument expressions.
/// - Returns: A symbolic upper incomplete gamma expression.
/// - Limits: Does not evaluate special parameters or rewrite to gamma/exp.
pub fn uppergamma(a : Expr, z : Expr) -> Expr {
  @symcore.function("uppergamma", [a, z])
}

///|
/// Build a polygamma expression.
///
/// - Does: Builds `polygamma(n, z)`.
/// - Input: Derivative order and argument expressions.
/// - Returns: A symbolic polygamma expression.
/// - Limits: Does not evaluate digamma/trigamma aliases or special values.
pub fn polygamma(n : Expr, z : Expr) -> Expr {
  @symcore.function("polygamma", [n, z])
}

///|
/// Build a logarithmic gamma expression.
///
/// - Does: Builds `loggamma(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic log-gamma expression.
/// - Limits: Does not evaluate integer cases or branch-sensitive logarithms.
pub fn loggamma(expr : Expr) -> Expr {
  @symcore.function("loggamma", [expr])
}

///|
/// Build a digamma expression.
///
/// - Does: Builds `digamma(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic digamma expression.
/// - Limits: Does not evaluate harmonic-number identities or special values.
pub fn digamma(expr : Expr) -> Expr {
  @symcore.function("digamma", [expr])
}

///|
/// Build a trigamma expression.
///
/// - Does: Builds `trigamma(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic trigamma expression.
/// - Limits: Does not rewrite to `polygamma(1, expr)` or evaluate values.
pub fn trigamma(expr : Expr) -> Expr {
  @symcore.function("trigamma", [expr])
}

///|
/// Build a multivariate gamma expression.
///
/// - Does: Builds `multigamma(a, p)`.
/// - Input: Shape and dimension/order expressions.
/// - Returns: A symbolic multivariate gamma expression.
/// - Limits: Does not expand into ordinary gamma products or validate dimension.
pub fn multigamma(a : Expr, p : Expr) -> Expr {
  @symcore.function("multigamma", [a, p])
}
