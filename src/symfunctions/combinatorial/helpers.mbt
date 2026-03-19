///|
/// Shared helpers for combinatorial functions.

///|
fn num_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn int_value(expr : Expr) -> BigInt? {
  match num_value(expr) {
    Some(n) if n.is_integral() => Some(n.numerator())
    _ => None
  }
}

///|
fn expr_from_bigint(n : BigInt) -> Expr {
  @symcore.number(@symnum.BigRational::from_bigint(n))
}

///|
fn expr_from_int(n : Int) -> Expr {
  int(n)
}
