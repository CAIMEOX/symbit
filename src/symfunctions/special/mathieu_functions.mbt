///|
/// Mathieu functions.

///|
pub fn mathieus(
  n : @symcore.Expr,
  q : @symcore.Expr,
  z : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("mathieus", [n, q, z])
}

///|
pub fn mathieuc(
  n : @symcore.Expr,
  q : @symcore.Expr,
  z : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("mathieuc", [n, q, z])
}

///|
pub fn mathieusprime(
  n : @symcore.Expr,
  q : @symcore.Expr,
  z : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("mathieusprime", [n, q, z])
}

///|
pub fn mathieucprime(
  n : @symcore.Expr,
  q : @symcore.Expr,
  z : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("mathieucprime", [n, q, z])
}
