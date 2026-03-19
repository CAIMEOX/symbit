///|
/// Three-dimensional isotropic harmonic oscillator formulas.

///|
pub fn r_nl(
  n : Expr,
  l : Expr,
  nu : Expr,
  r : Expr,
) -> Expr {
  let n1 = n + int(1)
  let coeff = @symelem.sqrt(
    expr_div(
      ((int(2) * nu) ^ (l + rational_expr(3, 2))) *
      (int(2) ^ (n1 + l + int(1))) *
      @symcomb.factorial(n1 + int(-1)),
      @symelem.sqrt(pi_expr()) *
      @symcomb.factorial2(
        int(2) * n1 + int(2) * l + int(-1),
      ),
    ),
  )
  coeff *
  (r ^ l) *
  @symelem.exp(int(-1) * nu * (r ^ int(2))) *
  @symspec.assoc_laguerre(
    n1 + int(-1),
    l + rational_expr(1, 2),
    int(2) * nu * (r ^ int(2)),
  )
}

///|
pub fn e_nl(
  n : Expr,
  l : Expr,
  hw : Expr,
) -> Expr {
  (int(2) * n + l + rational_expr(3, 2)) * hw
}
