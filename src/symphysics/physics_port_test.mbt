///|
fn physics_expr_equal(lhs : @symcore.Expr, rhs : String) -> Bool {
  try! @sympy_physics.expr_equal(@symprint.to_string(lhs), rhs)
}

///|
fn physics_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  assert_true((try! @sympy_physics.expr_equal(ours, rhs)))
}

///|
fn physics_assert_matrix_equiv(
  lhs : ExplicitMatrix,
  rhs : Array[String],
  context : String,
) -> Unit raise {
  let entries : Array[@symcore.Expr] = Array::new()
  for row in lhs.rows {
    for item in row {
      entries.push(item)
    }
  }
  assert_eq(entries.length(), rhs.length())
  for i in 0..<entries.length() {
    physics_assert_expr_equal(entries[i], rhs[i], "\{context}[\{i}]")
  }
}

///|
fn physics_dirac_c() -> @symcore.Expr {
  @symcore.number(
    try! @symnum.BigRational::new(
      @bigint.BigInt::from_string("137035999037"),
      @bigint.BigInt::from_int(1000000000),
    ),
  )
}

///|
fn physics_frac(num : Int, den : Int) -> @symcore.Expr {
  @symcore.number(
    try! @symnum.BigRational::new(
      @bigint.BigInt::from_int(num),
      @bigint.BigInt::from_int(den),
    ),
  )
}

///|
test "physics: matrices parity for Pauli, Dirac, PAT, and DFT" {
  for i in [1, 2, 3] {
    physics_assert_matrix_equiv(
      msigma(i),
      @sympy_physics.msigma(i),
      "msigma(\{i})",
    )
  }
  for mu in [0, 1, 2, 3, 5] {
    physics_assert_matrix_equiv(
      mgamma(mu),
      @sympy_physics.mgamma(mu),
      "mgamma(\{mu})",
    )
    physics_assert_matrix_equiv(
      mgamma(mu, lower=true),
      @sympy_physics.mgamma(mu, lower=true),
      "mgamma(\{mu}, lower=true)",
    )
  }

  let two = @symcore.int(2)
  physics_assert_matrix_equiv(
    pat_matrix(two, @symcore.int(1), @symcore.int(0), @symcore.int(0)),
    @sympy_physics.pat_matrix(
      two,
      @symcore.int(1),
      @symcore.int(0),
      @symcore.int(0),
    ),
    "pat_matrix",
  )
  physics_assert_matrix_equiv(
    minkowski_tensor,
    @sympy_physics.minkowski_tensor(),
    "minkowski_tensor",
  )
  for n in [1, 2, 4] {
    physics_assert_matrix_equiv(mdft(n), @sympy_physics.mdft(n), "mdft(\{n})")
  }
}

///|
test "physics: qho, sho, and pring parity" {
  let x = @symcore.symbol("x")
  let m = @symcore.symbol("m")
  let omega = @symcore.symbol("omega")
  let alpha = @symcore.symbol("alpha")
  for n in 0..<4 {
    physics_assert_expr_equal(
      psi_n(@symcore.int(n), x, m, omega),
      @sympy_physics.psi_n(@symcore.int(n), x, m, omega),
      "psi_n(\{n})",
    )
  }
  physics_assert_expr_equal(
    e_n(@symcore.symbol("n"), omega),
    @sympy_physics.e_n(@symcore.symbol("n"), omega),
    "E_n",
  )
  physics_assert_expr_equal(
    coherent_state(@symcore.int(3), alpha),
    @sympy_physics.coherent_state(@symcore.int(3), alpha),
    "coherent_state",
  )

  let r = @symcore.symbol("r")
  let nu = @symcore.symbol("nu")
  physics_assert_expr_equal(
    r_nl(@symcore.int(0), @symcore.int(0), nu, r),
    @sympy_physics.r_nl(@symcore.int(0), @symcore.int(0), nu, r),
    "R_nl",
  )
  physics_assert_expr_equal(
    e_nl(@symcore.symbol("n"), @symcore.symbol("l"), @symcore.symbol("hw")),
    @sympy_physics.e_nl(
      @symcore.symbol("n"),
      @symcore.symbol("l"),
      @symcore.symbol("hw"),
    ),
    "E_nl",
  )

  physics_assert_expr_equal(
    wavefunction(@symcore.int(2), x),
    @sympy_physics.wavefunction(@symcore.int(2), x),
    "pring.wavefunction",
  )
  physics_assert_expr_equal(
    energy(@symcore.int(2), m, r),
    @sympy_physics.energy(@symcore.int(2), m, r),
    "pring.energy",
  )
}

///|
test "physics: hydrogen parity" {
  let r = @symcore.symbol("r")
  let zsym = @symcore.symbol("Z")
  let phi = @symcore.symbol("phi")
  let theta = @symcore.symbol("theta")

  physics_assert_expr_equal(
    hydrogen_r_nl(@symcore.int(1), @symcore.int(0), r, z=zsym),
    @sympy_physics.hydrogen_r_nl(@symcore.int(1), @symcore.int(0), r, z=zsym),
    "hydrogen.R_nl(1,0)",
  )
  physics_assert_expr_equal(
    hydrogen_r_nl(@symcore.int(2), @symcore.int(1), r, z=zsym),
    @sympy_physics.hydrogen_r_nl(@symcore.int(2), @symcore.int(1), r, z=zsym),
    "hydrogen.R_nl(2,1)",
  )
  physics_assert_expr_equal(
    hydrogen_y_lm(@symcore.int(1), @symcore.int(0), phi, theta),
    @sympy_physics.hydrogen_y_lm(@symcore.int(1), @symcore.int(0), phi, theta),
    "hydrogen.Y_lm(1,0)",
  )
  physics_assert_expr_equal(
    hydrogen_y_lm(@symcore.int(2), @symcore.int(-1), phi, theta),
    @sympy_physics.hydrogen_y_lm(@symcore.int(2), @symcore.int(-1), phi, theta),
    "hydrogen.Y_lm(2,-1)",
  )
  physics_assert_expr_equal(
    hydrogen_z_lm(@symcore.int(2), @symcore.int(-1), phi, theta),
    @sympy_physics.hydrogen_z_lm(@symcore.int(2), @symcore.int(-1), phi, theta),
    "hydrogen.Z_lm(2,-1)",
  )
  physics_assert_expr_equal(
    hydrogen_psi_nlm(
      @symcore.int(2),
      @symcore.int(1),
      @symcore.int(1),
      r,
      phi,
      theta,
      z=zsym,
    ),
    @sympy_physics.hydrogen_psi_nlm(
      @symcore.int(2),
      @symcore.int(1),
      @symcore.int(1),
      r,
      phi,
      theta,
      z=zsym,
    ),
    "hydrogen.Psi_nlm(2,1,1)",
  )
  physics_assert_expr_equal(
    hydrogen_e_nl(@symcore.symbol("n"), z=zsym),
    @sympy_physics.hydrogen_e_nl(@symcore.symbol("n"), z=zsym),
    "hydrogen.E_nl",
  )
  let c = physics_dirac_c()
  physics_assert_expr_equal(
    hydrogen_e_nl_dirac(
      @symcore.int(2),
      @symcore.int(1),
      spin_up=false,
      z=zsym,
      c~,
    ),
    @sympy_physics.hydrogen_e_nl_dirac(
      @symcore.int(2),
      @symcore.int(1),
      spin_up=false,
      z=zsym,
      c~,
    ),
    "hydrogen.E_nl_dirac",
  )
}

///|
test "physics: wigner parity" {
  let half = physics_frac(1, 2)
  let three_half = physics_frac(3, 2)

  for
    case in [
      (
        @symcore.int(2),
        @symcore.int(6),
        @symcore.int(4),
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(0),
        "wigner_3j(2,6,4,0,0,0)",
      ),
      (
        @symcore.int(0),
        half,
        half,
        @symcore.int(0),
        half,
        @symcore.int(-1) * half,
        "wigner_3j(0,1/2,1/2,0,1/2,-1/2)",
      ),
      (
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(10),
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(0),
        "wigner_3j zero triangle",
      ),
    ] {
    let ours = wigner_3j(case.0, case.1, case.2, case.3, case.4, case.5)
    let oracle = @sympy_physics.wigner_3j(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
    )
    physics_assert_expr_equal(ours, oracle, case.6)
  }

  for
    case in [
      (
        three_half,
        half,
        @symcore.int(2),
        three_half,
        half,
        @symcore.int(2),
        "cg docs 1",
      ),
      (
        three_half,
        half,
        @symcore.int(1),
        three_half,
        @symcore.int(-1) * half,
        @symcore.int(1),
        "cg docs 2",
      ),
      (half, half, @symcore.int(1), half, half, @symcore.int(0), "cg zero"),
    ] {
    let ours = clebsch_gordan(case.0, case.1, case.2, case.3, case.4, case.5)
    let oracle = @sympy_physics.clebsch_gordan(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
    )
    physics_assert_expr_equal(ours, oracle, case.6)
  }
}

///|
test "physics: gaunt parity" {
  for
    case in [
      (
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(1),
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(-1),
        "gaunt(1,0,1,1,0,-1)",
      ),
      (
        @symcore.int(1),
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(-1),
        @symcore.int(1),
        @symcore.int(0),
        "gaunt(1,1,0,-1,1,0)",
      ),
      (
        @symcore.int(1),
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(2),
        @symcore.int(-2),
        "gaunt zero",
      ),
    ] {
    let ours = gaunt(case.0, case.1, case.2, case.3, case.4, case.5)
    let oracle = @sympy_physics.gaunt(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
    )
    physics_assert_expr_equal(ours, oracle, case.6)
  }
}

///|
test "physics: higher wigner parity" {
  let half = physics_frac(1, 2)
  for
    case in [
      (
        @symcore.int(5),
        @symcore.int(5),
        @symcore.int(5),
        @symcore.int(5),
        @symcore.int(5),
        @symcore.int(5),
        "wigner_6j(5,...,5)",
      ),
      (
        @symcore.int(2),
        @symcore.int(2),
        @symcore.int(2),
        physics_frac(3, 2),
        physics_frac(3, 2),
        physics_frac(3, 2),
        "wigner_6j zero mixed half",
      ),
    ] {
    let ours = wigner_6j(case.0, case.1, case.2, case.3, case.4, case.5)
    let oracle = @sympy_physics.wigner_6j(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
    )
    physics_assert_expr_equal(ours, oracle, case.6)
  }
  physics_assert_expr_equal(
    racah(
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
    ),
    @sympy_physics.racah(
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
      @symcore.int(3),
    ),
    "racah(3,...,3)",
  )
  for
    case in [
      (
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(0),
        half,
        half,
        @symcore.int(0),
        half,
        half,
        "wigner_9j half",
      ),
      (
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(3),
        @symcore.int(3),
        @symcore.int(2),
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(1),
        @symcore.int(3),
        "wigner_9j exact",
      ),
    ] {
    let ours = wigner_9j(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
      case.6,
      case.7,
      case.8,
    )
    let oracle = @sympy_physics.wigner_9j(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
      case.6,
      case.7,
      case.8,
    )
    physics_assert_expr_equal(ours, oracle, case.9)
  }
}

///|
test "physics: real gaunt parity" {
  for
    case in [
      (
        @symcore.int(1),
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(-1),
        @symcore.int(1),
        @symcore.int(-2),
        "real_gaunt(1,1,2,-1,1,-2)",
      ),
      (
        @symcore.int(2),
        @symcore.int(2),
        @symcore.int(2),
        @symcore.int(1),
        @symcore.int(1),
        @symcore.int(2),
        "real_gaunt(2,2,2,1,1,2)",
      ),
      (
        @symcore.int(-2),
        @symcore.int(1),
        @symcore.int(0),
        @symcore.int(1),
        @symcore.int(1),
        @symcore.int(1),
        "real_gaunt zero",
      ),
    ] {
    let ours = real_gaunt(case.0, case.1, case.2, case.3, case.4, case.5)
    let oracle = @sympy_physics.real_gaunt(
      case.0,
      case.1,
      case.2,
      case.3,
      case.4,
      case.5,
    )
    physics_assert_expr_equal(ours, oracle, case.6)
  }
}

///|
test "physics: rotational harmonic parity" {
  let theta = @symcore.symbol("theta")
  let phi = @symcore.symbol("phi")
  let half = physics_frac(1, 2)
  let alpha = @symcore.symbol("alpha")
  let beta = @symcore.symbol("beta")
  let gamma = @symcore.symbol("gamma")

  physics_assert_expr_equal(
    dot_rot_grad_ynm(
      @symcore.int(3),
      @symcore.int(2),
      @symcore.int(2),
      @symcore.int(0),
      theta,
      phi,
    ),
    @sympy_physics.dot_rot_grad_ynm(
      @symcore.int(3),
      @symcore.int(2),
      @symcore.int(2),
      @symcore.int(0),
      theta,
      phi,
    ),
    "dot_rot_grad_ynm(3,2,2,0)",
  )
  physics_assert_expr_equal(
    dot_rot_grad_ynm(
      @symcore.int(1),
      @symcore.int(5),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
    ),
    @sympy_physics.dot_rot_grad_ynm(
      @symcore.int(1),
      @symcore.int(5),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(2),
    ),
    "dot_rot_grad_ynm zero",
  )

  physics_assert_matrix_equiv(
    wigner_d_small(half, beta),
    @sympy_physics.wigner_d_small(half, beta),
    "wigner_d_small(1/2,beta)",
  )
  physics_assert_matrix_equiv(
    wigner_d_small(half, @symcore.symbol("pi") * physics_frac(1, 2)),
    @sympy_physics.wigner_d_small(
      half,
      @symcore.symbol("pi") * physics_frac(1, 2),
    ),
    "wigner_d_small(1/2,pi/2)",
  )
  physics_assert_matrix_equiv(
    wigner_d(half, alpha, beta, gamma),
    @sympy_physics.wigner_d(half, alpha, beta, gamma),
    "wigner_d(1/2,alpha,beta,gamma)",
  )
}
