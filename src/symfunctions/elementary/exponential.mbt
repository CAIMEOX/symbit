///|
/// Elementary exponential functions.

///|
pub fn exp(expr : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(expr) {
    return @symcore.int(1)
  }
  @symcore.function("exp", [expr])
}

///|
pub fn exp_polar(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("exp_polar", [expr])
}

///|
pub fn log(expr : @symcore.Expr) -> @symcore.Expr {
  if is_one_expr(expr) {
    return @symcore.int(0)
  }
  @symcore.function("log", [expr])
}

///|
pub fn ln(expr : @symcore.Expr) -> @symcore.Expr {
  log(expr)
}

///|
pub fn lambert_w(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("LambertW", [expr])
}
