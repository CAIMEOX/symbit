///|
fn pi_expr() -> @symcore.Expr {
  @symcore.symbol("pi")
}

///|
fn i_expr() -> @symcore.Expr {
  @symcore.symbol("I")
}

///|
fn rational_expr(num : Int, den : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(num, den)
}

///|
fn expr_div(lhs : @symcore.Expr, rhs : @symcore.Expr) -> @symcore.Expr {
  lhs * (rhs ^ @symcore.int(-1))
}

///|
fn expr_number_value(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
fn expr_integer_value(expr : @symcore.Expr) -> Int? {
  match expr_number_value(expr) {
    Some(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}
