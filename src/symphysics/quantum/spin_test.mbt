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

  let (_, half_vals) = m_values(half)
  inspect(half_vals.map(@symprint.to_string).join(","), content="1/2,-1/2")

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jz(), jz_ket(one, @symcore.int(1)).as_expr()])),
    "hbar*JzKet(1, 1)",
    "Jz action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jplus(), jz_ket(one, @symcore.int(0)).as_expr()])),
    "sqrt(2)*hbar*JzKet(1, 1)",
    "Jplus action",
  )
  quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([jx(), jz_ket(half, quantum_test_frac(-1, 2)).as_expr()]),
    ),
    "hbar/2*JzKet(1/2, 1/2)",
    "Jx action on spin-half",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jz(), spin_j=half),
    ["hbar/2", "0", "0", "-hbar/2"],
    2,
    2,
    "represent Jz",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jz_ket(one, @symcore.int(0)).as_expr()),
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

  quantum_test_assert_expr_equal(
    dagger(rotation(alpha, beta, gamma).as_expr()),
    "Rotation(-gamma, -beta, -alpha)",
    "rotation dagger",
  )
  let wigner_d_value = @symprint.to_string(
    rotation_d(
      @symcore.int(1),
      @symcore.int(1),
      @symcore.int(0),
      @symcore.symbol("pi") * quantum_test_frac(1, 2),
    ).doit(),
  )
  guard @sympy_physics.expr_equal(wigner_d_value, "-sqrt(2)/2") else {
    fail("Wigner d doit: \{wigner_d_value}")
  }
  quantum_test_assert_expr_equal(
    qapply(
      @symcore.raw_mul([
        rotation(@symcore.int(0), @symcore.int(0), @symcore.int(0)).as_expr(),
        jz_ket(@symcore.int(1), @symcore.int(1)).as_expr(),
      ]),
    ),
    "JzKet(1, 1)",
    "rotation identity action",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(
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

  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jx(), jx_ket(one, @symcore.int(1)).as_expr()])),
    "hbar*JxKet(1, 1)",
    "Jx eigen action",
  )
  quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([jz(), jx_ket(one, @symcore.int(1)).as_expr()])),
    "-sqrt(2)*hbar*JxKet(1, 0)/2",
    "Jz on JxKet",
  )
  quantum_test_assert_expr_equal(
    inner_product(
      jx_bra(one, @symcore.int(1)).as_expr(),
      jz_ket(one, @symcore.int(1)).as_expr(),
    ),
    "1/2",
    "JxBra/JzKet inner product",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jx_ket(half, half).as_expr(), basis=Some(jz())),
    ["sqrt(2)/2", "sqrt(2)/2"],
    2,
    1,
    "represent JxKet in Jz basis",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jy_ket(one, @symcore.int(1)).as_expr(), basis=Some(jz())),
    ["1/2", "sqrt(2)*I/2", "-1/2"],
    3,
    1,
    "represent JyKet in Jz basis",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jx(), basis=Some(jx()), spin_j=one),
    ["hbar", "0", "0", "0", "0", "0", "0", "0", "-hbar"],
    3,
    3,
    "represent Jx in Jx basis",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(jx_ket(one, one).rewrite(jz())),
    ),
    @sympy_physics.quantum_eval_str(
      "JzKet(1, 1)/2 + sqrt(2)*JzKet(1, 0)/2 + JzKet(1, -1)/2",
    ),
    "rewrite JxKet to Jz",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @symprint.to_string(jy_ket(one, one).rewrite(jx())),
    ),
    @sympy_physics.quantum_eval_str("-I*JxKet(1, 1)"),
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

  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      "sqrt(2)*hbar*JzKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jplus(), coupled.as_expr()])),
      ),
    ),
    "Jplus on JzKetCoupled",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      "sqrt(2)*TensorProduct(JzKet(Rational(1, 2), Rational(-1, 2)), JzKet(Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*TensorProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzKet(Rational(1, 2), Rational(-1, 2)))/2",
    ),
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(uncouple(coupled.as_expr())),
    ),
    "uncouple spin-half triplet",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        couple(
          tensor_product([
            jz_ket(half, half).as_expr(),
            jz_ket(half, minus_half).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "sqrt(2)*JzKetCoupled(0, 0, (Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2",
    ),
    "couple spin-half product",
  )
  let j = @symcore.symbol("j")
  let m = @symcore.symbol("m")
  let j1v = @symcore.symbol("j1")
  let j2v = @symcore.symbol("j2")
  let j3v = @symcore.symbol("j3")
  let j4v = @symcore.symbol("j4")
  let m1 = @symcore.symbol("m1")
  let m2 = @symcore.symbol("m2")
  let m3 = @symcore.symbol("m3")
  let m4 = @symcore.symbol("m4")
  let j13 = @symcore.symbol("j13")
  let j24 = @symcore.symbol("j24")
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        couple(
          tensor_product([
            jz_ket(j1v, m1).as_expr(),
            jz_ket(j2v, m2).as_expr(),
            jz_ket(j3v, m3).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "Sum(CG(j1, m1, j2, m2, j12, m1 + m2)*CG(j12, m1 + m2, j3, m3, j, m1 + m2 + m3)*JzKetCoupled(j, m1 + m2 + m3, (j1, j2, j3), ((1, 2, j12), (1, 3, j))), (j12, m1 + m2, j1 + j2), (j, m1 + m2 + m3, j12 + j3))",
    ),
    "symbolic three-spin couple",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        couple(
          tensor_product([
            jz_ket(j1v, m1).as_expr(),
            jz_ket(j2v, m2).as_expr(),
            jz_ket(j3v, m3).as_expr(),
            jz_ket(j4v, m4).as_expr(),
          ]).as_expr(),
          orders=[
            spin_couple_order(1, 3),
            spin_couple_order(2, 4),
            spin_couple_order(1, 2),
          ],
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "Sum(CG(j1, m1, j3, m3, j13, m1 + m3)*CG(j2, m2, j4, m4, j24, m2 + m4)*CG(j13, m1 + m3, j24, m2 + m4, j, m1 + m2 + m3 + m4)*JzKetCoupled(j, m1 + m2 + m3 + m4, (j1, j2, j3, j4), ((1, 3, j13), (2, 4, j24), (1, 2, j))), (j13, m1 + m3, j1 + j3), (j24, m2 + m4, j2 + j4), (j, m1 + m2 + m3 + m4, j13 + j24))",
    ),
    "symbolic four-spin custom couple",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        uncouple(jz_ket_coupled(j, m, [j1v, j2v, j3v]).as_expr()),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "Sum(CG(j1, m1, j2, m2, j1 + j2, m1 + m2)*CG(j1 + j2, m1 + m2, j3, m3, j, m)*TensorProduct(JzKet(j1, m1), JzKet(j2, m2), JzKet(j3, m3)), (m1, -j1, j1), (m2, -j2, j2), (m3, -j3, j3))",
    ),
    "symbolic three-spin uncouple",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        uncouple(
          jz_ket_coupled(j, m, [j1v, j2v, j3v, j4v], coupling=[
            spin_coupling(1, 3, j13),
            spin_coupling(2, 4, j24),
            spin_coupling(1, 2, j),
          ]).as_expr(),
        ),
      ),
    ),
    @sympy_physics.quantum_eval_str(
      "Sum(CG(j1, m1, j3, m3, j13, m1 + m3)*CG(j2, m2, j4, m4, j24, m2 + m4)*CG(j13, m1 + m3, j24, m2 + m4, j, m)*TensorProduct(JzKet(j1, m1), JzKet(j2, m2), JzKet(j3, m3), JzKet(j4, m4)), (m1, -j1, j1), (m2, -j2, j2), (m3, -j3, j3), (m4, -j4, j4))",
    ),
    "symbolic four-spin custom uncouple",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(x_coupled.as_expr(), basis=Some(jz())),
    ["0", "1/2", "sqrt(2)/2", "1/2"],
    4,
    1,
    "represent JxKetCoupled in Jz basis",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      "JzKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + JzKetCoupled(1, -1, (Rational(1, 2), Rational(1, 2)))/2",
    ),
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(x_coupled.rewrite(jz())),
    ),
    "rewrite JxKetCoupled to Jz",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      "-sqrt(2)*hbar*JxKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + hbar*JxKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jplus(), x_coupled.as_expr()])),
      ),
    ),
    "Jplus on JxKetCoupled",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      "sqrt(2)*hbar*JyKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + I*hbar*JyKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
        qapply(@symcore.raw_mul([jplus(), y_coupled.as_expr()])),
      ),
    ),
    "Jplus on JyKetCoupled",
  )
  quantum_test_assert_string_equal(
    @sympy_physics.quantum_eval_str(
      "JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))",
    ),
    @sympy_physics.quantum_eval_str(
      @sympy_physics.physics_expr_str(
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
