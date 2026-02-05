///|
/// Elliptic integrals.

///|
pub fn elliptic_k(m : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("elliptic_k", [m])
}

///|
pub fn elliptic_f(phi : @symcore.Expr, m : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("elliptic_f", [phi, m])
}

///|
pub fn elliptic_e(phi : @symcore.Expr, m : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("elliptic_e", [phi, m])
}

///|
pub fn elliptic_pi(
  n : @symcore.Expr,
  phi : @symcore.Expr,
  m : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("elliptic_pi", [n, phi, m])
}
