///|
/// Three-dimensional isotropic harmonic oscillator formulas.

///|
pub fn r_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  nu : @symcore.Expr,
  r : @symcore.Expr,
) -> @symcore.Expr {
  let n1 = n + @symcore.int(1)
  let coeff = @symelem.sqrt(
    expr_div(
      ((@symcore.int(2) * nu) ^ (l + rational_expr(3, 2))) *
        (@symcore.int(2) ^ (n1 + l + @symcore.int(1))) *
        @symcomb.factorial(n1 + @symcore.int(-1)),
      @symelem.sqrt(pi_expr()) *
        @symcomb.factorial2((@symcore.int(2) * n1) + (@symcore.int(2) * l) + @symcore.int(-1)),
    ),
  )
  coeff *
    (r ^ l) *
    @symelem.exp(@symcore.int(-1) * nu * (r ^ @symcore.int(2))) *
    @symspec.assoc_laguerre(
      n1 + @symcore.int(-1),
      l + rational_expr(1, 2),
      (@symcore.int(2) * nu) * (r ^ @symcore.int(2)),
    )
}

///|
pub fn e_nl(
  n : @symcore.Expr,
  l : @symcore.Expr,
  hw : @symcore.Expr,
) -> @symcore.Expr {
  ((@symcore.int(2) * n) + l + rational_expr(3, 2)) * hw
}
