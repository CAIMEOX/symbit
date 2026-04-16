///|
/// Singularity-function integration front door.
///
/// Current Limits:
/// - Coverage is restricted to direct `SingularityFunction` antiderivative rules.
/// - Unsupported cases return `None`.
///
/// - Does: Applies the local `SingularityFunction` antiderivative rules to `expr`.
/// - Input: One integrand `Expr` and one variable name.
/// - Returns: `Some(Expr)` for a found antiderivative or `None`.
/// - Limits: Only direct singularity-function forms are recognized.
pub fn singularityintegrate(expr : Expr, var_name : String) -> Expr? {
  let expr = expr_simplify(expr)
  match @symcore.application_args(expr) {
    Some([@symcore.Expr::Symbol(name), a, n]) if name == var_name &&
      @symcore.application_has_name(expr, "SingularityFunction", arity=3) =>
      match expr_is_int_value(n) {
        Some(k) if k >= 0 =>
          Some(
            expr_rat(1, k + 1) *
            @symspec.singularity_function(
              @symcore.Expr::Symbol(var_name),
              a,
              @symcore.int(k + 1),
            ),
          )
        Some(-1) =>
          Some(
            @symspec.singularity_function(
              @symcore.Expr::Symbol(var_name),
              a,
              @symcore.int(0),
            ),
          )
        Some(k) =>
          Some(
            @symspec.singularity_function(
              @symcore.Expr::Symbol(var_name),
              a,
              @symcore.int(k + 1),
            ),
          )
        _ => None
      }
    _ => None
  }
}
