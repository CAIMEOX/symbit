///|
fn pi_expr() -> Expr {
  symbol("pi")
}

///|
fn i_expr() -> Expr {
  symbol("I")
}

///|
fn rational_expr(num : Int, den : Int) -> Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn expr_div(lhs : Expr, rhs : Expr) -> Expr {
  lhs * (rhs ^ int(-1))
}

///|
fn expr_number_value(expr : Expr) -> @symnum.BigRational? {
  match expr {
    Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_integer_value(expr : Expr) -> Int? {
  match expr_number_value(expr) {
    Some(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}
