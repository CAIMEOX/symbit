///|
/// SingularityFunction.
///
/// Current Limits:
/// - The front door builds a symbolic singularity-function application.
/// - Rewrites to piecewise, delta, or Heaviside forms are not implemented here.

///|
/// Build a singularity-function expression.
///
/// - Does: Builds `SingularityFunction(expr, a, n)`.
/// - Input: Variable expression, offset expression, and exponent/order
///   expression.
/// - Returns: A symbolic singularity-function expression.
/// - Limits: Does not expand, differentiate, or rewrite the singularity
///   function.
pub fn singularity_function(expr : Expr, a : Expr, n : Expr) -> Expr {
  @symcore.function("SingularityFunction", [expr, a, n])
}
