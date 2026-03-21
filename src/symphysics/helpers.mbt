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
  match
    (
      try? @symcore.rational_from_ints(num, den) :
      Result[Expr, @symnum.RationalError]) {
    Ok(value) => value
    Err(_) => @symcore.function("Rational", [int(num), int(den)])
  }
}

///|
fn rational_expr_bigint(num : BigInt, den : BigInt) -> Expr {
  match
    (
      try? @symnum.BigRational::new(num, den) :
      Result[@symnum.BigRational, @symnum.RationalError]) {
    Ok(value) => @symcore.number(value)
    Err(_) =>
      @symcore.function("Rational", [
        @symcore.number(@symnum.BigRational::from_bigint(num)),
        @symcore.number(@symnum.BigRational::from_bigint(den)),
      ])
  }
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
