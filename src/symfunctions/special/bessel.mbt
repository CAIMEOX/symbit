///|
/// Bessel and Airy functions.
///
/// Current Limits:
/// - These front doors build symbolic Bessel/Airy-family applications.
/// - Recurrences, branch behavior, numeric evaluation, and special-order
///   simplification are not implemented here.

///|
/// Build a Bessel J expression.
///
/// - Does: Builds `besselj(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic Bessel J expression.
/// - Limits: Does not evaluate special orders or argument limits.
pub fn besselj(n : Expr, z : Expr) -> Expr {
  @symcore.function("besselj", [n, z])
}

///|
/// Build a Bessel Y expression.
///
/// - Does: Builds `bessely(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic Bessel Y expression.
/// - Limits: Does not evaluate special orders or argument limits.
pub fn bessely(n : Expr, z : Expr) -> Expr {
  @symcore.function("bessely", [n, z])
}

///|
/// Build a modified Bessel I expression.
///
/// - Does: Builds `besseli(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic modified Bessel I expression.
/// - Limits: Does not evaluate special orders or argument limits.
pub fn besseli(n : Expr, z : Expr) -> Expr {
  @symcore.function("besseli", [n, z])
}

///|
/// Build a modified Bessel K expression.
///
/// - Does: Builds `besselk(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic modified Bessel K expression.
/// - Limits: Does not evaluate special orders or argument limits.
pub fn besselk(n : Expr, z : Expr) -> Expr {
  @symcore.function("besselk", [n, z])
}

///|
/// Build a Hankel function of the first kind.
///
/// - Does: Builds `hankel1(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic Hankel function expression.
/// - Limits: Does not rewrite through Bessel J/Y or evaluate special cases.
pub fn hankel1(n : Expr, z : Expr) -> Expr {
  @symcore.function("hankel1", [n, z])
}

///|
/// Build a Hankel function of the second kind.
///
/// - Does: Builds `hankel2(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic Hankel function expression.
/// - Limits: Does not rewrite through Bessel J/Y or evaluate special cases.
pub fn hankel2(n : Expr, z : Expr) -> Expr {
  @symcore.function("hankel2", [n, z])
}

///|
/// Build a spherical Bessel J expression.
///
/// - Does: Builds `jn(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic spherical Bessel J expression.
/// - Limits: Does not rewrite through ordinary Bessel functions.
pub fn jn(n : Expr, z : Expr) -> Expr {
  @symcore.function("jn", [n, z])
}

///|
/// Build a spherical Bessel Y expression.
///
/// - Does: Builds `yn(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic spherical Bessel Y expression.
/// - Limits: Does not rewrite through ordinary Bessel functions.
pub fn yn(n : Expr, z : Expr) -> Expr {
  @symcore.function("yn", [n, z])
}

///|
/// Build a Bessel-zero request expression.
///
/// - Does: Builds `jn_zeros(n, k)`.
/// - Input: Order and count/index expressions.
/// - Returns: A symbolic Bessel-zero request expression.
/// - Limits: Does not compute numeric zeros.
pub fn jn_zeros(n : Expr, k : Expr) -> Expr {
  @symcore.function("jn_zeros", [n, k])
}

///|
/// Build a spherical Hankel function of the first kind.
///
/// - Does: Builds `hn1(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic spherical Hankel expression.
/// - Limits: Does not rewrite through spherical Bessel functions.
pub fn hn1(n : Expr, z : Expr) -> Expr {
  @symcore.function("hn1", [n, z])
}

///|
/// Build a spherical Hankel function of the second kind.
///
/// - Does: Builds `hn2(n, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic spherical Hankel expression.
/// - Limits: Does not rewrite through spherical Bessel functions.
pub fn hn2(n : Expr, z : Expr) -> Expr {
  @symcore.function("hn2", [n, z])
}

///|
/// Build an Airy Ai expression.
///
/// - Does: Builds `airyai(expr)`.
/// - Input: One symbolic argument expression.
/// - Returns: A symbolic Airy Ai expression.
/// - Limits: Does not evaluate special argument values.
pub fn airyai(expr : Expr) -> Expr {
  @symcore.function("airyai", [expr])
}

///|
/// Build an Airy Bi expression.
///
/// - Does: Builds `airybi(expr)`.
/// - Input: One symbolic argument expression.
/// - Returns: A symbolic Airy Bi expression.
/// - Limits: Does not evaluate special argument values.
pub fn airybi(expr : Expr) -> Expr {
  @symcore.function("airybi", [expr])
}

///|
/// Build a derivative of Airy Ai.
///
/// - Does: Builds `airyaiprime(expr)`.
/// - Input: One symbolic argument expression.
/// - Returns: A symbolic Airy Ai derivative expression.
/// - Limits: Does not evaluate special argument values.
pub fn airyaiprime(expr : Expr) -> Expr {
  @symcore.function("airyaiprime", [expr])
}

///|
/// Build a derivative of Airy Bi.
///
/// - Does: Builds `airybiprime(expr)`.
/// - Input: One symbolic argument expression.
/// - Returns: A symbolic Airy Bi derivative expression.
/// - Limits: Does not evaluate special argument values.
pub fn airybiprime(expr : Expr) -> Expr {
  @symcore.function("airybiprime", [expr])
}

///|
/// Build a Marcum Q expression.
///
/// - Does: Builds `marcumq(m, a, b)`.
/// - Input: Order and two argument expressions.
/// - Returns: A symbolic Marcum Q expression.
/// - Limits: Does not evaluate distributional or numeric cases.
pub fn marcumq(m : Expr, a : Expr, b : Expr) -> Expr {
  @symcore.function("marcumq", [m, a, b])
}
