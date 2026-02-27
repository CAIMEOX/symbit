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
        fail("residue unsupported denominator")
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
        fail("residue unsupported pole")
      }
      let coeffs = match poly_series_div(num_reg, den_reg, pole_order) {
        Some(v) => v
        None => fail("residue unsupported division")
      }
      let idx = pole_order - 1
      if idx < coeffs.length() {
        coeffs[idx]
      } else {
        @symcore.int(0)
      }
    }
    _ => fail("residue unsupported expression")
  }
}
