///|
/// Shared helpers for constructing function expressions.
///
/// Current Limits:
/// - These helpers only build symbolic function applications.
/// - Function-specific arity checks, branch rules, and simplification live in
///   the package-specific front doors.

///|
/// Construct a named function application with an explicit argument list.
///
/// - Does: Creates a symbolic application with the requested function name and
///   argument array.
/// - Input: A function head name and the raw `Expr` argument list.
/// - Returns: One `Expr` application node.
/// - Limits: This helper does not validate the name, arity, or mathematical
///   domain of the function.
pub fn function(name : String, args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function(name, args)
}

///|
/// Construct a unary function application.
///
/// - Does: Builds `name(arg)` through the shared symbolic constructor.
/// - Input: A function head name and one symbolic argument.
/// - Returns: One `Expr` application node.
/// - Limits: This helper does not apply function-specific simplification.
pub fn unary(name : String, arg : @symcore.Expr) -> @symcore.Expr {
  @symcore.function(name, [arg])
}

///|
/// Construct a binary function application.
///
/// - Does: Builds `name(left, right)` through the shared symbolic constructor.
/// - Input: A function head name and two symbolic arguments.
/// - Returns: One `Expr` application node.
/// - Limits: This helper does not apply function-specific simplification or
///   commutativity rules.
pub fn binary(
  name : String,
  left : @symcore.Expr,
  right : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function(name, [left, right])
}
