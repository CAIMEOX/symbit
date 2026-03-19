///|
/// Bessel and Airy functions.

///|
pub fn besselj(n : Expr, z : Expr) -> Expr {
  @symcore.function("besselj", [n, z])
}

///|
pub fn bessely(n : Expr, z : Expr) -> Expr {
  @symcore.function("bessely", [n, z])
}

///|
pub fn besseli(n : Expr, z : Expr) -> Expr {
  @symcore.function("besseli", [n, z])
}

///|
pub fn besselk(n : Expr, z : Expr) -> Expr {
  @symcore.function("besselk", [n, z])
}

///|
pub fn hankel1(n : Expr, z : Expr) -> Expr {
  @symcore.function("hankel1", [n, z])
}

///|
pub fn hankel2(n : Expr, z : Expr) -> Expr {
  @symcore.function("hankel2", [n, z])
}

///|
pub fn jn(n : Expr, z : Expr) -> Expr {
  @symcore.function("jn", [n, z])
}

///|
pub fn yn(n : Expr, z : Expr) -> Expr {
  @symcore.function("yn", [n, z])
}

///|
pub fn jn_zeros(n : Expr, k : Expr) -> Expr {
  @symcore.function("jn_zeros", [n, k])
}

///|
pub fn hn1(n : Expr, z : Expr) -> Expr {
  @symcore.function("hn1", [n, z])
}

///|
pub fn hn2(n : Expr, z : Expr) -> Expr {
  @symcore.function("hn2", [n, z])
}

///|
pub fn airyai(expr : Expr) -> Expr {
  @symcore.function("airyai", [expr])
}

///|
pub fn airybi(expr : Expr) -> Expr {
  @symcore.function("airybi", [expr])
}

///|
pub fn airyaiprime(expr : Expr) -> Expr {
  @symcore.function("airyaiprime", [expr])
}

///|
pub fn airybiprime(expr : Expr) -> Expr {
  @symcore.function("airybiprime", [expr])
}

///|
pub fn marcumq(
  m : Expr,
  a : Expr,
  b : Expr,
) -> Expr {
  @symcore.function("marcumq", [m, a, b])
}
