///|
/// Spherical harmonics.

///|
pub fn ynm(
  n : Expr,
  m : Expr,
  theta : Expr,
  phi : Expr,
) -> Expr {
  @symcore.function("Ynm", [n, m, theta, phi])
}

///|
pub fn ynm_c(
  n : Expr,
  m : Expr,
  theta : Expr,
  phi : Expr,
) -> Expr {
  @symcore.function("Ynm_c", [n, m, theta, phi])
}

///|
pub fn znm(
  n : Expr,
  m : Expr,
  theta : Expr,
  phi : Expr,
) -> Expr {
  @symcore.function("Znm", [n, m, theta, phi])
}
