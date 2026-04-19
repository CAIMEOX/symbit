///|
/// Spherical harmonics.
///
/// Current Limits:
/// - These front doors build symbolic spherical-harmonic applications.
/// - Normalization identities, conjugation rules, and explicit expansions are
///   not implemented here.

///|
/// Build a spherical harmonic expression.
///
/// - Does: Builds `Ynm(n, m, theta, phi)`.
/// - Input: Degree, order, polar angle, and azimuthal angle expressions.
/// - Returns: A symbolic spherical harmonic expression.
/// - Limits: Does not expand into trigonometric or polynomial forms.
pub fn ynm(n : Expr, m : Expr, theta : Expr, phi : Expr) -> Expr {
  @symcore.function("Ynm", [n, m, theta, phi])
}

///|
/// Build a conjugated spherical harmonic expression.
///
/// - Does: Builds `Ynm_c(n, m, theta, phi)`.
/// - Input: Degree, order, polar angle, and azimuthal angle expressions.
/// - Returns: A symbolic conjugated spherical harmonic expression.
/// - Limits: Does not simplify conjugation identities.
pub fn ynm_c(n : Expr, m : Expr, theta : Expr, phi : Expr) -> Expr {
  @symcore.function("Ynm_c", [n, m, theta, phi])
}

///|
/// Build a real spherical harmonic expression.
///
/// - Does: Builds `Znm(n, m, theta, phi)`.
/// - Input: Degree, order, polar angle, and azimuthal angle expressions.
/// - Returns: A symbolic real spherical harmonic expression.
/// - Limits: Does not expand into real trigonometric basis functions.
pub fn znm(n : Expr, m : Expr, theta : Expr, phi : Expr) -> Expr {
  @symcore.function("Znm", [n, m, theta, phi])
}
