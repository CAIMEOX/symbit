///|
/// RDE helper front door.
///
/// Current Limits:
/// - The current exported path is a thin wrapper over the rational integrator.
/// - It does not expose a separate differential-equation object layer.

///|
/// Run the local RDE-style integrator.
///
/// - Does: Delegates to the rational integration path and simplifies the result.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Behavior is currently tied to the rational integrator's coverage.
pub fn rde_integrate(expr : Expr, var_name : String) -> Expr? {
  ratint(expr, var_name).map(expr_simplify)
}
