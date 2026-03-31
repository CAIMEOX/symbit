///|
test "physics.quantum.spin: parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  quantum_test_assert_string_equal(
    quantum_qapply_str("Jz*JzKet(1, 1)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(@symcore.raw_mul([jz(), jz_ket(one, one).as_expr()])),
      ),
    ),
    "Jz qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("Jplus*JzKet(1, 0)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([jplus(), jz_ket(one, @symcore.int(0)).as_expr()]),
        ),
      ),
    ),
    "Jplus qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Dagger(Jplus)"),
    quantum_eval_str(@symprint.to_string(dagger(jplus()))),
    "spin dagger parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("Commutator(Jx, Jy).doit()"),
    quantum_eval_str(@symprint.to_string(commutator(jx(), jy()))),
    "spin commutator parity",
  )

  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jz(), spin_j=half),
    physics_eval_matrix("represent(Jz, j=Rational(1, 2))"),
    2,
    2,
    "represent Jz parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jplus(), spin_j=one),
    physics_eval_matrix("represent(Jplus, j=1)"),
    3,
    3,
    "represent Jplus parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jz_ket(one, @symcore.int(0)).as_expr()),
    physics_eval_matrix("represent(JzKet(1, 0))"),
    3,
    1,
    "represent JzKet parity",
  )
}

///|
test "physics.quantum.spin: rotation parity" {
  let alpha = @symcore.Expr::Symbol("alpha")
  let beta = @symcore.Expr::Symbol("beta")
  let gamma = @symcore.Expr::Symbol("gamma")

  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(dagger(rotation(alpha, beta, gamma).as_expr())),
    ),
    quantum_eval_str("Rotation(-gamma, -beta, -alpha)"),
    "rotation dagger parity",
  )
  quantum_test_assert_expr_equal(
    rotation_d(@symcore.int(1), @symcore.int(1), @symcore.int(0), beta).doit(),
    quantum_eval_str("Rotation.d(1, 1, 0, beta).doit()"),
    "rotation.d parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(
      rotation(
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi),
        @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Pi) *
        quantum_test_frac(1, 2),
        @symcore.int(0),
      ).as_expr(),
      spin_j=@symcore.int(1),
    ),
    physics_eval_matrix("represent(Rotation(pi, pi/2, 0), j=1)"),
    3,
    3,
    "rotation represent parity",
  )
}

///|
test "physics.quantum.spin: Jx/Jy basis parity" {
  let half = quantum_test_frac(1, 2)
  let one = @symcore.int(1)

  quantum_test_assert_string_equal(
    quantum_qapply_str("Jx*JxKet(1, 1)"),
    quantum_eval_str(
      physics_expr_str(
        qapply(@symcore.raw_mul([jx(), jx_ket(one, one).as_expr()])),
      ),
    ),
    "Jx eigen qapply parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str("Jz*JxKet(1, 1)"),
    quantum_eval_str(
      physics_expr_str(
        qapply(@symcore.raw_mul([jz(), jx_ket(one, one).as_expr()])),
      ),
    ),
    "Jz on JxKet parity",
  )
  quantum_test_assert_string_equal(
    physics_srepr("InnerProduct(JxBra(1, 1), JzKet(1, 1)).doit()"),
    physics_expr_srepr(
      inner_product(jx_bra(one, one).as_expr(), jz_ket(one, one).as_expr()),
    ),
    "spin cross inner-product parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jx_ket(half, half).as_expr(), basis=Some(jz())),
    physics_eval_matrix(
      "represent(JxKet(Rational(1, 2), Rational(1, 2)), basis=Jz)",
    ),
    2,
    1,
    "represent JxKet parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jy_ket(one, one).as_expr(), basis=Some(jz())),
    physics_eval_matrix("represent(JyKet(1, 1), basis=Jz)"),
    3,
    1,
    "represent JyKet parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(jz_ket(one, one).as_expr(), basis=Some(jx())),
    physics_eval_matrix("represent(JzKet(1, 1), basis=Jx)"),
    3,
    1,
    "represent JzKet in Jx basis parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("JzKet(1, 1)/2 + sqrt(2)*JzKet(1, 0)/2 + JzKet(1, -1)/2"),
    quantum_eval_str(physics_expr_str(jx_ket(one, one).rewrite(jz()))),
    "rewrite JxKet parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("-I*JxKet(1, 1)"),
    quantum_eval_str(physics_expr_str(jy_ket(one, one).rewrite(jx()))),
    "rewrite JyKet parity",
  )
}

///|
test "physics.quantum.spin: coupled Jz parity" {
  let half = quantum_test_frac(1, 2)
  let zero = @symcore.int(0)
  let one = @symcore.int(1)
  let minus_half = quantum_test_frac(-1, 2)
  let j = @symcore.Expr::Symbol("j")
  let m = @symcore.Expr::Symbol("m")
  let j1v = @symcore.Expr::Symbol("j1")
  let j2v = @symcore.Expr::Symbol("j2")
  let j3v = @symcore.Expr::Symbol("j3")
  let j4v = @symcore.Expr::Symbol("j4")
  let m1 = @symcore.Expr::Symbol("m1")
  let m2 = @symcore.Expr::Symbol("m2")
  let m3 = @symcore.Expr::Symbol("m3")
  let m4 = @symcore.Expr::Symbol("m4")
  let j13 = @symcore.Expr::Symbol("j13")
  let j24 = @symcore.Expr::Symbol("j24")

  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "Jplus*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))",
    ),
    quantum_eval_str(
      physics_expr_str(
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
  quantum_test_assert_string_equal(
    quantum_eval_str(
      "uncouple(JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2))))",
    ),
    quantum_eval_str(
      physics_expr_str(
        uncouple(jz_ket_coupled(one, zero, [half, half]).as_expr()),
      ),
    ),
    "uncouple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("hbar**2*j*(j + 1)*JzKetCoupled(j, m, (j1, j2))"),
    quantum_eval_str(
      physics_expr_str(
        qapply(
          @symcore.raw_mul([j2(), jz_ket_coupled(j, m, [j1v, j2v]).as_expr()]),
        ),
      ),
    ),
    "J2 on symbolic JzKetCoupled parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      "couple(TensorProduct(JzKet(Rational(1, 2), Rational(1, 2)), JzKet(Rational(1, 2), Rational(-1, 2))))",
    ),
    quantum_eval_str(
      physics_expr_str(
        couple(
          @symquant.tensor_product([
            jz_ket(half, half).as_expr(),
            jz_ket(half, minus_half).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    "couple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("couple(TensorProduct(JzKet(j1, m1), JzKet(j2, m2)))"),
    quantum_eval_str(
      physics_expr_str(
        couple(
          @symquant.tensor_product([
            jz_ket(j1v, m1).as_expr(),
            jz_ket(j2v, m2).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    "symbolic couple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("uncouple(JzKetCoupled(j, m, (j1, j2)))"),
    quantum_eval_str(
      physics_expr_str(uncouple(jz_ket_coupled(j, m, [j1v, j2v]).as_expr())),
    ),
    "symbolic uncouple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      "couple(TensorProduct(JzKet(j1, m1), JzKet(j2, m2), JzKet(j3, m3)))",
    ),
    quantum_eval_str(
      physics_expr_str(
        couple(
          @symquant.tensor_product([
            jz_ket(j1v, m1).as_expr(),
            jz_ket(j2v, m2).as_expr(),
            jz_ket(j3v, m3).as_expr(),
          ]).as_expr(),
        ),
      ),
    ),
    "symbolic three-spin couple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      "couple(TensorProduct(JzKet(j1, m1), JzKet(j2, m2), JzKet(j3, m3), JzKet(j4, m4)), ((1, 3), (2, 4), (1, 2)))",
    ),
    quantum_eval_str(
      physics_expr_str(
        couple(
          @symquant.tensor_product([
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
    "symbolic four-spin custom couple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str("uncouple(JzKetCoupled(j, m, (j1, j2, j3)))"),
    quantum_eval_str(
      physics_expr_str(
        uncouple(jz_ket_coupled(j, m, [j1v, j2v, j3v]).as_expr()),
      ),
    ),
    "symbolic three-spin uncouple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      "uncouple(JzKetCoupled(j, m, (j1, j2, j3, j4), ((1, 3, j13), (2, 4, j24), (1, 2, j))))",
    ),
    quantum_eval_str(
      physics_expr_str(
        uncouple(
          jz_ket_coupled(j, m, [j1v, j2v, j3v, j4v], coupling=[
            spin_coupling(1, 3, j13),
            spin_coupling(2, 4, j24),
            spin_coupling(1, 2, j),
          ]).as_expr(),
        ),
      ),
    ),
    "symbolic four-spin custom uncouple parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(
      jx_ket_coupled(one, one, [half, half]).as_expr(),
      basis=Some(jz()),
    ),
    quantum_represent_matrix(
      "JxKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))", "Jz", 4,
    ),
    4,
    1,
    "represent JxKetCoupled parity",
  )
  quantum_test_assert_matrix_expr_equal(
    represent_matrix(
      jz_ket_coupled(one, zero, [half, half]).as_expr(),
      basis=Some(jx()),
    ),
    quantum_represent_matrix(
      "JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))", "Jx", 4,
    ),
    4,
    1,
    "represent JzKetCoupled in Jx basis parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      "JzKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))/2 + sqrt(2)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))/2 + JzKetCoupled(1, -1, (Rational(1, 2), Rational(1, 2)))/2",
    ),
    quantum_eval_str(
      physics_expr_str(jx_ket_coupled(one, one, [half, half]).rewrite(jz())),
    ),
    "rewrite JxKetCoupled parity",
  )
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "Jplus*JxKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    quantum_eval_str(
      physics_expr_str(
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
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "Jplus*JyKetCoupled(1, 1, (Rational(1, 2), Rational(1, 2)))",
    ),
    quantum_eval_str(
      physics_expr_str(
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
  quantum_test_assert_string_equal(
    quantum_qapply_str(
      "Rotation(0, 0, 0)*JzKetCoupled(1, 0, (Rational(1, 2), Rational(1, 2)))",
    ),
    quantum_eval_str(
      physics_expr_str(
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
