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

///|
test "physics.quantum.spin: local Jx/Jy bases" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  inspect(jx_ket(one, @symcore.int(1)).to_string(), content="|1,1>")
  inspect(jy_bra(one, @symcore.int(-1)).to_string(), content="<1,-1|")

  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jx(), jx_ket(one, @symcore.int(1)).as_expr()])),
    "hbar*JxKet(1, 1)",
    "Jx eigen action",
  )
  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jz(), jx_ket(one, @symcore.int(1)).as_expr()])),
    "-sqrt(2)*hbar*JxKet(1, 0)/2",
    "Jz on JxKet",
  )
  try! quantum_test_assert_expr_equal(
    inner_product(
      jx_bra(one, @symcore.int(1)).as_expr(),
      jz_ket(one, @symcore.int(1)).as_expr(),
    ),
    "1/2",
    "JxBra/JzKet inner product",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jx_ket(half, half).as_expr(), basis=Some(jz())),
    ["sqrt(2)/2", "sqrt(2)/2"],
    2,
    1,
    "represent JxKet in Jz basis",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      jy_ket(one, @symcore.int(1)).as_expr(),
      basis=Some(jz()),
    ),
    ["1/2", "sqrt(2)*I/2", "-1/2"],
    3,
    1,
    "represent JyKet in Jz basis",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jx(), basis=Some(jx()), spin_j=one),
    ["hbar", "0", "0", "0", "0", "0", "0", "0", "-hbar"],
    3,
    3,
    "represent Jx in Jx basis",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(jx_ket(one, one).rewrite(jz())),
    ),
    try! @sympy_physics.quantum_eval_str(
      "JzKet(1, 1)/2 + sqrt(2)*JzKet(1, 0)/2 + JzKet(1, -1)/2",
    ),
    "rewrite JxKet to Jz",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(jy_ket(one, one).rewrite(jx())),
    ),
    try! @sympy_physics.quantum_eval_str("-I*JxKet(1, 1)"),
    "rewrite JyKet to Jx",
  )
}

///|
test "physics.quantum.spin: local coupled Jz states" {
  let half = quantum_test_frac(1, 2)
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let minus_half = quantum_test_frac(-1, 2)
  let coupled = jz_ket_coupled(one, zero, [half, half])
  let x_coupled = jx_ket_coupled(one, one, [half, half])
  let y_coupled = jy_ket_coupled(one, one, [half, half])

  inspect(coupled.to_string(), content="|1,0,j1=1/2,j2=1/2>")

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "sqrt(2)*hbar*JzKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jplus(), coupled.as_expr()])),
      ),
    ),
    "Jplus on JzKetCoupled",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "sqrt(2)*TensorProduct(JzKet(Rational(1, 2), Rational(-1, 2)), JzKet(Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*TensorProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzKet(Rational(1, 2), Rational(-1, 2)))/2",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(uncouple(coupled.as_expr())),
    ),
    "uncouple spin-half triplet",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        couple(
          tensor_product([
            jz_ket(half, half).as_expr(),
            jz_ket(half, minus_half).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    try! @sympy_physics.quantum_eval_str(
      "sqrt(2)*JzKetCoupled(0, 0, (Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2",
    ),
    "couple spin-half product",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(x_coupled.as_expr(), basis=Some(jz())),
    ["0", "1/2", "sqrt(2)/2", "1/2"],
    4,
    1,
    "represent JxKetCoupled in Jz basis",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "JzKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + JzKetCoupled(1, -1, (Rational(1, 2), Rational(1, 2)))/2",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(x_coupled.rewrite(jz())),
    ),
    "rewrite JxKetCoupled to Jz",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "-sqrt(2)*hbar*JxKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + hbar*JxKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jplus(), x_coupled.as_expr()])),
      ),
    ),
    "Jplus on JxKetCoupled",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "sqrt(2)*hbar*JyKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + I*hbar*JyKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jplus(), y_coupled.as_expr()])),
      ),
    ),
    "Jplus on JyKetCoupled",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(
          @symcore.raw_mul([
            rotation(@symcore.int(0), @symcore.int(0), @symcore.int(0)).as_expr(),
            coupled.as_expr(),
          ]),
        ),
      ),
    ),
    "identity rotation on JzKetCoupled",
  )
}
