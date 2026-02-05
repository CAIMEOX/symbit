///|
/// Bessel and Airy functions.

///|
pub fn besselj(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("besselj", [n, z])
}

///|
pub fn bessely(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("bessely", [n, z])
}

///|
pub fn besseli(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("besseli", [n, z])
}

///|
pub fn besselk(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("besselk", [n, z])
}

///|
pub fn hankel1(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("hankel1", [n, z])
}

///|
pub fn hankel2(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("hankel2", [n, z])
}

///|
pub fn jn(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("jn", [n, z])
}

///|
pub fn yn(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("yn", [n, z])
}

///|
pub fn jn_zeros(n : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("jn_zeros", [n, k])
}

///|
pub fn hn1(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("hn1", [n, z])
}

///|
pub fn hn2(n : @symcore.Expr, z : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("hn2", [n, z])
}

///|
pub fn airyai(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("airyai", [expr])
}

///|
pub fn airybi(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("airybi", [expr])
}

///|
pub fn airyaiprime(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("airyaiprime", [expr])
}

///|
pub fn airybiprime(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("airybiprime", [expr])
}

///|
pub fn marcumq(
  m : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("marcumq", [m, a, b])
}
