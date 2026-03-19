///|
/// Delta and step functions.

///|
pub fn dirac_delta(expr : Expr) -> Expr {
  @symcore.function("DiracDelta", [expr])
}

///|
pub fn heaviside(expr : Expr) -> Expr {
  @symcore.function("Heaviside", [expr])
}
