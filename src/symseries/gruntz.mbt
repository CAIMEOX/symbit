///|
/// Gruntz algorithm placeholder.

///|
pub fn gruntz(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> @symcore.Expr raise {
  // Use the same limit backend for now.
  limit(expr, x, x0, dir~)
}
