///|
/// Error and exponential integral functions.

///|
pub fn erf(expr : @symcore.Expr) -> @symcore.Expr {
  match num_value(expr) {
    Some(n) if n.is_zero() => @symcore.int(0)
    _ => @symcore.function("erf", [expr])
  }
}

///|
pub fn erfc(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("erfc", [expr])
}

///|
pub fn erfi(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("erfi", [expr])
}

///|
pub fn erf2(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("erf2", [a, b])
}

///|
pub fn erfinv(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("erfinv", [expr])
}

///|
pub fn erfcinv(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("erfcinv", [expr])
}

///|
pub fn erf2inv(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("erf2inv", [a, b])
}

///|
pub fn ei(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Ei", [expr])
}

///|
pub fn expint(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("expint", [n, z])
}

///|
pub fn e1(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("E1", [expr])
}

///|
pub fn li(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("li", [expr])
}

///|
pub fn li_offset(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Li", [expr])
}

///|
pub fn si(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Si", [expr])
}

///|
pub fn ci(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Ci", [expr])
}

///|
pub fn shi(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Shi", [expr])
}

///|
pub fn chi(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Chi", [expr])
}

///|
pub fn fresnels(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("fresnels", [expr])
}

///|
pub fn fresnelc(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("fresnelc", [expr])
}
