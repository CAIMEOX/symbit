///|
pub fn from_hyper(
  expr : @symcore.Expr,
  x? : @symcore.Expr = @symcore.symbol("x"),
  x0? : @symcore.Expr = @symcore.int(0),
) -> HolonomicFunction {
  expr_to_holonomic(expr, x=x, x0~)
}

///|
pub fn from_meijerg(
  expr : @symcore.Expr,
  x? : @symcore.Expr = @symcore.symbol("x"),
  x0? : @symcore.Expr = @symcore.int(0),
) -> HolonomicFunction {
  expr_to_holonomic(expr, x=x, x0~)
}

///|
pub fn to_expr(hf : HolonomicFunction) -> @symcore.Expr {
  hf.to_expr()
}

///|
pub fn to_sequence(hf : HolonomicFunction) -> Array[HolonomicSequence] {
  hf.to_sequence()
}

///|
pub fn to_hyper(hf : HolonomicFunction) -> @symcore.Expr {
  hf.to_expr()
}
