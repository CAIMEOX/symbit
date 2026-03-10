///|
/// One-dimensional quantum harmonic oscillator formulas.

///|
pub fn psi_n(
  n : @symcore.Expr,
  x : @symcore.Expr,
  m : @symcore.Expr,
  omega : @symcore.Expr,
) -> @symcore.Expr {
  let nu = expr_div(m * omega, hbar)
  let coeff = (expr_div(nu, pi_expr()) ^ rational_expr(1, 4)) *
    @symelem.sqrt(((@symcore.int(2) ^ n) * @symcomb.factorial(n)) ^ @symcore.int(-1))
  coeff * @symelem.exp((@symcore.int(-1) * nu * (x ^ @symcore.int(2))) * rational_expr(1, 2)) *
    @symspec.hermite(n, @symelem.sqrt(nu) * x)
}

///|
pub fn e_n(n : @symcore.Expr, omega : @symcore.Expr) -> @symcore.Expr {
  hbar * omega * (n + rational_expr(1, 2))
}

///|
pub fn coherent_state(
  n : @symcore.Expr,
  alpha : @symcore.Expr,
) -> @symcore.Expr {
  @symelem.exp((@symcore.int(-1) * (@symelem.abs(alpha) ^ @symcore.int(2))) * rational_expr(1, 2)) *
    (alpha ^ n) * @symelem.sqrt(@symcomb.factorial(n) ^ @symcore.int(-1))
}
