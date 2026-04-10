///|
/// Shared helpers for constructing function expressions.

///|
/// Construct a named function application with an explicit argument list.
///
/// This is the generic entry point for building expression nodes such as
/// `sin(x)` or `max(x, y)` when you already know the function head name.
pub fn function(name : String, args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function(name, args)
}

///|
/// Construct a unary function application.
///
/// This is shorthand for [`function`](#function) with a single argument.
pub fn unary(name : String, arg : @symcore.Expr) -> @symcore.Expr {
  @symcore.function(name, [arg])
}

///|
/// Construct a binary function application.
///
/// This is shorthand for [`function`](#function) with exactly two arguments.
pub fn binary(
  name : String,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function(name, [left, right])
}
