///|
/// Practical Heurisch-style front doors.
///
/// Current Limits:
/// - The exposed API is a lightweight heuristic layer over manual and rational integration helpers.
/// - It returns `None` or unevaluated integrals when no heuristic rule applies.

///|
fn push_unique_component(out : Array[Expr], expr : Expr) -> Unit {
  if !out.any(fn(prev) { @symcore.compare_expr(prev, expr) == 0 }) {
    out.push(expr)
  }
}

///|
fn collect_components(
  expr : Expr,
  var_name : String,
  out : Array[Expr],
) -> Unit {
  if !expr_depends_on(expr, var_name) {
    return
  }
  match expr {
    @symcore.Expr::Symbol(name) if name == var_name =>
      push_unique_component(out, expr)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for arg in args {
        collect_components(arg, var_name, out)
      }
    @symcore.Expr::Pow(base, exp) => {
      collect_components(base, var_name, out)
      collect_components(exp, var_name, out)
      push_unique_component(out, expr)
    }
    _ =>
      match @symcore.application_args(expr) {
        Some(args) => {
          for arg in args {
            collect_components(arg, var_name, out)
          }
          push_unique_component(out, expr)
        }
        None => push_unique_component(out, expr)
      }
  }
}

///|
/// Extract heuristic components from an integrand.
///
/// - Does: Collects the dependent subexpressions that the heuristic integrator treats as components.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: An `Array[Expr]` of collected components.
/// - Limits: The collection is structural and does not prove algebraic independence.
pub fn components(expr : Expr, var_name : String) -> Array[Expr] {
  let out : Array[Expr] = []
  collect_components(expr_simplify(expr), var_name, out)
  out
}

///|
/// Search for a heuristic one-variable antiderivative.
///
/// - Does: Tries heuristic integration routes for `expr` in the variable named by `var_name`.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Returns `None` when the heuristic path cannot certify an antiderivative.
pub fn heurisch(expr : Expr, var_name : String) -> Expr? {
  match manual_integrate(expr, var_name) {
    Some(res) => Some(res)
    None =>
      match ratint(expr, var_name) {
        Some(res) => Some(expr_simplify(res))
        None => None
      }
  }
}

///|
/// Wrap `heurisch` with an unevaluated fallback.
///
/// - Does: Runs `heurisch` and falls back to an unevaluated `Integral` when no result is found.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: One `Expr`, either an antiderivative or an unevaluated integral.
/// - Limits: The fallback is always symbolic; it does not raise on heuristic failure.
pub fn heurisch_wrapper(expr : Expr, var_name : String) -> Expr {
  heurisch(expr, var_name).unwrap_or(
    integral(expr, limits=[integral_limit([@symcore.Expr::Symbol(var_name)])]),
  )
}
