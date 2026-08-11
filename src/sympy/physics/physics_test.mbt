///|
using @symcore {type Expr, int}

///|
fn physics_matrix_expr_equal(
  lhs : ExplicitMatrix,
  rhs : ExplicitMatrix,
) -> Bool {
  if lhs.height() != rhs.height() || lhs.width() != rhs.width() {
    return false
  }
  for i in 0..<lhs.height() {
    for j in 0..<lhs.width() {
      if !physics_expr_equal(
          lhs.rows[i][j],
          @symprint.pretty_string(rhs.rows[i][j]),
        ) {
        return false
      }
    }
  }
  true
}

///|
test "physics: Pauli and Dirac matrices satisfy core identities" {
  let i = @symcore.Expr::NumberSymbol(ImaginaryUnit)
  let sigma1 = @symphysics.msigma(1)
  let sigma2 = @symphysics.msigma(2)
  let sigma3 = @symphysics.msigma(3)
  let gamma0 = @symphysics.mgamma(0)
  let gamma1 = @symphysics.mgamma(1)
  let gamma2 = @symphysics.mgamma(2)
  let gamma3 = @symphysics.mgamma(3)
  let gamma5 = @symphysics.mgamma(5)

  assert_true(sigma1.mul(sigma2) == sigma3.scale(i))
  assert_true(sigma1.mul(sigma1) == @symphysics.explicit_matrix_eye(2))
  assert_true(sigma1.mul(sigma3).mul(sigma1) == sigma3.neg())

  assert_true(
    physics_matrix_expr_equal(
      gamma0.mul(gamma1).mul(gamma2).mul(gamma3).scale(i),
      gamma5,
    ),
  )
  assert_true(
    physics_matrix_expr_equal(
      gamma0.mul(gamma0),
      @symphysics.explicit_matrix_eye(4).scale(int(1)),
    ),
  )
  assert_true(
    physics_matrix_expr_equal(
      gamma2.mul(gamma2),
      @symphysics.explicit_matrix_eye(4).scale(int(-1)),
    ),
  )
}

///|
test "physics: simple wavefunction and energy behaviors" {
  let x = Expr::Symbol("x")
  let alpha = Expr::Symbol("alpha")
  let psi0 = @symphysics.psi_n(int(0), x, int(1), int(1))
  physics_assert_expr_equal(
    psi0, "exp(-x**2/(2*hbar))/(hbar**(1/4)*pi**(1/4))", "psi_n ground state",
  )

  let cs0 = @symphysics.coherent_state(int(0), alpha)
  physics_assert_expr_equal(cs0, "exp(-Abs(alpha)**2/2)", "coherent_state n=0")

  physics_assert_expr_equal(
    @symphysics.wavefunction(int(0), x),
    "1/sqrt(2*pi)",
    "ring wavefunction n=0",
  )

  let err : Result[Expr, PhysicsError] = try
    @symphysics.energy(Symbol("n"), Symbol("m"), Symbol("r")) |> Ok
  catch {
    error => Err(error)
  }
  assert_true(err is Err(_))
}

///|
test "physics: hydrogen formulas and quantum-number guards" {
  let r = Expr::Symbol("r")
  let phi = Expr::Symbol("phi")
  let theta = Expr::Symbol("theta")

  physics_assert_expr_equal(
    @symphysics.hydrogen_e_nl(int(1)),
    "-1/2",
    "hydrogen ground-state energy",
  )
  physics_assert_expr_equal(
    @symphysics.hydrogen_r_nl(int(1), int(0), r),
    "2*exp(-r)",
    "hydrogen radial ground state",
  )

  let psi_err : Result[Expr, PhysicsError] = try
    @symphysics.hydrogen_psi_nlm(int(1), int(1), int(0), r, phi, theta) |> Ok
  catch {
    error => Err(error)
  }
  assert_true(psi_err is Err(_))

  let dirac_err : Result[Expr, PhysicsError] = try
    @symphysics.hydrogen_e_nl_dirac(int(1), int(0), spin_up=false) |> Ok
  catch {
    error => Err(error)
  }
  assert_true(dirac_err is Err(_))
}

///|
test "physics: wigner coefficients obey core examples and guards" {
  let half = physics_frac(1, 2)
  let three_half = physics_frac(3, 2)

  physics_assert_expr_equal(
    @symphysics.wigner_3j(int(2), int(6), int(4), int(0), int(0), int(0)),
    "sqrt(715)/143",
    "wigner_3j docs",
  )
  physics_assert_expr_equal(
    @symphysics.clebsch_gordan(
      three_half,
      half,
      int(2),
      three_half,
      half,
      int(2),
    ),
    "1",
    "clebsch_gordan docs",
  )
  physics_assert_expr_equal(
    @symphysics.clebsch_gordan(half, half, int(1), half, half, int(0)),
    "0",
    "clebsch_gordan zero",
  )

  let bad : Result[Expr, PhysicsError] = try
    @symphysics.wigner_3j(
      physics_frac(1, 3),
      half,
      half,
      int(0),
      half,
      int(-1) * half,
    )
    |> Ok
  catch {
    error => Err(error)
  }
  assert_true(bad is Err(_))
}

///|
test "physics: gaunt examples and guards" {
  physics_assert_expr_equal(
    @symphysics.gaunt(int(1), int(0), int(1), int(1), int(0), int(-1)),
    "-1/(2*sqrt(pi))",
    "gaunt example",
  )
  physics_assert_expr_equal(
    @symphysics.gaunt(int(1), int(1), int(0), int(0), int(2), int(-2)),
    "0",
    "gaunt zero",
  )

  let bad : Result[Expr, PhysicsError] = try
    @symphysics.gaunt(
      physics_frac(1, 2),
      int(1),
      int(1),
      int(0),
      int(0),
      int(0),
    )
    |> Ok
  catch {
    error => Err(error)
  }
  assert_true(bad is Err(_))
}

///|
test "physics: higher wigner examples and guards" {
  let half = physics_frac(1, 2)
  physics_assert_expr_equal(
    @symphysics.wigner_6j(int(5), int(5), int(5), int(5), int(5), int(5)),
    "1/52",
    "wigner_6j example",
  )
  physics_assert_expr_equal(
    @symphysics.wigner_6j(int(3), int(3), int(3), int(3), int(3), int(3)),
    "-1/14",
    "wigner_6j 3",
  )
  physics_assert_expr_equal(
    @symphysics.racah(int(3), int(3), int(3), int(3), int(3), int(3)),
    "-1/14",
    "racah example",
  )
  physics_assert_expr_equal(
    @symphysics.wigner_9j(
      int(0),
      int(0),
      int(0),
      int(0),
      half,
      half,
      int(0),
      half,
      half,
    ),
    "1/2",
    "wigner_9j half example",
  )
  physics_assert_expr_equal(
    @symphysics.wigner_9j(
      int(1),
      int(2),
      int(3),
      int(3),
      int(2),
      int(1),
      int(2),
      int(1),
      int(3),
    ),
    "-4*sqrt(70)/11025",
    "wigner_9j exact example",
  )
  physics_assert_expr_equal(
    @symphysics.wigner_9j(
      half,
      half,
      int(1),
      half,
      half,
      int(1),
      int(1),
      half,
      half,
    ),
    "0",
    "wigner_9j zero",
  )
}

///|
test "physics: real gaunt examples and zeros" {
  physics_assert_expr_equal(
    @symphysics.real_gaunt(int(1), int(1), int(2), int(-1), int(1), int(-2)),
    "-sqrt(15)/(10*sqrt(pi))",
    "real_gaunt example",
  )
  physics_assert_expr_equal(
    @symphysics.real_gaunt(int(2), int(2), int(2), int(1), int(1), int(2)),
    "sqrt(15)/(14*sqrt(pi))",
    "real_gaunt 222",
  )
  physics_assert_expr_equal(
    @symphysics.real_gaunt(int(-2), int(1), int(0), int(1), int(1), int(1)),
    "0",
    "real_gaunt zero",
  )
}

///|
test "physics: rotational harmonic examples" {
  let theta = Expr::Symbol("theta")
  let phi = Expr::Symbol("phi")
  let half = physics_frac(1, 2)
  let alpha = Expr::Symbol("alpha")
  let beta = Expr::Symbol("beta")
  let gamma = Expr::Symbol("gamma")

  physics_assert_expr_equal(
    @symphysics.dot_rot_grad_ynm(int(3), int(2), int(2), int(0), theta, phi),
    "3*sqrt(55)*Ynm(5, 2, theta, phi)/(11*sqrt(pi))",
    "dot_rot_grad example",
  )
  physics_assert_expr_equal(
    @symphysics.dot_rot_grad_ynm(int(1), int(5), int(1), int(1), int(1), int(2)),
    "0",
    "dot_rot_grad zero",
  )

  assert_true(
    physics_matrix_expr_equal(
      @symphysics.wigner_d_small(half, int(0)),
      @symphysics.explicit_matrix_eye(2),
    ),
  )

  let d = @symphysics.wigner_d(half, alpha, beta, gamma)
  physics_assert_expr_equal(
    d.rows[0][0],
    "exp(I*alpha/2)*exp(I*gamma/2)*cos(beta/2)",
    "wigner_d(0,0)",
  )
  physics_assert_expr_equal(
    d.rows[0][1],
    "exp(I*alpha/2)*exp(-I*gamma/2)*sin(beta/2)",
    "wigner_d(0,1)",
  )
  physics_assert_expr_equal(
    d.rows[1][0],
    "-exp(-I*alpha/2)*exp(I*gamma/2)*sin(beta/2)",
    "wigner_d(1,0)",
  )
  physics_assert_expr_equal(
    d.rows[1][1],
    "exp(-I*alpha/2)*exp(-I*gamma/2)*cos(beta/2)",
    "wigner_d(1,1)",
  )
}
