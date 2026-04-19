///|
/// Zeta and polylogarithmic special functions.
///
/// Current Limits:
/// - These front doors build symbolic zeta-family applications.
/// - Analytic continuation, special values, and series expansions are not
///   implemented here.

///|
/// Build a Riemann zeta expression.
///
/// - Does: Builds `zeta(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic zeta expression.
/// - Limits: Does not evaluate special values or poles.
pub fn zeta(expr : Expr) -> Expr {
  @symcore.function("zeta", [expr])
}

///|
/// Build a Dirichlet eta expression.
///
/// - Does: Builds `dirichlet_eta(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Dirichlet eta expression.
/// - Limits: Does not evaluate special values or rewrite through zeta.
pub fn dirichlet_eta(expr : Expr) -> Expr {
  @symcore.function("dirichlet_eta", [expr])
}

///|
/// Build a Lerch transcendent expression.
///
/// - Does: Builds `lerchphi(z, s, a)`.
/// - Input: Argument, exponent, and shift expressions.
/// - Returns: A symbolic Lerch transcendent expression.
/// - Limits: Does not evaluate reductions to zeta or polylogarithms.
pub fn lerchphi(z : Expr, s : Expr, a : Expr) -> Expr {
  @symcore.function("lerchphi", [z, s, a])
}

///|
/// Build a polylogarithm expression.
///
/// - Does: Builds `polylog(s, z)`.
/// - Input: Order and argument expressions.
/// - Returns: A symbolic polylogarithm expression.
/// - Limits: Does not evaluate special orders or arguments.
pub fn polylog(s : Expr, z : Expr) -> Expr {
  @symcore.function("polylog", [s, z])
}

///|
/// Build a Stieltjes constant expression.
///
/// - Does: Builds `stieltjes(n)`.
/// - Input: One symbolic index expression.
/// - Returns: A symbolic Stieltjes constant expression.
/// - Limits: Does not evaluate numeric constants.
pub fn stieltjes(n : Expr) -> Expr {
  @symcore.function("stieltjes", [n])
}

///|
/// Build a Riemann xi expression.
///
/// - Does: Builds `riemann_xi(expr)`.
/// - Input: One symbolic expression.
/// - Returns: A symbolic Riemann xi expression.
/// - Limits: Does not rewrite through gamma and zeta functions.
pub fn riemann_xi(expr : Expr) -> Expr {
  @symcore.function("riemann_xi", [expr])
}
