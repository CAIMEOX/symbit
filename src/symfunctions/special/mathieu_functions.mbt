///|
/// Mathieu functions.

///|
pub fn mathieus(
  n : Expr,
  q : Expr,
  z : Expr,
) -> Expr {
  @symcore.function("mathieus", [n, q, z])
}

///|
pub fn mathieuc(
  n : Expr,
  q : Expr,
  z : Expr,
) -> Expr {
  @symcore.function("mathieuc", [n, q, z])
}

///|
pub fn mathieusprime(
  n : Expr,
  q : Expr,
  z : Expr,
) -> Expr {
  @symcore.function("mathieusprime", [n, q, z])
}

///|
pub fn mathieucprime(
  n : Expr,
  q : Expr,
  z : Expr,
) -> Expr {
  @symcore.function("mathieucprime", [n, q, z])
}
