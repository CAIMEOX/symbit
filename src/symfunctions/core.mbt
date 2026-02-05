///|
/// Shared helpers for constructing function expressions.

///|
pub fn function(name : String, args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function(name, args)
}

///|
pub fn unary(name : String, arg : @symcore.Expr) -> @symcore.Expr {
  @symcore.function(name, [arg])
}

///|
pub fn binary(
  name : String,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function(name, [left, right])
}
