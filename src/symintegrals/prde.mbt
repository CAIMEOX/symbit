///|
/// Parametric RDE helper surface. The current Stage 3 implementation targets the
/// practical polynomial-times-elementary subfamilies handled by `heurisch`.

///|
pub fn prde_integrate(expr : Expr, var_name : String) -> Expr? {
  heurisch(expr, var_name).map(expr_simplify)
}
