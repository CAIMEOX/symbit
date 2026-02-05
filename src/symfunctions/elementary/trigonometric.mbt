///|
/// Elementary trigonometric functions.

///|
pub fn sin(expr : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(expr) {
    return @symcore.int(0)
  }
  @symcore.function("sin", [expr])
}

///|
pub fn cos(expr : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(expr) {
    return @symcore.int(1)
  }
  @symcore.function("cos", [expr])
}

///|
pub fn tan(expr : @symcore.Expr) -> @symcore.Expr {
  if is_zero_expr(expr) {
    return @symcore.int(0)
  }
  @symcore.function("tan", [expr])
}

///|
pub fn sec(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("sec", [expr])
}

///|
pub fn csc(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("csc", [expr])
}

///|
pub fn cot(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("cot", [expr])
}

///|
pub fn sinc(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("sinc", [expr])
}

///|
pub fn asin(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("asin", [expr])
}

///|
pub fn acos(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("acos", [expr])
}

///|
pub fn atan(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("atan", [expr])
}

///|
pub fn asec(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("asec", [expr])
}

///|
pub fn acsc(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("acsc", [expr])
}

///|
pub fn acot(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("acot", [expr])
}

///|
pub fn atan2(y : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("atan2", [y, x])
}
