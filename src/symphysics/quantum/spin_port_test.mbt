///|
test "physics.quantum.spin: parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("Jz*JzKet(1, 1)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([jz(), jz_ket(one, one).as_expr()])),
      ),
    ),
    "Jz qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("Jplus*JzKet(1, 0)"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([jplus(), jz_ket(one, @symcore.int(0)).as_expr()]),
        ),
      ),
    ),
    "Jplus qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Dagger(Jplus)"),
    try! @sympy_physics.quantum_eval_str(@symprint.to_string(dagger(jplus()))),
    "spin dagger parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("Commutator(Jx, Jy).doit()"),
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(commutator(jx(), jy())),
    ),
    "spin commutator parity",
  )

  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz(), spin_j=half),
    try! @sympy_physics.physics_eval_matrix("represent(Jz, j=Rational(1, 2))"),
    2,
    2,
    "represent Jz parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jplus(), spin_j=one),
    try! @sympy_physics.physics_eval_matrix("represent(Jplus, j=1)"),
    3,
    3,
    "represent Jplus parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz_ket(one, @symcore.int(0)).as_expr()),
    try! @sympy_physics.physics_eval_matrix("represent(JzKet(1, 0))"),
    3,
    1,
    "represent JzKet parity",
  )
}

///|
test "physics.quantum.spin: rotation parity" {
  let alpha = @symcore.symbol("alpha")
  let beta = @symcore.symbol("beta")
  let gamma = @symcore.symbol("gamma")

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      @symprint.to_string(dagger(rotation(alpha, beta, gamma).as_expr())),
    ),
    try! @sympy_physics.quantum_eval_str("Rotation(-gamma, -beta, -alpha)"),
    "rotation dagger parity",
  )
  try! quantum_test_assert_expr_equal(
    try! rotation_d(@symcore.int(1), @symcore.int(1), @symcore.int(0), beta).doit(),
    try! @sympy_physics.quantum_eval_str("Rotation.d(1, 1, 0, beta).doit()"),
    "rotation.d parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      rotation(
        @symcore.symbol("pi"),
        @symcore.symbol("pi") * quantum_test_frac(1, 2),
        @symcore.int(0),
      ).as_expr(),
      spin_j=@symcore.int(1),
    ),
    try! @sympy_physics.physics_eval_matrix(
      "represent(Rotation(pi, pi/2, 0), j=1)",
    ),
    3,
    3,
    "rotation represent parity",
  )
}

///|
test "physics.quantum.spin: Jx/Jy basis parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("Jx*JxKet(1, 1)"),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jx(), jx_ket(one, one).as_expr()])),
      ),
    ),
    "Jx eigen qapply parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str("Jz*JxKet(1, 1)"),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jz(), jx_ket(one, one).as_expr()])),
      ),
    ),
    "Jz on JxKet parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.physics_srepr(
      "InnerProduct(JxBra(1, 1), JzKet(1, 1)).doit()",
    ),
    try! @sympy_physics.physics_expr_srepr(
      inner_product(jx_bra(one, one).as_expr(), jz_ket(one, one).as_expr()),
    ),
    "spin cross inner-product parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jx_ket(half, half).as_expr(), basis=Some(jz())),
    try! @sympy_physics.physics_eval_matrix(
      "represent(JxKet(Rational(1, 2), Rational(1, 2)), basis=Jz)",
    ),
    2,
    1,
    "represent JxKet parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jy_ket(one, one).as_expr(), basis=Some(jz())),
    try! @sympy_physics.physics_eval_matrix("represent(JyKet(1, 1), basis=Jz)"),
    3,
    1,
    "represent JyKet parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(jz_ket(one, one).as_expr(), basis=Some(jx())),
    try! @sympy_physics.physics_eval_matrix("represent(JzKet(1, 1), basis=Jx)"),
    3,
    1,
    "represent JzKet in Jx basis parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "JzKet(1, 1)/2 + sqrt(2)*JzKet(1, 0)/2 + JzKet(1, -1)/2",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(jx_ket(one, one).rewrite(jz())),
    ),
    "rewrite JxKet parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str("-I*JxKet(1, 1)"),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(jy_ket(one, one).rewrite(jx())),
    ),
    "rewrite JyKet parity",
  )
}

///|
test "physics.quantum.spin: coupled Jz parity" {
  let half = quantum_test_frac(1, 2)
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let minus_half = quantum_test_frac(-1, 2)
  let j = @symcore.symbol("j")
  let m = @symcore.symbol("m")
  let j1v = @symcore.symbol("j1")
  let j2v = @symcore.symbol("j2")
  let m1 = @symcore.symbol("m1")
  let m2 = @symcore.symbol("m2")

  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "Jplus*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(
          @symcore.raw_mul([
            jplus(),
            jz_ket_coupled(one, zero, [half, half]).as_expr(),
          ]),
        ),
      ),
    ),
    "Jplus on JzKetCoupled parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "uncouple(JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2))))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        uncouple(jz_ket_coupled(one, zero, [half, half]).as_expr()),
      ),
    ),
    "uncouple parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "hbar**2*j*(j + 1)*JzKetCoupled(j, m, (j1, j2))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(
          @symcore.raw_mul([j2(), jz_ket_coupled(j, m, [j1v, j2v]).as_expr()]),
        ),
      ),
    ),
    "J2 on symbolic JzKetCoupled parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "couple(TensorProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzKet(Rational(1, 2), Rational(-1, 2))))",
    ),
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
    "couple parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "couple(TensorProduct(JzKet(j1, m1), JzKet(j2, m2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        couple(
          tensor_product([jz_ket(j1v, m1).as_expr(), jz_ket(j2v, m2).as_expr()]).as_expr(),
        ),
      ),
    ),
    "symbolic couple parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "uncouple(JzKetCoupled(j, m, (j1, j2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        uncouple(jz_ket_coupled(j, m, [j1v, j2v]).as_expr()),
      ),
    ),
    "symbolic uncouple parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      jx_ket_coupled(one, one, [half, half]).as_expr(),
      basis=Some(jz()),
    ),
    try! @sympy_physics.quantum_represent_matrix(
      "JxKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))", "Jz", 4,
    ),
    4,
    1,
    "represent JxKetCoupled parity",
  )
  try! quantum_test_assert_matrix_expr_equal(
    try! represent_matrix(
      jz_ket_coupled(one, zero, [half, half]).as_expr(),
      basis=Some(jx()),
    ),
    try! @sympy_physics.quantum_represent_matrix(
      "JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))", "Jx", 4,
    ),
    4,
    1,
    "represent JzKetCoupled in Jx basis parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_eval_str(
      "JzKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + JzKetCoupled(1, -1, (Rational(1, 2), Rational(1, 2)))/2",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        jx_ket_coupled(one, one, [half, half]).rewrite(jz()),
      ),
    ),
    "rewrite JxKetCoupled parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "Jplus*JxKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(
          @symcore.raw_mul([
            jplus(),
            jx_ket_coupled(one, one, [half, half]).as_expr(),
          ]),
        ),
      ),
    ),
    "Jplus on JxKetCoupled parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "Jplus*JyKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(
          @symcore.raw_mul([
            jplus(),
            jy_ket_coupled(one, one, [half, half]).as_expr(),
          ]),
        ),
      ),
    ),
    "Jplus on JyKetCoupled parity",
  )
  try! quantum_test_assert_string_equal(
    try! @sympy_physics.quantum_qapply_str(
      "Rotation(0, 0, 0)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))",
    ),
    try! @sympy_physics.quantum_eval_str(
      try! @sympy_physics.physics_expr_str(
        qapply(
          @symcore.raw_mul([
            rotation(@symcore.int(0), @symcore.int(0), @symcore.int(0)).as_expr(),
            jz_ket_coupled(one, zero, [half, half]).as_expr(),
          ]),
        ),
      ),
    ),
    "identity rotation on JzKetCoupled parity",
  )
}
