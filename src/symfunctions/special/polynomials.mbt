///|
/// Orthogonal polynomial special functions.

///|
pub fn legendre(n : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("legendre", [n, x])
}

///|
pub fn assoc_legendre(
  n : @symcore.Expr,
  m : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("assoc_legendre", [n, m, x])
}

///|
pub fn hermite(n : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("hermite", [n, x])
}

///|
pub fn hermite_prob(n : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("hermite_prob", [n, x])
}

///|
pub fn chebyshevt(n : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("chebyshevt", [n, x])
}

///|
pub fn chebyshevu(n : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("chebyshevu", [n, x])
}

///|
pub fn chebyshevu_root(n : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("chebyshevu_root", [n, k])
}

///|
pub fn chebyshevt_root(n : @symcore.Expr, k : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("chebyshevt_root", [n, k])
}

///|
pub fn laguerre(n : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("laguerre", [n, x])
}

///|
pub fn assoc_laguerre(
  n : @symcore.Expr,
  m : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("assoc_laguerre", [n, m, x])
}

///|
pub fn gegenbauer(
  n : @symcore.Expr,
  a : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("gegenbauer", [n, a, x])
}

///|
pub fn jacobi(
  n : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("jacobi", [n, a, b, x])
}

///|
pub fn jacobi_normalized(
  n : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("jacobi_normalized", [n, a, b, x])
}
