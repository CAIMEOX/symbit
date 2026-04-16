///|
/// Parametric RDE helper front door.
///
/// Current Limits:
/// - The current exported path is a thin wrapper over the heuristic integrator.
/// - It does not expose a separate parametric differential-equation object layer.

///|
/// Run the local PRDE-style integrator.
///
/// - Does: Delegates to the heuristic integration path and simplifies the result.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Behavior is currently tied to the heuristic integrator's coverage.
pub fn prde_integrate(expr : Expr, var_name : String) -> Expr? {
  heurisch(expr, var_name).map(expr_simplify)
}
