///|
/// Shared helpers for special functions.

///|
fn num_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Number(n) => Some(n)
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
  Number(@symnum.BigRational::from_bigint(n))
}

///|
fn factorial_bigint(n : Int) -> BigInt {
  if n <= 1 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  let mut i = 2
  while i <= n {
    acc = acc * BigInt::from_int(i)
    i = i + 1
  }
  acc
}
