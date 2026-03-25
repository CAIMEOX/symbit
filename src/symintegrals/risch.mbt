///|
/// Risch-style exact integration entrypoint for the practical algebraic,
/// logarithmic, exponential, and trigonometric subfamilies supported locally.

///|
/// Risch-style elementary integration entrypoint for one variable.
pub fn risch_integrate(expr : Expr, var_name : String) -> Expr? {
  match manual_integrate(expr, var_name) {
    Some(res) => Some(res)
    None =>
      match prde_integrate(expr, var_name) {
        Some(res) => Some(res)
        None => rde_integrate(expr, var_name)
      }
  }
}
