///|
/// Particle-on-a-ring wavefunctions and energies.

///|
pub fn wavefunction(
  n : @symcore.Expr,
  x : @symcore.Expr,
) -> @symcore.Expr {
  @symelem.exp(n * i_expr() * x) * (@symelem.sqrt(@symcore.int(2) * pi_expr()) ^ @symcore.int(-1))
}

///|
pub fn energy(
  n : @symcore.Expr,
  m : @symcore.Expr,
  r : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  guard expr_integer_value(n) != None else {
    raise PhysicsError::ValueError("'n' must be integer")
  }
  expr_div((n ^ @symcore.int(2)) * (hbar ^ @symcore.int(2)), (@symcore.int(2) * m * (r ^ @symcore.int(2))))
}
