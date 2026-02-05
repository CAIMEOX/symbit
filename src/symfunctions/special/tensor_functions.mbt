///|
/// Tensor-related special functions.

///|
pub fn eijk(
  i : @symcore.Expr,
  j : @symcore.Expr,
  k : @symcore.Expr,
) -> @symcore.Expr {
  @symcore.function("Eijk", [i, j, k])
}

///|
pub fn levi_civita(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function("LeviCivita", args)
}

///|
pub fn kronecker_delta(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("KroneckerDelta", [a, b])
}
