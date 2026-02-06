///|
pub fn evalf(
  hf : HolonomicFunction,
  x_value : @symnum.BigRational,
  terms? : Int = 20,
) -> @symcore.Expr {
  hf.evalf(x_value, terms~)
}

///|
pub fn evalf_euler(
  hf : HolonomicFunction,
  x_value : @symnum.BigRational,
  steps? : Int = 20,
) -> @symcore.Expr {
  hf.evalf(x_value, terms=steps)
}

///|
pub fn evalf_rk4(
  hf : HolonomicFunction,
  x_value : @symnum.BigRational,
  steps? : Int = 20,
) -> @symcore.Expr {
  hf.evalf(x_value, terms=steps)
}
