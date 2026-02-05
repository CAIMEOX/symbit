///|
/// Delta and step functions.

///|
pub fn dirac_delta(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("DiracDelta", [expr])
}

///|
pub fn heaviside(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Heaviside", [expr])
}
