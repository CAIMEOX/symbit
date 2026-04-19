///|
/// Elementary trigonometric functions.
///
/// Current Limits:
/// - The front doors primarily build symbolic applications.
/// - Only a small set of exact zero-argument simplifications is performed.
/// - General trigonometric identities, branch analysis, and periodic
///   canonicalization are not complete.

///|
/// Build a symbolic sine expression.
///
/// - Does: Returns `0` for exact zero input, otherwise builds `sin(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the sine of the input.
/// - Limits: Does not simplify general angle identities or branch-sensitive
///   forms.
pub fn sin(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(0)
  }
  @symcore.function("sin", [expr])
}

///|
/// Build a symbolic cosine expression.
///
/// - Does: Returns `1` for exact zero input, otherwise builds `cos(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the cosine of the input.
/// - Limits: Does not simplify general angle identities or branch-sensitive
///   forms.
pub fn cos(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(1)
  }
  @symcore.function("cos", [expr])
}

///|
/// Build a symbolic tangent expression.
///
/// - Does: Returns `0` for exact zero input, otherwise builds `tan(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the tangent of the input.
/// - Limits: Does not simplify general angle identities, poles, or periodic
///   forms.
pub fn tan(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(0)
  }
  @symcore.function("tan", [expr])
}

///|
/// Build a symbolic secant expression.
///
/// - Does: Builds `sec(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the secant of the input.
/// - Limits: Does not simplify reciprocal cosine forms or pole behavior.
pub fn sec(expr : Expr) -> Expr {
  @symcore.function("sec", [expr])
}

///|
/// Build a symbolic cosecant expression.
///
/// - Does: Builds `csc(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the cosecant of the input.
/// - Limits: Does not simplify reciprocal sine forms or pole behavior.
pub fn csc(expr : Expr) -> Expr {
  @symcore.function("csc", [expr])
}

///|
/// Build a symbolic cotangent expression.
///
/// - Does: Builds `cot(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the cotangent of the input.
/// - Limits: Does not simplify reciprocal tangent forms or pole behavior.
pub fn cot(expr : Expr) -> Expr {
  @symcore.function("cot", [expr])
}

///|
/// Build a symbolic normalized sinc expression.
///
/// - Does: Builds `sinc(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the normalized sinc of the input.
/// - Limits: Does not currently evaluate the removable value at zero.
pub fn sinc(expr : Expr) -> Expr {
  @symcore.function("sinc", [expr])
}

///|
/// Build a symbolic inverse sine expression.
///
/// - Does: Builds `asin(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse sine of the input.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn asin(expr : Expr) -> Expr {
  @symcore.function("asin", [expr])
}

///|
/// Build a symbolic inverse cosine expression.
///
/// - Does: Builds `acos(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse cosine of the input.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn acos(expr : Expr) -> Expr {
  @symcore.function("acos", [expr])
}

///|
/// Build a symbolic inverse tangent expression.
///
/// - Does: Builds `atan(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse tangent of the input.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn atan(expr : Expr) -> Expr {
  @symcore.function("atan", [expr])
}

///|
/// Build a symbolic inverse secant expression.
///
/// - Does: Builds `asec(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse secant of the input.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn asec(expr : Expr) -> Expr {
  @symcore.function("asec", [expr])
}

///|
/// Build a symbolic inverse cosecant expression.
///
/// - Does: Builds `acsc(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse cosecant of the input.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn acsc(expr : Expr) -> Expr {
  @symcore.function("acsc", [expr])
}

///|
/// Build a symbolic inverse cotangent expression.
///
/// - Does: Builds `acot(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic expression for the inverse cotangent of the input.
/// - Limits: Does not perform branch-cut simplification or numeric evaluation.
pub fn acot(expr : Expr) -> Expr {
  @symcore.function("acot", [expr])
}

///|
/// Build a symbolic two-argument arctangent expression.
///
/// - Does: Builds `atan2(y, x)`.
/// - Input: Two symbolic expressions representing the numerator-like and
///   denominator-like coordinates.
/// - Returns: A symbolic expression for the quadrant-aware arctangent.
/// - Limits: Does not currently resolve quadrant cases from assumptions.
pub fn atan2(y : Expr, x : Expr) -> Expr {
  @symcore.function("atan2", [y, x])
}
