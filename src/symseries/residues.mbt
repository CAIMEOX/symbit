///|
/// Residue for rational functions, including higher-order poles, via
/// local series expansion around x0.

///|
fn local_series_poly(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
) -> Array[@symcore.Expr]? {
  let t = @symcore.symbol("__res_t")
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = @symcore.add([x0, t])
  let shifted = @symcore.subst(expr, env)
  poly_from_expr(shifted, t)
}

///|
fn first_nonzero_order(poly : Array[@symcore.Expr]) -> Int {
  let mut i = 0
  while i < poly.length() && is_zero_expr(poly[i]) {
    i += 1
  }
  i
}

///|
fn drop_terms(poly : Array[@symcore.Expr], k : Int) -> Array[@symcore.Expr] {
  if k <= 0 {
    return poly
  }
  if k >= poly.length() {
    return []
  }
  let out : Array[@symcore.Expr] = Array::new()
  for i in k..<poly.length() {
    out.push(poly[i])
  }
  poly_trim(out)
}

///|
fn is_infinite_expr(expr : @symcore.Expr) -> Bool {
  expr == @symcore.symbol("oo") || expr == @symcore.symbol("zoo") ||
  expr == @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")])
}

///|
fn factorial_rational_expr(n : Int) -> @symcore.Expr {
  let mut fact = BigInt::from_int(1)
  let mut i = 2
  while i <= n {
    fact = fact.mul(BigInt::from_int(i))
    i = i + 1
  }
  @symcore.number(safe_rational(BigInt::from_int(1), fact))
}

///|
fn residue_via_pole_order(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
) -> @symcore.Expr raise {
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => ""
  }
  let shift = @symcore.add([x, expr_neg(x0)])
  let mut m = 1
  while m <= 8 {
    let gm = expr_mul(@symcore.pow(shift, @symcore.int(m)), expr)
    let lm = limit(gm, x, x0)
    if !is_infinite_expr(lm) && !contains_symbol(lm, var_name) {
      if m == 1 {
        return lm
      }
      let mut deriv = gm
      let mut k = 0
      while k < m - 1 {
        deriv = @symcalculus.diff(deriv, x)
        k = k + 1
      }
      let val = limit(deriv, x, x0)
      return expr_mul(val, factorial_rational_expr(m - 1))
    }
    m = m + 1
  }
  let first = limit(expr_mul(shift, expr), x, x0)
  if !is_infinite_expr(first) && !contains_symbol(first, var_name) {
    first
  } else {
    @symcore.int(0)
  }
}

///|
pub fn residue(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
) -> @symcore.Expr raise {
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("residue requires a Symbol")
  }
  if !contains_symbol(expr, var_name) {
    return @symcore.int(0)
  }
  let (num_expr, den_expr) = split_num_den(expr)
  match (
    local_series_poly(num_expr, var_name, x0),
    local_series_poly(den_expr, var_name, x0),
  ) {
    (Some(num_poly), Some(den_poly)) => {
      if den_poly.is_empty() {
        return residue_via_pole_order(expr, x, x0)
      }
      let ord_num = first_nonzero_order(num_poly)
      let ord_den = first_nonzero_order(den_poly)
      if ord_den <= ord_num {
        return @symcore.int(0)
      }
      let pole_order = ord_den - ord_num
      let num_reg = drop_terms(num_poly, ord_num)
      let den_reg = drop_terms(den_poly, ord_den)
      if den_reg.is_empty() || is_zero_expr(den_reg[0]) {
        return residue_via_pole_order(expr, x, x0)
      }
      let coeffs = match poly_series_div(num_reg, den_reg, pole_order) {
        Some(v) => v
        None => return residue_via_pole_order(expr, x, x0)
      }
      let idx = pole_order - 1
      if idx < coeffs.length() {
        coeffs[idx]
      } else {
        @symcore.int(0)
      }
    }
    _ => residue_via_pole_order(expr, x, x0)
  }
}
