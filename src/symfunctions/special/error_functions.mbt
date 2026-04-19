///|
/// Error and exponential integral functions.
///
/// Current Limits:
/// - `erf(0)` is simplified locally.
/// - Other front doors build symbolic special-function applications.
/// - Numeric evaluation, branch cuts, series, and asymptotic rewrites are not
///   implemented here.

///|
/// Build or evaluate an error-function expression.
///
/// - Does: Returns `0` for exact zero input, otherwise builds `erf(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic or exact error-function expression.
/// - Limits: Does not evaluate infinities, sign identities, or numeric values.
pub fn erf(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(n) if n.is_zero() => int(0)
    _ => @symcore.function("erf", [expr])
  }
}

///|
/// Build a complementary error-function expression.
///
/// - Does: Builds `erfc(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic complementary error-function expression.
/// - Limits: Does not evaluate special argument values.
pub fn erfc(expr : Expr) -> Expr {
  @symcore.function("erfc", [expr])
}

///|
/// Build an imaginary error-function expression.
///
/// - Does: Builds `erfi(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic imaginary error-function expression.
/// - Limits: Does not evaluate special argument values.
pub fn erfi(expr : Expr) -> Expr {
  @symcore.function("erfi", [expr])
}

///|
/// Build a two-argument error-function expression.
///
/// - Does: Builds `erf2(a, b)`.
/// - Input: Lower and upper argument expressions.
/// - Returns: A symbolic two-argument error-function expression.
/// - Limits: Does not reduce when endpoints are equal or special.
pub fn erf2(a : Expr, b : Expr) -> Expr {
  @symcore.function("erf2", [a, b])
}

///|
/// Build an inverse error-function expression.
///
/// - Does: Builds `erfinv(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic inverse error-function expression.
/// - Limits: Does not evaluate special argument values.
pub fn erfinv(expr : Expr) -> Expr {
  @symcore.function("erfinv", [expr])
}

///|
/// Build an inverse complementary error-function expression.
///
/// - Does: Builds `erfcinv(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic inverse complementary error-function expression.
/// - Limits: Does not evaluate special argument values.
pub fn erfcinv(expr : Expr) -> Expr {
  @symcore.function("erfcinv", [expr])
}

///|
/// Build an inverse two-argument error-function expression.
///
/// - Does: Builds `erf2inv(a, b)`.
/// - Input: Two symbolic endpoint/value expressions.
/// - Returns: A symbolic inverse two-argument error-function expression.
/// - Limits: Does not evaluate special endpoint cases.
pub fn erf2inv(a : Expr, b : Expr) -> Expr {
  @symcore.function("erf2inv", [a, b])
}

///|
/// Build an exponential integral expression.
///
/// - Does: Builds `Ei(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic exponential integral expression.
/// - Limits: Does not evaluate branch cuts or special values.
pub fn ei(expr : Expr) -> Expr {
  @symcore.function("Ei", [expr])
}

///|
/// Build a generalized exponential integral expression.
///
/// - Does: Builds `expint(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic generalized exponential integral expression.
/// - Limits: Does not simplify order-specific cases.
pub fn expint(n : Expr, z : Expr) -> Expr {
  @symcore.function("expint", [n, z])
}

///|
/// Build an E1 exponential integral expression.
///
/// - Does: Builds `E1(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic E1 expression.
/// - Limits: Does not rewrite through `Ei` or evaluate branch cuts.
pub fn e1(expr : Expr) -> Expr {
  @symcore.function("E1", [expr])
}

///|
/// Build a logarithmic integral expression.
///
/// - Does: Builds `li(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic logarithmic integral expression.
/// - Limits: Does not evaluate singular or offset conventions.
pub fn li(expr : Expr) -> Expr {
  @symcore.function("li", [expr])
}

///|
/// Build an offset logarithmic integral expression.
///
/// - Does: Builds `Li(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic offset logarithmic integral expression.
/// - Limits: Does not evaluate special values.
pub fn li_offset(expr : Expr) -> Expr {
  @symcore.function("Li", [expr])
}

///|
/// Build a sine integral expression.
///
/// - Does: Builds `Si(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic sine integral expression.
/// - Limits: Does not evaluate special values or series.
pub fn si(expr : Expr) -> Expr {
  @symcore.function("Si", [expr])
}

///|
/// Build a cosine integral expression.
///
/// - Does: Builds `Ci(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic cosine integral expression.
/// - Limits: Does not evaluate special values or branch cuts.
pub fn ci(expr : Expr) -> Expr {
  @symcore.function("Ci", [expr])
}

///|
/// Build a hyperbolic sine integral expression.
///
/// - Does: Builds `Shi(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic hyperbolic sine integral expression.
/// - Limits: Does not evaluate special values or series.
pub fn shi(expr : Expr) -> Expr {
  @symcore.function("Shi", [expr])
}

///|
/// Build a hyperbolic cosine integral expression.
///
/// - Does: Builds `Chi(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic hyperbolic cosine integral expression.
/// - Limits: Does not evaluate special values or branch cuts.
pub fn chi(expr : Expr) -> Expr {
  @symcore.function("Chi", [expr])
}

///|
/// Build a Fresnel S expression.
///
/// - Does: Builds `fresnels(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Fresnel S expression.
/// - Limits: Does not evaluate special values or asymptotics.
pub fn fresnels(expr : Expr) -> Expr {
  @symcore.function("fresnels", [expr])
}

///|
/// Build a Fresnel C expression.
///
/// - Does: Builds `fresnelc(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Fresnel C expression.
/// - Limits: Does not evaluate special values or asymptotics.
pub fn fresnelc(expr : Expr) -> Expr {
  @symcore.function("fresnelc", [expr])
}
