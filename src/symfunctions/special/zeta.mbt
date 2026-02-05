///|
/// Zeta and polylogarithmic special functions.

///|
pub fn zeta(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("zeta", [expr])
}

///|
pub fn dirichlet_eta(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("dirichlet_eta", [expr])
}

///|
pub fn lerchphi(
  z : @symcore.Expr,
  s : @symcore.Expr,
  a : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("lerchphi", [z, s, a])
}

///|
pub fn polylog(s : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("polylog", [s, z])
}

///|
pub fn stieltjes(n : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("stieltjes", [n])
}

///|
pub fn riemann_xi(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("riemann_xi", [expr])
}
