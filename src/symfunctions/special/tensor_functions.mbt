///|
/// Tensor-related special functions.
///
/// Current Limits:
/// - These front doors build symbolic tensor-function applications.
/// - Index validation, dimension-aware simplification, and contraction logic are
///   not implemented here.

///|
/// Build a three-index Levi-Civita expression.
///
/// - Does: Builds `Eijk(i, j, k)`.
/// - Input: Three symbolic index expressions.
/// - Returns: A symbolic three-index Levi-Civita expression.
/// - Limits: Does not evaluate repeated or numeric indices.
pub fn eijk(i : Expr, j : Expr, k : Expr) -> Expr {
  @symcore.function("Eijk", [i, j, k])
}

///|
/// Build a variadic Levi-Civita expression.
///
/// - Does: Builds `LeviCivita(args...)`.
/// - Input: An array of symbolic index expressions.
/// - Returns: A symbolic Levi-Civita expression.
/// - Limits: Does not evaluate permutations or repeated indices.
pub fn levi_civita(args : Array[Expr]) -> Expr {
  @symcore.function("LeviCivita", args)
}

///|
/// Build a Kronecker delta expression.
///
/// - Does: Builds `KroneckerDelta(a, b)`.
/// - Input: Two symbolic index expressions.
/// - Returns: A symbolic Kronecker delta expression.
/// - Limits: Does not evaluate equal numeric indices or assumptions.
pub fn kronecker_delta(a : Expr, b : Expr) -> Expr {
  @symcore.function("KroneckerDelta", [a, b])
}
