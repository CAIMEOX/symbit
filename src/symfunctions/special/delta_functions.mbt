///|
/// Delta and step functions.
///
/// Current Limits:
/// - These front doors build symbolic distribution applications.
/// - Distributional identities, derivative orders, and convention-sensitive
///   values are not evaluated here.

///|
/// Build a Dirac delta expression.
///
/// - Does: Builds `DiracDelta(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Dirac delta expression.
/// - Limits: Does not expand roots, derivatives, or distributional products.
pub fn dirac_delta(expr : Expr) -> Expr {
  @symcore.function("DiracDelta", [expr])
}

///|
/// Build a Heaviside step expression.
///
/// - Does: Builds `Heaviside(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Heaviside expression.
/// - Limits: Does not evaluate the value at zero or simplify sign-known input.
pub fn heaviside(expr : Expr) -> Expr {
  @symcore.function("Heaviside", [expr])
}
