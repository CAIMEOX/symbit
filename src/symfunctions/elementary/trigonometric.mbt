///|
/// Elementary trigonometric functions.

///|
pub fn sin(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(0)
  }
  @symcore.function("sin", [expr])
}

///|
pub fn cos(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(1)
  }
  @symcore.function("cos", [expr])
}

///|
pub fn tan(expr : Expr) -> Expr {
  if is_zero_expr(expr) {
    return int(0)
  }
  @symcore.function("tan", [expr])
}

///|
pub fn sec(expr : Expr) -> Expr {
  @symcore.function("sec", [expr])
}

///|
pub fn csc(expr : Expr) -> Expr {
  @symcore.function("csc", [expr])
}

///|
pub fn cot(expr : Expr) -> Expr {
  @symcore.function("cot", [expr])
}

///|
pub fn sinc(expr : Expr) -> Expr {
  @symcore.function("sinc", [expr])
}

///|
pub fn asin(expr : Expr) -> Expr {
  @symcore.function("asin", [expr])
}

///|
pub fn acos(expr : Expr) -> Expr {
  @symcore.function("acos", [expr])
}

///|
pub fn atan(expr : Expr) -> Expr {
  @symcore.function("atan", [expr])
}

///|
pub fn asec(expr : Expr) -> Expr {
  @symcore.function("asec", [expr])
}

///|
pub fn acsc(expr : Expr) -> Expr {
  @symcore.function("acsc", [expr])
}

///|
pub fn acot(expr : Expr) -> Expr {
  @symcore.function("acot", [expr])
}

///|
pub fn atan2(y : Expr, x : Expr) -> Expr {
  @symcore.function("atan2", [y, x])
}
