///|
/// Elementary exponential functions.

///|
pub fn exp(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(1)
  }
  @symcore.function("exp", [expr])
}

///|
pub fn exp_polar(expr : Expr) -> Expr {
  @symcore.function("exp_polar", [expr])
}

///|
pub fn log(expr : Expr) -> Expr {
  if is_one_expr(expr) {
    return int(0)
  }
  @symcore.function("log", [expr])
}

///|
pub fn ln(expr : Expr) -> Expr {
  log(expr)
}

///|
pub fn lambert_w(expr : Expr) -> Expr {
  @symcore.function("LambertW", [expr])
}
