///|
/// Orthogonal polynomial special functions.
///
/// Current Limits:
/// - These front doors build symbolic orthogonal-polynomial applications.
/// - Explicit polynomial expansion, recurrence simplification, roots, and
///   normalization checks are not implemented here.

///|
/// Build a Legendre polynomial expression.
///
/// - Does: Builds `legendre(n, x)`.
/// - Input: Degree and argument expressions.
/// - Returns: A symbolic Legendre polynomial expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn legendre(n : Expr, x : Expr) -> Expr {
  @symcore.function("legendre", [n, x])
}

///|
/// Build an associated Legendre polynomial expression.
///
/// - Does: Builds `assoc_legendre(n, m, x)`.
/// - Input: Degree, order, and argument expressions.
/// - Returns: A symbolic associated Legendre expression.
/// - Limits: Does not expand integer-degree/order polynomials.
pub fn assoc_legendre(n : Expr, m : Expr, x : Expr) -> Expr {
  @symcore.function("assoc_legendre", [n, m, x])
}

///|
/// Build a physicists' Hermite polynomial expression.
///
/// - Does: Builds `hermite(n, x)`.
/// - Input: Degree and argument expressions.
/// - Returns: A symbolic Hermite polynomial expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn hermite(n : Expr, x : Expr) -> Expr {
  @symcore.function("hermite", [n, x])
}

///|
/// Build a probabilists' Hermite polynomial expression.
///
/// - Does: Builds `hermite_prob(n, x)`.
/// - Input: Degree and argument expressions.
/// - Returns: A symbolic probabilists' Hermite polynomial expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn hermite_prob(n : Expr, x : Expr) -> Expr {
  @symcore.function("hermite_prob", [n, x])
}

///|
/// Build a Chebyshev T polynomial expression.
///
/// - Does: Builds `chebyshevt(n, x)`.
/// - Input: Degree and argument expressions.
/// - Returns: A symbolic Chebyshev T expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn chebyshevt(n : Expr, x : Expr) -> Expr {
  @symcore.function("chebyshevt", [n, x])
}

///|
/// Build a Chebyshev U polynomial expression.
///
/// - Does: Builds `chebyshevu(n, x)`.
/// - Input: Degree and argument expressions.
/// - Returns: A symbolic Chebyshev U expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn chebyshevu(n : Expr, x : Expr) -> Expr {
  @symcore.function("chebyshevu", [n, x])
}

///|
/// Build a Chebyshev U root expression.
///
/// - Does: Builds `chebyshevu_root(n, k)`.
/// - Input: Degree and root-index expressions.
/// - Returns: A symbolic Chebyshev U root expression.
/// - Limits: Does not compute numeric or exact trigonometric roots.
pub fn chebyshevu_root(n : Expr, k : Expr) -> Expr {
  @symcore.function("chebyshevu_root", [n, k])
}

///|
/// Build a Chebyshev T root expression.
///
/// - Does: Builds `chebyshevt_root(n, k)`.
/// - Input: Degree and root-index expressions.
/// - Returns: A symbolic Chebyshev T root expression.
/// - Limits: Does not compute numeric or exact trigonometric roots.
pub fn chebyshevt_root(n : Expr, k : Expr) -> Expr {
  @symcore.function("chebyshevt_root", [n, k])
}

///|
/// Build a Laguerre polynomial expression.
///
/// - Does: Builds `laguerre(n, x)`.
/// - Input: Degree and argument expressions.
/// - Returns: A symbolic Laguerre polynomial expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn laguerre(n : Expr, x : Expr) -> Expr {
  @symcore.function("laguerre", [n, x])
}

///|
/// Build an associated Laguerre polynomial expression.
///
/// - Does: Builds `assoc_laguerre(n, m, x)`.
/// - Input: Degree, parameter/order, and argument expressions.
/// - Returns: A symbolic associated Laguerre expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn assoc_laguerre(n : Expr, m : Expr, x : Expr) -> Expr {
  @symcore.function("assoc_laguerre", [n, m, x])
}

///|
/// Build a Gegenbauer polynomial expression.
///
/// - Does: Builds `gegenbauer(n, a, x)`.
/// - Input: Degree, parameter, and argument expressions.
/// - Returns: A symbolic Gegenbauer polynomial expression.
/// - Limits: Does not expand integer-degree polynomials.
pub fn gegenbauer(n : Expr, a : Expr, x : Expr) -> Expr {
  @symcore.function("gegenbauer", [n, a, x])
}

///|
/// Build a Jacobi polynomial expression.
///
/// - Does: Builds `jacobi(n, a, b, x)`.
/// - Input: Degree, two parameter expressions, and argument expression.
/// - Returns: A symbolic Jacobi polynomial expression.
/// - Limits: Does not expand integer-degree polynomials or validate parameters.
pub fn jacobi(n : Expr, a : Expr, b : Expr, x : Expr) -> Expr {
  @symcore.function("jacobi", [n, a, b, x])
}

///|
/// Build a normalized Jacobi polynomial expression.
///
/// - Does: Builds `jacobi_normalized(n, a, b, x)`.
/// - Input: Degree, two parameter expressions, and argument expression.
/// - Returns: A symbolic normalized Jacobi polynomial expression.
/// - Limits: Does not evaluate normalization factors or expand polynomials.
pub fn jacobi_normalized(n : Expr, a : Expr, b : Expr, x : Expr) -> Expr {
  @symcore.function("jacobi_normalized", [n, a, b, x])
}
