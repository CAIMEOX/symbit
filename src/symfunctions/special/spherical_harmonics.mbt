///|
/// Spherical harmonics.

///|
pub fn ynm(
  n : @symcore.Expr,
  m : @symcore.Expr,
  theta : @symcore.Expr,
  phi : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Ynm", [n, m, theta, phi])
}

///|
pub fn ynm_c(
  n : @symcore.Expr,
  m : @symcore.Expr,
  theta : @symcore.Expr,
  phi : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Ynm_c", [n, m, theta, phi])
}

///|
pub fn znm(
  n : @symcore.Expr,
  m : @symcore.Expr,
  theta : @symcore.Expr,
  phi : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Znm", [n, m, theta, phi])
}
