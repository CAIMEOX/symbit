///|
test "field_elem: expect_rational projects constant extensions" {
  let cc = FieldElem::CC(
    @symnum.BigRational::from_int(3),
    @symnum.BigRational::zero(),
  )
  inspect(fe_expect_rational(cc), content="3")

  let gf_const = FieldElem::GFExt(5, [7], [1, 0, 1])
  inspect(fe_expect_rational(gf_const), content="7")

  let a = @symcore.Expr::Symbol("a")
  let minpoly = PolyBuilder::new(["a"], QQ).from_expr(
    (a ^ @symcore.int(2)) + @symcore.int(1),
  )
  let alg_const = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::from_int(5))],
    minpoly,
    "a",
  )
  inspect(fe_expect_rational(alg_const), content="5")
}

///|
test "field_elem: expect_rational rejects non-constant extensions" {
  let gf_non_const = FieldElem::GFExt(5, [1, 1], [1, 0, 1])
  sympolys_assert_error(
    fn() raise PolyError { fe_expect_rational(gf_non_const) },
    "DomainMismatch",
  )

  let a = @symcore.Expr::Symbol("a")
  let minpoly = PolyBuilder::new(["a"], QQ).from_expr(
    (a ^ @symcore.int(2)) + @symcore.int(1),
  )
  let alg_non_const = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::one()), QQ(@symnum.BigRational::one())],
    minpoly,
    "a",
  )
  sympolys_assert_error(
    fn() raise PolyError { fe_expect_rational(alg_non_const) },
    "DomainMismatch",
  )
}

///|
test "field_elem: from_int embeds into Frac(base)" {
  let q = fe_from_int(4, Frac(QQ))
  inspect(q, content="4")

  let gf = fe_from_int(-3, Frac(GF(5)))
  inspect(gf, content="2")
}

///|
fn fe_wb_rat(num : Int, den : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => abort("whitebox test rational expects a nonzero denominator")
  }
}

///|
fn fe_wb_qq(num : Int, den : Int) -> FieldElem {
  QQ(fe_wb_rat(num, den))
}

///|
fn fe_wb_minpoly(
  gen : String,
  expr : @symcore.Expr,
  base : Domain,
) -> Poly raise PolyError {
  PolyBuilder::new([gen], base).from_expr(expr)
}

///|
test "field_elem wb: helper branches and domain mismatches" {
  let trimmed = fe_trim([], 5).map(item => item.to_string()).join(", ")
  inspect("[\{trimmed}]", content="[0]")
  inspect(fe_mod_inv_int(2, 4), content="0")

  let pow_neg = fe_pow(
    CC(@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(0)),
    -1,
  )
  inspect(pow_neg, content="1/2")

  sympolys_assert_error(
    fn() raise PolyError { fe_add(GFp(5, 1), GFp(7, 1)) },
    "DomainMismatch",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      fe_add(GFExt(5, [1], [1, 0, 1]), GFExt(5, [1], [1, 1, 1]))
    },
    "DomainMismatch",
  )

  let a = @symcore.Expr::Symbol("a")
  let minpoly = fe_wb_minpoly("a", (a ^ @symcore.int(2)) + @symcore.int(1), QQ)
  let alg1 = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::one())],
    minpoly,
    "a",
  )
  let alg2 = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::one())],
    minpoly,
    "b",
  )
  sympolys_assert_error(
    fn() raise PolyError { fe_add(alg1, alg2) },
    "DomainMismatch",
  )
  sympolys_assert_error(
    fn() raise PolyError { fe_mul(alg1, alg2) },
    "DomainMismatch",
  )
}

///|
test "field_elem wb: inverses and conversion guard paths" {
  sympolys_assert_error(
    fn() raise PolyError { fe_inv(QQ(@symnum.BigRational::zero())) },
    "DivisionByZero",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      fe_inv(CC(@symnum.BigRational::zero(), @symnum.BigRational::zero()))
    },
    "DivisionByZero",
  )

  sympolys_assert_error(
    fn() raise PolyError { fe_inv(GFp(5, 0)) },
    "DivisionByZero",
  )

  sympolys_assert_error(
    fn() raise PolyError { fe_inv(GFExt(5, [0], [1, 0, 1])) },
    "DivisionByZero",
  )

  let x = @symcore.Expr::Symbol("x")
  let minpoly = fe_wb_minpoly("x", x ^ @symcore.int(2), QQ)
  sympolys_assert_error(
    fn() raise PolyError {
      fe_alg_poly_inv(
        [QQ(@symnum.BigRational::zero()), QQ(@symnum.BigRational::one())],
        minpoly,
      )
    },
    "DomainNotField",
  )

  sympolys_assert_error(
    fn() raise PolyError { fe_from_rational(fe_wb_rat(1, 2), ZZ) },
    "CoefficientNotInteger",
  )

  let frac_gf = fe_from_rational(fe_wb_rat(8, 3), Frac(GF(7)))
  inspect(frac_gf, content="5")

  sympolys_assert_error(
    fn() raise PolyError {
      load_algext_minpoly(QQ, ["a", "b"], [@symcore.int(1)])
    },
    "BadGenerator(algext)",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      load_algext_minpoly(ZZ, ["a"], [Symbol("a") + @symcore.int(1)])
    },
    "DomainNotField",
  )

  sympolys_assert_error(
    fn() raise PolyError { load_algext_minpoly(QQ, ["a"], [@symcore.int(1)]) },
    "BadExponent",
  )
}

///|
test "field_elem wb: algebraic helpers and string formatting branches" {
  let a = @symcore.Expr::Symbol("a")
  let minpoly = fe_wb_minpoly("a", (a ^ @symcore.int(2)) + @symcore.int(1), QQ)

  let add_res = fe_alg_poly_add([fe_wb_qq(1, 1), fe_wb_qq(1, 1)], [
    fe_wb_qq(2, 1),
  ])
  assert_true(add_res.length() == 2 && Show::to_string(add_res[0]) == "3")

  let sub_res = fe_alg_poly_sub([fe_wb_qq(1, 1), fe_wb_qq(1, 1)], [
    fe_wb_qq(2, 1),
  ])
  assert_true(sub_res.length() == 2 && Show::to_string(sub_res[0]) == "-1")

  let non_monic = fe_wb_minpoly("a", @symcore.int(2) * a + @symcore.int(1), QQ)
  sympolys_assert_error(
    fn() raise PolyError {
      fe_alg_poly_mod(
        [fe_wb_qq(1, 1), fe_wb_qq(0, 1), fe_wb_qq(1, 1)],
        non_monic,
      )
    },
    "DomainNotField",
  )

  let div_zero = fe_alg_poly_divmod([fe_wb_qq(3, 1), fe_wb_qq(1, 1)], [
    fe_wb_qq(0, 1),
  ])
  assert_true(div_zero.0.length() == 1 && div_zero.1.length() == 2)

  let div_short = fe_alg_poly_divmod([fe_wb_qq(1, 1)], [
    fe_wb_qq(1, 1),
    fe_wb_qq(1, 1),
  ])
  assert_true(div_short.0.length() == 1)

  sympolys_assert_error(
    fn() raise PolyError { fe_alg_poly_inv([fe_wb_qq(0, 1)], minpoly) },
    "DivisionByZero",
  )

  let cc_str = Show::to_string(
    FieldElem::CC(
      @symnum.BigRational::from_int(2),
      @symnum.BigRational::from_int(-3),
    ),
  )
  inspect(cc_str, content="2 - 3i")

  let alg_pretty = fe_algext_to_string(
    [fe_wb_qq(1, 1), fe_wb_qq(1, 1), fe_wb_qq(2, 1)],
    "a",
    minpoly,
  )
  inspect(alg_pretty, content="1 + a + 2*a^2")
  inspect(fe_algext_to_string([fe_wb_qq(0, 1)], "a", minpoly), content="0")

  sympolys_assert_error(
    fn() raise PolyError {
      fe_expect_rational(
        CC(@symnum.BigRational::one(), @symnum.BigRational::one()),
      )
    },
    "DomainMismatch",
  )

  let gfext_empty = fe_expect_rational(GFExt(5, [], [1, 0, 1]))
  inspect(gfext_empty, content="0")

  let algext_empty = fe_expect_rational(AlgExt(QQ, [], minpoly, "a"))
  inspect(algext_empty, content="0")
}

///|
test "field_elem wb: remaining branch sweep" {
  let poly_add = fe_poly_add([1, 2], [3], 5)
  assert_true(poly_add.length() == 2)

  let qpow = fe_pow(QQ(@symnum.BigRational::from_int(2)), 3)
  inspect(qpow, content="8")
  let gpow = fe_pow(GFp(5, 3), 4)
  inspect(gpow, content="1")

  let a = @symcore.Expr::Symbol("a")
  let minpoly = fe_wb_minpoly("a", (a ^ @symcore.int(2)) + @symcore.int(1), QQ)
  let alg = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::one()), QQ(@symnum.BigRational::one())],
    minpoly,
    "a",
  )
  let apow = fe_pow(alg, 2)
  assert_true(apow is AlgExt(_, _, _, _))

  assert_true(
    fe_is_negative(
      CC(@symnum.BigRational::from_int(-2), @symnum.BigRational::zero()),
    ),
  )
  assert_true(
    fe_is_positive(
      CC(@symnum.BigRational::from_int(3), @symnum.BigRational::zero()),
    ),
  )
  assert_true(!fe_is_negative(GFp(5, 4)))
  assert_true(!fe_is_positive(GFp(5, 4)))
  assert_true(!fe_is_negative(GFExt(5, [1], [1, 0, 1])))
  assert_true(!fe_is_positive(GFExt(5, [1], [1, 0, 1])))
  let alg_sign_probe = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::one())],
    minpoly,
    "a",
  )
  assert_true(!fe_is_negative(alg_sign_probe))
  assert_true(!fe_is_positive(alg_sign_probe))

  let pm_edge = fe_poly_mod([1, 0], [1], 1)
  assert_true(pm_edge.length() == 0)
  let mp_const = fe_wb_minpoly("a", @symcore.int(1), QQ)
  let alg_mod_edge = fe_alg_poly_mod(
    [QQ(@symnum.BigRational::zero())],
    mp_const,
  )
  assert_true(alg_mod_edge.length() == 0)

  inspect(
    fe_add(
      CC(@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(1)),
      QQ(@symnum.BigRational::from_int(3)),
    ),
    content="5 + 1i",
  )
  inspect(
    fe_add(
      QQ(@symnum.BigRational::from_int(3)),
      CC(@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(1)),
    ),
    content="5 + 1i",
  )
  sympolys_assert_error(
    fn() raise PolyError { fe_add(QQ(@symnum.BigRational::one()), GFp(5, 1)) },
    "DomainMismatch",
  )

  inspect(
    fe_mul(
      CC(@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(1)),
      QQ(@symnum.BigRational::from_int(3)),
    ),
    content="6 + 3i",
  )
  inspect(
    fe_mul(
      QQ(@symnum.BigRational::from_int(3)),
      CC(@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(1)),
    ),
    content="6 + 3i",
  )
  sympolys_assert_error(
    fn() raise PolyError { fe_mul(GFp(5, 2), GFp(7, 3)) },
    "DomainMismatch",
  )
  sympolys_assert_error(
    fn() raise PolyError {
      fe_mul(GFExt(5, [1], [1, 0, 1]), GFExt(5, [1], [1, 1, 1]))
    },
    "DomainMismatch",
  )
  sympolys_assert_error(
    fn() raise PolyError { fe_mul(QQ(@symnum.BigRational::one()), GFp(5, 2)) },
    "DomainMismatch",
  )

  sympolys_assert_error(
    fn() raise PolyError {
      fe_inv(AlgExt(QQ, [QQ(@symnum.BigRational::zero())], minpoly, "a"))
    },
    "DivisionByZero",
  )

  let cc_from_rat = fe_from_rational(fe_wb_rat(7, 2), CC)
  inspect(cc_from_rat, content="7/2")
  let gfext_from_rat = fe_from_rational(fe_wb_rat(8, 3), GFExt(7, 2, [1, 0, 1]))
  guard gfext_from_rat is GFExt(_, coeffs, _) && coeffs.length() == 1 else {
    fail("fe_from_rational over GFExt should produce constant coeff vector")
  }

  inspect(
    FieldElem::CC(
      @symnum.BigRational::from_int(2),
      @symnum.BigRational::from_int(3),
    ),
    content="2 + 3i",
  )
  let alg_str = Show::to_string(
    FieldElem::AlgExt(
      QQ,
      [QQ(@symnum.BigRational::one()), QQ(@symnum.BigRational::one())],
      minpoly,
      "a",
    ),
  )
  inspect(alg_str, content="1 + a")

  assert_true(fe_alg_poly_trim([]).length() == 1)
  let padded = fe_alg_poly_add([fe_wb_qq(1, 1)], [
    fe_wb_qq(2, 1),
    fe_wb_qq(3, 1),
  ])
  assert_true(padded.length() == 2 && Show::to_string(padded[1]) == "3")
}
