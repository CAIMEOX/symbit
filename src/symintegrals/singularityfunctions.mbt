///|
/// Symbolic integration rules for `SingularityFunction`.
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
