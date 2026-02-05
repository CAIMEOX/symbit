///|
/// Elementary integer-valued functions.

///|
pub fn floor(expr : @symcore.Expr) -> @symcore.Expr {
  if is_integral_expr(expr) {
    return expr
  }
  @symcore.function("floor", [expr])
}

///|
pub fn ceiling(expr : @symcore.Expr) -> @symcore.Expr {
  if is_integral_expr(expr) {
    return expr
  }
  @symcore.function("ceiling", [expr])
}

///|
pub fn frac(expr : @symcore.Expr) -> @symcore.Expr {
  if is_integral_expr(expr) {
    return @symcore.int(0)
  }
  @symcore.function("frac", [expr])
}
