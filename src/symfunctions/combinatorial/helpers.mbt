///|
/// Shared helpers for combinatorial functions.

///|
fn num_value(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn int_value(expr : @symcore.Expr) -> BigInt? {
  match num_value(expr) {
    Some(n) if n.is_integral() => Some(n.numerator())
    _ => None
  }
}

///|
fn expr_from_bigint(n : BigInt) -> @symcore.Expr {
  @symcore.number(@symnum.BigRational::from_bigint(n))
}

///|
fn expr_from_int(n : Int) -> @symcore.Expr {
  @symcore.int(n)
}
