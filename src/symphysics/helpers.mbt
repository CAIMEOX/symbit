///|
fn pi_expr() -> Expr {
  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi)
}

///|
fn i_expr() -> Expr {
  @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
}

///|
fn rational_expr(num : Int, den : Int) -> Expr {
  @symcore.rational_from_ints(num, den) catch {
    _ => @symcore.function("Rational", [int(num), int(den)])
  }
}

///|
fn rational_expr_bigint(num : BigInt, den : BigInt) -> Expr {
  @symcore.Expr::Number(@symnum.BigRational::new(num, den)) catch {
    _ =>
      @symcore.function("Rational", [
        @symcore.Expr::Number(@symnum.BigRational::from_bigint(num)),
        @symcore.Expr::Number(@symnum.BigRational::from_bigint(den)),
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
