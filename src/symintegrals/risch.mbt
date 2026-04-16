///|
/// Risch-style integration front door.
///
/// Current Limits:
/// - This front door delegates to the currently implemented elementary subsolvers.
/// - It is not a full decision procedure for all elementary integrals.

///|
/// Try the Risch-style elementary integration pipeline.
///
/// - Does: Runs the local elementary integration subsolvers for `expr` in one variable.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Coverage is limited to the practical subfamilies implemented by the local subsolvers.
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
