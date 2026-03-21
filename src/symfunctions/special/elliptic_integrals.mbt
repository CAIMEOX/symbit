///|
/// Elliptic integrals.

///|
pub fn elliptic_k(m : Expr) -> Expr {
  @symcore.function("elliptic_k", [m])
}

///|
pub fn elliptic_f(phi : Expr, m : Expr) -> Expr {
  @symcore.function("elliptic_f", [phi, m])
}

///|
pub fn elliptic_e(phi : Expr, m : Expr) -> Expr {
  @symcore.function("elliptic_e", [phi, m])
}

///|
pub fn elliptic_pi(n : Expr, phi : Expr, m : Expr) -> Expr {
  @symcore.function("elliptic_pi", [n, phi, m])
}
