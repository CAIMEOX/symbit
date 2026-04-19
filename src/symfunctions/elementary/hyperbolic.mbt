///|
/// Elementary hyperbolic functions.
///
/// Current Limits:
/// - The front doors build symbolic applications.
/// - General hyperbolic identities, inverse-branch rules, and numeric
///   evaluation are not complete.

///|
/// Build a symbolic hyperbolic sine expression.
///
/// - Does: Builds `sinh(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the hyperbolic sine of the input.
/// - Limits: Does not simplify parity, exponential rewrites, or numeric cases.
pub fn sinh(expr : Expr) -> Expr {
  @symcore.function("sinh", [expr])
}

///|
/// Build a symbolic hyperbolic cosine expression.
///
/// - Does: Builds `cosh(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the hyperbolic cosine of the input.
/// - Limits: Does not simplify parity, exponential rewrites, or numeric cases.
pub fn cosh(expr : Expr) -> Expr {
  @symcore.function("cosh", [expr])
}

///|
/// Build a symbolic hyperbolic tangent expression.
///
/// - Does: Builds `tanh(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the hyperbolic tangent of the input.
/// - Limits: Does not simplify exponential rewrites, poles, or numeric cases.
pub fn tanh(expr : Expr) -> Expr {
  @symcore.function("tanh", [expr])
}

///|
/// Build a symbolic hyperbolic cotangent expression.
///
/// - Does: Builds `coth(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the hyperbolic cotangent of the input.
/// - Limits: Does not simplify reciprocal forms, poles, or numeric cases.
pub fn coth(expr : Expr) -> Expr {
  @symcore.function("coth", [expr])
}

///|
/// Build a symbolic hyperbolic secant expression.
///
/// - Does: Builds `sech(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the hyperbolic secant of the input.
/// - Limits: Does not simplify reciprocal forms or numeric cases.
pub fn sech(expr : Expr) -> Expr {
  @symcore.function("sech", [expr])
}

///|
/// Build a symbolic hyperbolic cosecant expression.
///
/// - Does: Builds `csch(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the hyperbolic cosecant of the input.
/// - Limits: Does not simplify reciprocal forms, poles, or numeric cases.
pub fn csch(expr : Expr) -> Expr {
  @symcore.function("csch", [expr])
}

///|
/// Build a symbolic inverse hyperbolic sine expression.
///
/// - Does: Builds `asinh(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse hyperbolic sine.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn asinh(expr : Expr) -> Expr {
  @symcore.function("asinh", [expr])
}

///|
/// Build a symbolic inverse hyperbolic cosine expression.
///
/// - Does: Builds `acosh(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse hyperbolic cosine.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn acosh(expr : Expr) -> Expr {
  @symcore.function("acosh", [expr])
}

///|
/// Build a symbolic inverse hyperbolic tangent expression.
///
/// - Does: Builds `atanh(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse hyperbolic tangent.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn atanh(expr : Expr) -> Expr {
  @symcore.function("atanh", [expr])
}

///|
/// Build a symbolic inverse hyperbolic cotangent expression.
///
/// - Does: Builds `acoth(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse hyperbolic cotangent.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn acoth(expr : Expr) -> Expr {
  @symcore.function("acoth", [expr])
}

///|
/// Build a symbolic inverse hyperbolic secant expression.
///
/// - Does: Builds `asech(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse hyperbolic secant.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn asech(expr : Expr) -> Expr {
  @symcore.function("asech", [expr])
}

///|
/// Build a symbolic inverse hyperbolic cosecant expression.
///
/// - Does: Builds `acsch(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse hyperbolic cosecant.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn acsch(expr : Expr) -> Expr {
  @symcore.function("acsch", [expr])
}
