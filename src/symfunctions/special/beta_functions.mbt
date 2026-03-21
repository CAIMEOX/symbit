///|
/// Beta functions.

///|
pub fn beta(x : Expr, y : Expr) -> Expr {
  @symcore.function("beta", [x, y])
}

///|
pub fn betainc(a : Expr, b : Expr, x1 : Expr, x2 : Expr) -> Expr {
  @symcore.function("betainc", [a, b, x1, x2])
}

///|
pub fn betainc_regularized(a : Expr, b : Expr, x1 : Expr, x2 : Expr) -> Expr {
  @symcore.function("betainc_regularized", [a, b, x1, x2])
}
