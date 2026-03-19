///|
/// Zeta and polylogarithmic special functions.

///|
pub fn zeta(expr : Expr) -> Expr {
  @symcore.function("zeta", [expr])
}

///|
pub fn dirichlet_eta(expr : Expr) -> Expr {
  @symcore.function("dirichlet_eta", [expr])
}

///|
pub fn lerchphi(
  z : Expr,
  s : Expr,
  a : Expr,
) -> Expr {
  @symcore.function("lerchphi", [z, s, a])
}

///|
pub fn polylog(s : Expr, z : Expr) -> Expr {
  @symcore.function("polylog", [s, z])
}

///|
pub fn stieltjes(n : Expr) -> Expr {
  @symcore.function("stieltjes", [n])
}

///|
pub fn riemann_xi(expr : Expr) -> Expr {
  @symcore.function("riemann_xi", [expr])
}
