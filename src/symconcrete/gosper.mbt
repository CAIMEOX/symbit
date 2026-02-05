///|
/// Gosper-style indefinite summation helpers.

///|
pub fn gosper_term(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
) -> @symcore.Expr? {
  gosper_sum(expr, sym)
}

///|
pub fn gosper_normal(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
) -> @symcore.Expr? {
  match gosper_sum(expr, sym) {
    Some(g) => Some(@symcore.function("Tuple", [g, @symcore.int(1)]))
    None => None
  }
}
