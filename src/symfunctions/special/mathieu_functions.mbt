///|
/// Mathieu functions.
///
/// Current Limits:
/// - These front doors build symbolic Mathieu applications.
/// - Characteristic values, expansions, and numerical evaluation are not
///   implemented here.

///|
/// Build an odd Mathieu sine expression.
///
/// - Does: Builds `mathieus(n, q, z)`.
/// - Input: Order, parameter, and argument expressions.
/// - Returns: A symbolic Mathieu sine expression.
/// - Limits: Does not evaluate characteristic expansions.
pub fn mathieus(n : Expr, q : Expr, z : Expr) -> Expr {
  @symcore.function("mathieus", [n, q, z])
}

///|
/// Build an even Mathieu cosine expression.
///
/// - Does: Builds `mathieuc(n, q, z)`.
/// - Input: Order, parameter, and argument expressions.
/// - Returns: A symbolic Mathieu cosine expression.
/// - Limits: Does not evaluate characteristic expansions.
pub fn mathieuc(n : Expr, q : Expr, z : Expr) -> Expr {
  @symcore.function("mathieuc", [n, q, z])
}

///|
/// Build a derivative of the odd Mathieu sine expression.
///
/// - Does: Builds `mathieusprime(n, q, z)`.
/// - Input: Order, parameter, and argument expressions.
/// - Returns: A symbolic Mathieu sine-derivative expression.
/// - Limits: Does not evaluate derivative expansions.
pub fn mathieusprime(n : Expr, q : Expr, z : Expr) -> Expr {
  @symcore.function("mathieusprime", [n, q, z])
}

///|
/// Build a derivative of the even Mathieu cosine expression.
///
/// - Does: Builds `mathieucprime(n, q, z)`.
/// - Input: Order, parameter, and argument expressions.
/// - Returns: A symbolic Mathieu cosine-derivative expression.
/// - Limits: Does not evaluate derivative expansions.
pub fn mathieucprime(n : Expr, q : Expr, z : Expr) -> Expr {
  @symcore.function("mathieucprime", [n, q, z])
}
