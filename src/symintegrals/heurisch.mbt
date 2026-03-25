///|
/// Practical Heurisch-style dispatcher layered on top of the exact rule engine.

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
    @symcore.Expr::Function(_, args) => {
      for arg in args {
        collect_components(arg, var_name, out)
      }
      push_unique_component(out, expr)
    }
    _ => push_unique_component(out, expr)
  }
}

///|
/// Extract the component functions used by the heuristic integrator.
pub fn components(expr : Expr, var_name : String) -> Array[Expr] {
  let out : Array[Expr] = []
  collect_components(expr_simplify(expr), var_name, out)
  out
}

///|
/// Heuristic single-variable antiderivative search.
///
/// Returns `None` when the heuristic path cannot certify an antiderivative.
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
/// Total wrapper around `heurisch` that falls back to the input expression when
/// no heuristic antiderivative is available.
pub fn heurisch_wrapper(expr : Expr, var_name : String) -> Expr {
  heurisch(expr, var_name).unwrap_or(
    integral(expr, limits=[integral_limit([@symcore.symbol(var_name)])]),
  )
}
