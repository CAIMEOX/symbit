///|
/// Orthogonal polynomial special functions.

///|
pub fn legendre(n : Expr, x : Expr) -> Expr {
  @symcore.function("legendre", [n, x])
}

///|
pub fn assoc_legendre(n : Expr, m : Expr, x : Expr) -> Expr {
  @symcore.function("assoc_legendre", [n, m, x])
}

///|
pub fn hermite(n : Expr, x : Expr) -> Expr {
  @symcore.function("hermite", [n, x])
}

///|
pub fn hermite_prob(n : Expr, x : Expr) -> Expr {
  @symcore.function("hermite_prob", [n, x])
}

///|
pub fn chebyshevt(n : Expr, x : Expr) -> Expr {
  @symcore.function("chebyshevt", [n, x])
}

///|
pub fn chebyshevu(n : Expr, x : Expr) -> Expr {
  @symcore.function("chebyshevu", [n, x])
}

///|
pub fn chebyshevu_root(n : Expr, k : Expr) -> Expr {
  @symcore.function("chebyshevu_root", [n, k])
}

///|
pub fn chebyshevt_root(n : Expr, k : Expr) -> Expr {
  @symcore.function("chebyshevt_root", [n, k])
}

///|
pub fn laguerre(n : Expr, x : Expr) -> Expr {
  @symcore.function("laguerre", [n, x])
}

///|
pub fn assoc_laguerre(n : Expr, m : Expr, x : Expr) -> Expr {
  @symcore.function("assoc_laguerre", [n, m, x])
}

///|
pub fn gegenbauer(n : Expr, a : Expr, x : Expr) -> Expr {
  @symcore.function("gegenbauer", [n, a, x])
}

///|
pub fn jacobi(n : Expr, a : Expr, b : Expr, x : Expr) -> Expr {
  @symcore.function("jacobi", [n, a, b, x])
}

///|
pub fn jacobi_normalized(n : Expr, a : Expr, b : Expr, x : Expr) -> Expr {
  @symcore.function("jacobi_normalized", [n, a, b, x])
}
