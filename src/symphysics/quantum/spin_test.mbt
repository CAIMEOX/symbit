///|
test "physics.quantum.spin: local uncoupled Jz basis" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  inspect(jz_ket(one, @symcore.int(0)).to_string(), content="|1,0>")
  inspect(jz_bra(one, @symcore.int(-1)).to_string(), content="<1,-1|")
  inspect(@symprint.to_string(dagger(jplus())), content="Dagger(Jplus)")
  inspect(
    @symprint.to_string(dagger(jz_ket(one, @symcore.int(0)).as_expr())),
    content="JzBra(1, 0)",
  )

  let (_, half_vals) = try! m_values(half)
  inspect(half_vals.map(@symprint.to_string).join(","), content="1/2,-1/2")

  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jz(), jz_ket(one, @symcore.int(1)).as_expr()])),
    "hbar*JzKet(1, 1)",
    "Jz action",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jplus(), jz_ket(one, @symcore.int(0)).as_expr()])),
    "sqrt(2)*hbar*JzKet(1, 1)",
    "Jplus action",
  )
  try! quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([jx(), jz_ket(half, quantum_test_frac(-1, 2)).as_expr()]),
    ),
    "hbar/2*JzKet(1/2, 1/2)",
    "Jx action on spin-half",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz(), spin_j=half),
    ["hbar/2", "0", "0", "-hbar/2"],
    2,
    2,
    "represent Jz",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz_ket(one, @symcore.int(0)).as_expr()),
    ["0", "1", "0"],
    3,
    1,
    "represent JzKet",
  )
}

///|
test "physics.quantum.spin: local rotations and Wigner D" {
  let alpha = @symcore.symbol("alpha")
  let beta = @symcore.symbol("beta")
  let gamma = @symcore.symbol("gamma")

  inspect(
    rotation(alpha, beta, gamma).to_string(),
    content="R(alpha,beta,gamma)",
  )
  inspect(
    rotation_d(@symcore.int(1), @symcore.int(1), @symcore.int(0), beta).to_string(),
    content="d(1,1,0,beta)",
  )

  try! quantum_test_assert_expr_equal(
    dagger(rotation(alpha, beta, gamma).as_expr()),
    "Rotation(-gamma, -beta, -alpha)",
    "rotation dagger",
  )
  let wigner_d_value = @symprint.to_string(
    try! rotation_d(
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(0),
      @symcore.symbol("pi") * quantum_test_frac(1, 2),
    ).doit(),
  )
  guard (try! @sympy_physics.expr_equal(wigner_d_value, "-sqrt(2)/2")) else {
    fail("Wigner d doit: \{wigner_d_value}")
  }
  try! quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        rotation(@symcore.int(0), @symcore.int(0), @symcore.int(0)).as_expr(),
        jz_ket(@symcore.int(1), @symcore.int(1)).as_expr(),
      ]),
    ),
    "JzKet(1, 1)",
    "rotation identity action",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      rotation(@symcore.int(0), @symcore.int(0), @symcore.int(0)).as_expr(),
      spin_j=@symcore.int(1),
    ),
    ["1", "0", "0", "0", "1", "0", "0", "0", "1"],
    3,
    3,
    "rotation identity matrix",
  )
}
