///|
/// SingularityFunction.

///|
pub fn singularity_function(
  expr : @symcore.Expr,
  a : @symcore.Expr,
  n : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("SingularityFunction", [expr, a, n])
}
