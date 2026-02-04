///|
/// Residue placeholder.

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
  match (poly_from_expr(num_expr, x), poly_from_expr(den_expr, x)) {
    (Some(num_poly), Some(den_poly)) => {
      let den_val = poly_eval(den_poly, x0)
      if !is_zero_expr(den_val) {
        return @symcore.int(0)
      }
      let den_deriv = poly_derivative(den_poly)
      let den_prime = poly_eval(den_deriv, x0)
      if is_zero_expr(den_prime) {
        fail("residue higher-order pole not implemented")
      }
      let num_val = poly_eval(num_poly, x0)
      let inv = match expr_inv(den_prime) {
        Some(v) => v
        None => fail("residue division by zero")
      }
      expr_mul(num_val, inv)
    }
    _ => fail("residue unsupported expression")
  }
}
