///|
fn physics_matrix_expr_equal(lhs : ExplicitMatrix, rhs : ExplicitMatrix) -> Bool {
  if lhs.height() != rhs.height() || lhs.width() != rhs.width() {
    return false
  }
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      if !physics_expr_equal(lhs.rows[i][j], @symprint.to_string(rhs.rows[i][j])) {
        return false
      }
    }
  }
  true
}

///|
test "physics: Pauli and Dirac matrices satisfy core identities" {
  let i = @symcore.symbol("I")
  let sigma1 = try! msigma(1)
  let sigma2 = try! msigma(2)
  let sigma3 = try! msigma(3)
  let gamma0 = try! mgamma(0)
  let gamma1 = try! mgamma(1)
  let gamma2 = try! mgamma(2)
  let gamma3 = try! mgamma(3)
  let gamma5 = try! mgamma(5)

  guard sigma1.mul(sigma2) == sigma3.scale(i) else {
    fail("sigma1*sigma2 should equal I*sigma3")
  }
  guard sigma1.mul(sigma1) == explicit_matrix_eye(2) else {
    fail("sigma1 squared should be identity")
  }
  guard sigma1.mul(sigma3).mul(sigma1) == sigma3.neg() else {
    fail("sigma1*sigma3*sigma1 should equal -sigma3")
  }

  guard physics_matrix_expr_equal(gamma0.mul(gamma1).mul(gamma2).mul(gamma3).scale(i), gamma5) else {
    fail("gamma5 identity mismatch")
  }
  guard physics_matrix_expr_equal(gamma0.mul(gamma0), explicit_matrix_eye(4).scale(@symcore.int(1))) else {
    fail("gamma0 squared should be identity")
  }
  guard physics_matrix_expr_equal(gamma2.mul(gamma2), explicit_matrix_eye(4).scale(@symcore.int(-1))) else {
    fail("gamma2 squared should be negative identity")
  }
}

///|
test "physics: simple wavefunction and energy behaviors" {
  let x = @symcore.symbol("x")
  let alpha = @symcore.symbol("alpha")
  let psi0 = psi_n(@symcore.int(0), x, @symcore.int(1), @symcore.int(1))
  physics_assert_expr_equal(psi0, "exp(-x**2/(2*hbar))/(hbar**(1/4)*pi**(1/4))", "psi_n ground state")

  let cs0 = coherent_state(@symcore.int(0), alpha)
  physics_assert_expr_equal(cs0, "exp(-Abs(alpha)**2/2)", "coherent_state n=0")

  physics_assert_expr_equal(wavefunction(@symcore.int(0), x), "1/sqrt(2*pi)", "ring wavefunction n=0")

  let err : Result[@symcore.Expr, PhysicsError] = try? energy(@symcore.symbol("n"), @symcore.symbol("m"), @symcore.symbol("r"))
  guard err is Err(_) else {
    fail("pring energy should reject non-literal integer n in current core model")
  }
}
