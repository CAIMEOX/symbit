///|
/// Elementary integer-valued functions.

///|
pub fn floor(expr : Expr) -> Expr {
  if is_integral_expr(expr) {
    return expr
  }
  @symcore.function("floor", [expr])
}

///|
pub fn ceiling(expr : Expr) -> Expr {
  if is_integral_expr(expr) {
    return expr
  }
  @symcore.function("ceiling", [expr])
}

///|
pub fn frac(expr : Expr) -> Expr {
  if is_integral_expr(expr) {
    return int(0)
  }
  @symcore.function("frac", [expr])
}
