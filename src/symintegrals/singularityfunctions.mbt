///|
/// Symbolic integration rules for `SingularityFunction`.
pub fn singularityintegrate(expr : Expr, var_name : String) -> Expr? {
  match expr_simplify(expr) {
    @symcore.Expr::Function(
      "SingularityFunction",
      [@symcore.Expr::Symbol(name), a, n]
    ) if name == var_name =>
      match expr_is_int_value(n) {
        Some(k) if k >= 0 =>
          Some(
            expr_rat(1, k + 1) *
            @symspec.singularity_function(
              @symcore.Expr::Symbol(var_name),
              a,
              expr_int(k + 1),
            ),
          )
        Some(-1) =>
          Some(
            @symspec.singularity_function(
              @symcore.Expr::Symbol(var_name),
              a,
              expr_zero(),
            ),
          )
        Some(k) =>
          Some(
            @symspec.singularity_function(
              @symcore.Expr::Symbol(var_name),
              a,
              expr_int(k + 1),
            ),
          )
        _ => None
      }
    _ => None
  }
}
