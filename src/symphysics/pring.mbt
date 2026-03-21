///|
/// Particle-on-a-ring wavefunctions and energies.

///|
pub fn wavefunction(n : Expr, x : Expr) -> Expr {
  @symelem.exp(n * i_expr() * x) * (@symelem.sqrt(int(2) * pi_expr()) ^ int(-1))
}

///|
pub fn energy(n : Expr, m : Expr, r : Expr) -> Expr raise PhysicsError {
  guard expr_integer_value(n) != None else {
    raise PhysicsError::ValueError("'n' must be integer")
  }
  expr_div((n ^ int(2)) * (hbar ^ int(2)), int(2) * m * (r ^ int(2)))
}
