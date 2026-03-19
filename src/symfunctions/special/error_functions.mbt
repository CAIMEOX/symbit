///|
/// Error and exponential integral functions.

///|
pub fn erf(expr : Expr) -> Expr {
  match num_value(expr) {
    Some(n) if n.is_zero() => int(0)
    _ => @symcore.function("erf", [expr])
  }
}

///|
pub fn erfc(expr : Expr) -> Expr {
  @symcore.function("erfc", [expr])
}

///|
pub fn erfi(expr : Expr) -> Expr {
  @symcore.function("erfi", [expr])
}

///|
pub fn erf2(a : Expr, b : Expr) -> Expr {
  @symcore.function("erf2", [a, b])
}

///|
pub fn erfinv(expr : Expr) -> Expr {
  @symcore.function("erfinv", [expr])
}

///|
pub fn erfcinv(expr : Expr) -> Expr {
  @symcore.function("erfcinv", [expr])
}

///|
pub fn erf2inv(a : Expr, b : Expr) -> Expr {
  @symcore.function("erf2inv", [a, b])
}

///|
pub fn ei(expr : Expr) -> Expr {
  @symcore.function("Ei", [expr])
}

///|
pub fn expint(n : Expr, z : Expr) -> Expr {
  @symcore.function("expint", [n, z])
}

///|
pub fn e1(expr : Expr) -> Expr {
  @symcore.function("E1", [expr])
}

///|
pub fn li(expr : Expr) -> Expr {
  @symcore.function("li", [expr])
}

///|
pub fn li_offset(expr : Expr) -> Expr {
  @symcore.function("Li", [expr])
}

///|
pub fn si(expr : Expr) -> Expr {
  @symcore.function("Si", [expr])
}

///|
pub fn ci(expr : Expr) -> Expr {
  @symcore.function("Ci", [expr])
}

///|
pub fn shi(expr : Expr) -> Expr {
  @symcore.function("Shi", [expr])
}

///|
pub fn chi(expr : Expr) -> Expr {
  @symcore.function("Chi", [expr])
}

///|
pub fn fresnels(expr : Expr) -> Expr {
  @symcore.function("fresnels", [expr])
}

///|
pub fn fresnelc(expr : Expr) -> Expr {
  @symcore.function("fresnelc", [expr])
}
