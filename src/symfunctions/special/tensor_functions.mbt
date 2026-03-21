///|
/// Tensor-related special functions.

///|
pub fn eijk(i : Expr, j : Expr, k : Expr) -> Expr {
  @symcore.function("Eijk", [i, j, k])
}

///|
pub fn levi_civita(args : Array[Expr]) -> Expr {
  @symcore.function("LeviCivita", args)
}

///|
pub fn kronecker_delta(a : Expr, b : Expr) -> Expr {
  @symcore.function("KroneckerDelta", [a, b])
}
