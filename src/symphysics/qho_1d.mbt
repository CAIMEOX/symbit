///|
/// One-dimensional quantum harmonic oscillator formulas.

///|
pub fn psi_n(
  n : Expr,
  x : Expr,
  m : Expr,
  omega : Expr,
) -> Expr {
  let nu = expr_div(m * omega, hbar)
  let coeff = (expr_div(nu, pi_expr()) ^ rational_expr(1, 4)) *
    @symelem.sqrt(
      ((int(2) ^ n) * @symcomb.factorial(n)) ^ int(-1),
    )
  coeff *
  @symelem.exp(
    int(-1) * nu * (x ^ int(2)) * rational_expr(1, 2),
  ) *
  @symspec.hermite(n, @symelem.sqrt(nu) * x)
}

///|
pub fn e_n(n : Expr, omega : Expr) -> Expr {
  hbar * omega * (n + rational_expr(1, 2))
}

///|
pub fn coherent_state(
  n : Expr,
  alpha : Expr,
) -> Expr {
  @symelem.exp(
    int(-1) *
    (@symelem.abs(alpha) ^ int(2)) *
    rational_expr(1, 2),
  ) *
  (alpha ^ n) *
  @symelem.sqrt(@symcomb.factorial(n) ^ int(-1))
}
