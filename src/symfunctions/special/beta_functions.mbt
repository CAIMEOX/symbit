///|
/// Beta functions.

///|
pub fn beta(x : @symcore.Expr, y : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("beta", [x, y])
}

///|
pub fn betainc(
  a : @symcore.Expr,
  b : @symcore.Expr,
  x1 : @symcore.Expr,
  x2 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("betainc", [a, b, x1, x2])
}

///|
pub fn betainc_regularized(
  a : @symcore.Expr,
  b : @symcore.Expr,
  x1 : @symcore.Expr,
  x2 : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("betainc_regularized", [a, b, x1, x2])
}
