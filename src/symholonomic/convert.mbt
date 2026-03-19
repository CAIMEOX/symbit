///|
pub fn from_hyper(
  expr : Expr,
  x? : Expr = symbol("x"),
  x0? : Expr = int(0),
) -> HolonomicFunction {
  expr_to_holonomic(expr, x~, x0~)
}

///|
pub fn from_meijerg(
  expr : Expr,
  x? : Expr = symbol("x"),
  x0? : Expr = int(0),
) -> HolonomicFunction {
  expr_to_holonomic(expr, x~, x0~)
}

///|
pub fn to_expr(hf : HolonomicFunction) -> Expr {
  hf.to_expr()
}

///|
pub fn to_sequence(hf : HolonomicFunction) -> Array[HolonomicSequence] {
  hf.to_sequence()
}

///|
pub fn to_hyper(hf : HolonomicFunction) -> Expr {
  hf.to_expr()
}
