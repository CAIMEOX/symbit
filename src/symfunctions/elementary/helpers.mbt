///|
/// Shared helpers for elementary functions.

///|
fn num_value(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn is_zero_expr(expr : @symcore.Expr) -> Bool {
  match num_value(expr) {
    Some(n) => n.is_zero()
    None => false
  }
}

///|
fn is_one_expr(expr : @symcore.Expr) -> Bool {
  match num_value(expr) {
    Some(n) => n.is_one()
    None => false
  }
}

///|
fn is_integral_expr(expr : @symcore.Expr) -> Bool {
  match num_value(expr) {
    Some(n) => n.is_integral()
    None => false
  }
}

///|
fn abs_rational(n : @symnum.BigRational) -> @symnum.BigRational {
  if n.numerator().op_lt(BigInt::from_int(0)) {
    n.neg_r()
  } else {
    n
  }
}

///|
fn sign_rational(n : @symnum.BigRational) -> Int {
  if n.is_zero() {
    0
  } else if n.numerator().op_lt(BigInt::from_int(0)) {
    -1
  } else {
    1
  }
}
