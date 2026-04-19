///|
/// Elliptic integrals.
///
/// Current Limits:
/// - These front doors build symbolic elliptic-integral applications.
/// - Numeric evaluation, singularity checks, and parameter normalization are not
///   implemented here.

///|
/// Build a complete elliptic integral of the first kind.
///
/// - Does: Builds `elliptic_k(m)`.
/// - Input: One symbolic parameter.
/// - Returns: A symbolic complete elliptic integral expression.
/// - Limits: Does not evaluate singular or special parameter values.
pub fn elliptic_k(m : Expr) -> Expr {
  @symcore.function("elliptic_k", [m])
}

///|
/// Build an incomplete elliptic integral of the first kind.
///
/// - Does: Builds `elliptic_f(phi, m)`.
/// - Input: Amplitude and parameter expressions.
/// - Returns: A symbolic incomplete elliptic integral expression.
/// - Limits: Does not normalize amplitudes or evaluate special cases.
pub fn elliptic_f(phi : Expr, m : Expr) -> Expr {
  @symcore.function("elliptic_f", [phi, m])
}

///|
/// Build an elliptic integral of the second kind.
///
/// - Does: Builds `elliptic_e(phi, m)`.
/// - Input: Amplitude and parameter expressions.
/// - Returns: A symbolic elliptic integral expression.
/// - Limits: Does not normalize amplitudes or evaluate special cases.
pub fn elliptic_e(phi : Expr, m : Expr) -> Expr {
  @symcore.function("elliptic_e", [phi, m])
}

///|
/// Build an elliptic integral of the third kind.
///
/// - Does: Builds `elliptic_pi(n, phi, m)`.
/// - Input: Characteristic, amplitude, and parameter expressions.
/// - Returns: A symbolic elliptic integral expression.
/// - Limits: Does not check poles or evaluate special cases.
pub fn elliptic_pi(n : Expr, phi : Expr, m : Expr) -> Expr {
  @symcore.function("elliptic_pi", [n, phi, m])
}
