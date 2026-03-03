///|
test "field_elem: expect_rational projects constant extensions" {
  let cc = FieldElem::CC(
    @symnum.BigRational::from_int(3),
    @symnum.BigRational::zero(),
  )
  inspect(try! fe_expect_rational(cc).to_string(), content="3")

  let gf_const = FieldElem::GFExt(5, [7], [1, 0, 1])
  inspect(try! fe_expect_rational(gf_const).to_string(), content="7")

  let a = @symcore.symbol("a")
  let minpoly = PolyBuilder::new(["a"], Domain::QQ).from_expr(
    (a ^ @symcore.int(2)) + @symcore.int(1),
  )
  let alg_const = FieldElem::AlgExt(
    Domain::QQ,
    [FieldElem::QQ(@symnum.BigRational::from_int(5))],
    minpoly,
    "a",
  )
  inspect(try! fe_expect_rational(alg_const).to_string(), content="5")
}

///|
test "field_elem: expect_rational rejects non-constant extensions" {
  let gf_non_const = FieldElem::GFExt(5, [1, 1], [1, 0, 1])
  let gf_res : Result[@symnum.BigRational, PolyError] = try? fe_expect_rational(
    gf_non_const,
  )
  guard gf_res is Err(PolyError::DomainMismatch) else {
    fail("expected DomainMismatch")
  }

  let a = @symcore.symbol("a")
  let minpoly = PolyBuilder::new(["a"], Domain::QQ).from_expr(
    (a ^ @symcore.int(2)) + @symcore.int(1),
  )
  let alg_non_const = FieldElem::AlgExt(
    Domain::QQ,
    [
      FieldElem::QQ(@symnum.BigRational::one()),
      FieldElem::QQ(@symnum.BigRational::one()),
    ],
    minpoly,
    "a",
  )
  let alg_res : Result[@symnum.BigRational, PolyError] = try? fe_expect_rational(
    alg_non_const,
  )
  guard alg_res is Err(PolyError::DomainMismatch) else {
    fail("expected DomainMismatch")
  }
}

///|
test "field_elem: from_int embeds into Frac(base)" {
  let q = try! fe_from_int(4, Domain::Frac(Domain::QQ))
  inspect(fe_to_string(q), content="4")

  let gf = try! fe_from_int(-3, Domain::Frac(Domain::GF(5)))
  inspect(fe_to_string(gf), content="2")
}

///|
fn fe_wb_rat(num : Int, den : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
}

///|
fn fe_wb_qq(num : Int, den : Int) -> FieldElem {
  FieldElem::QQ(fe_wb_rat(num, den))
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
  guard fe_trim([], 5).to_string() == "[0]" else {
    fail("fe_trim([]) should canonicalize to [0]")
  }
  inspect(fe_mod_inv_int(2, 4), content="0")

  let pow_neg = try! fe_pow(
    FieldElem::CC(
      @symnum.BigRational::from_int(2),
      @symnum.BigRational::from_int(0),
    ),
    -1,
  )
  inspect(fe_to_string(pow_neg), content="1/2")

  let gf_add_bad : Result[FieldElem, PolyError] = try? fe_add(
    FieldElem::GFp(5, 1),
    FieldElem::GFp(7, 1),
  )
  guard gf_add_bad is Err(PolyError::DomainMismatch) else {
    fail("GFp add with different primes should raise DomainMismatch")
  }

  let gfext_add_bad : Result[FieldElem, PolyError] = try? fe_add(
    FieldElem::GFExt(5, [1], [1, 0, 1]),
    FieldElem::GFExt(5, [1], [1, 1, 1]),
  )
  guard gfext_add_bad is Err(PolyError::DomainMismatch) else {
    fail("GFExt add with different mod poly should raise DomainMismatch")
  }

  let a = @symcore.symbol("a")
  let minpoly = try! fe_wb_minpoly(
    "a",
    (a ^ @symcore.int(2)) + @symcore.int(1),
    Domain::QQ,
  )
  let alg1 = FieldElem::AlgExt(
    Domain::QQ,
    [FieldElem::QQ(@symnum.BigRational::one())],
    minpoly,
    "a",
  )
  let alg2 = FieldElem::AlgExt(
    Domain::QQ,
    [FieldElem::QQ(@symnum.BigRational::one())],
    minpoly,
    "b",
  )
  let alg_add_bad : Result[FieldElem, PolyError] = try? fe_add(alg1, alg2)
  guard alg_add_bad is Err(PolyError::DomainMismatch) else {
    fail("AlgExt add with different generator should raise DomainMismatch")
  }
  let alg_mul_bad : Result[FieldElem, PolyError] = try? fe_mul(alg1, alg2)
  guard alg_mul_bad is Err(PolyError::DomainMismatch) else {
    fail("AlgExt mul with different generator should raise DomainMismatch")
  }
}

///|
test "field_elem wb: inverses and conversion guard paths" {
  let inv_qq_zero : Result[FieldElem, PolyError] = try? fe_inv(
    FieldElem::QQ(@symnum.BigRational::zero()),
  )
  guard inv_qq_zero is Err(PolyError::DivisionByZero) else {
    fail("QQ inverse of zero should raise DivisionByZero")
  }

  let inv_cc_zero : Result[FieldElem, PolyError] = try? fe_inv(
    FieldElem::CC(@symnum.BigRational::zero(), @symnum.BigRational::zero()),
  )
  guard inv_cc_zero is Err(PolyError::DivisionByZero) else {
    fail("CC inverse of zero should raise DivisionByZero")
  }

  let inv_gfp_zero : Result[FieldElem, PolyError] = try? fe_inv(FieldElem::GFp(5, 0))
  guard inv_gfp_zero is Err(PolyError::DivisionByZero) else {
    fail("GFp inverse of zero should raise DivisionByZero")
  }

  let inv_gfext_zero : Result[FieldElem, PolyError] = try? fe_inv(
    FieldElem::GFExt(5, [0], [1, 0, 1]),
  )
  guard inv_gfext_zero is Err(PolyError::DivisionByZero) else {
    fail("GFExt inverse of zero should raise DivisionByZero")
  }

  let x = @symcore.symbol("x")
  let minpoly = try! fe_wb_minpoly("x", x ^ @symcore.int(2), Domain::QQ)
  let inv_alg_nonfield : Result[Array[FieldElem], PolyError] = try? fe_alg_poly_inv(
    [FieldElem::QQ(@symnum.BigRational::zero()), FieldElem::QQ(@symnum.BigRational::one())],
    minpoly,
  )
  guard inv_alg_nonfield is Err(PolyError::DomainNotField) else {
    fail("fe_alg_poly_inv should fail in non-field quotient")
  }

  let bad_zz : Result[FieldElem, PolyError] = try? fe_from_rational(
    fe_wb_rat(1, 2),
    Domain::ZZ,
  )
  guard bad_zz is Err(PolyError::CoefficientNotInteger) else {
    fail("fe_from_rational(1/2, ZZ) should reject non-integers")
  }

  let frac_gf = try! fe_from_rational(fe_wb_rat(8, 3), Domain::Frac(Domain::GF(7)))
  inspect(fe_to_string(frac_gf), content="5")

  let bad_loader_gen : Result[(Poly, String), PolyError] = try? load_algext_minpoly(
    Domain::QQ,
    ["a", "b"],
    [@symcore.int(1)],
  )
  guard bad_loader_gen is Err(PolyError::BadGenerator("algext")) else {
    fail("load_algext_minpoly should require one generator/relation")
  }

  let bad_loader_base : Result[(Poly, String), PolyError] = try? load_algext_minpoly(
    Domain::ZZ,
    ["a"],
    [@symcore.symbol("a") + @symcore.int(1)],
  )
  guard bad_loader_base is Err(PolyError::DomainNotField) else {
    fail("load_algext_minpoly should reject non-field base domains")
  }

  let bad_loader_deg : Result[(Poly, String), PolyError] = try? load_algext_minpoly(
    Domain::QQ,
    ["a"],
    [@symcore.int(1)],
  )
  guard bad_loader_deg is Err(PolyError::BadExponent) else {
    fail("load_algext_minpoly should reject degree <= 0 relations")
  }
}

///|
test "field_elem wb: algebraic helpers and string formatting branches" {
  let a = @symcore.symbol("a")
  let minpoly = try! fe_wb_minpoly(
    "a",
    (a ^ @symcore.int(2)) + @symcore.int(1),
    Domain::QQ,
  )

  let add_res = try! fe_alg_poly_add(
    [fe_wb_qq(1, 1), fe_wb_qq(1, 1)],
    [fe_wb_qq(2, 1)],
  )
  guard add_res.length() == 2 && add_res[0].to_string() == "3" else {
    fail("fe_alg_poly_add padding branch mismatch")
  }

  let sub_res = try! fe_alg_poly_sub(
    [fe_wb_qq(1, 1), fe_wb_qq(1, 1)],
    [fe_wb_qq(2, 1)],
  )
  guard sub_res.length() == 2 && sub_res[0].to_string() == "-1" else {
    fail("fe_alg_poly_sub padding branch mismatch")
  }

  let non_monic = try! fe_wb_minpoly(
    "a",
    @symcore.int(2) * a + @symcore.int(1),
    Domain::QQ,
  )
  let mod_bad : Result[Array[FieldElem], PolyError] = try? fe_alg_poly_mod(
    [fe_wb_qq(1, 1), fe_wb_qq(0, 1), fe_wb_qq(1, 1)],
    non_monic,
  )
  guard mod_bad is Err(PolyError::DomainNotField) else {
    fail("fe_alg_poly_mod should reject non-monic minimal polynomial")
  }

  let div_zero = try! fe_alg_poly_divmod(
    [fe_wb_qq(3, 1), fe_wb_qq(1, 1)],
    [fe_wb_qq(0, 1)],
  )
  guard div_zero.0.length() == 1 && div_zero.1.length() == 2 else {
    fail("fe_alg_poly_divmod zero divisor branch mismatch")
  }

  let div_short = try! fe_alg_poly_divmod(
    [fe_wb_qq(1, 1)],
    [fe_wb_qq(1, 1), fe_wb_qq(1, 1)],
  )
  guard div_short.0.length() == 1 else {
    fail("fe_alg_poly_divmod n<m quotient shape mismatch")
  }

  let inv_zero : Result[Array[FieldElem], PolyError] = try? fe_alg_poly_inv(
    [fe_wb_qq(0, 1)],
    minpoly,
  )
  guard inv_zero is Err(PolyError::DivisionByZero) else {
    fail("fe_alg_poly_inv(0) should raise DivisionByZero")
  }

  let cc_str = fe_to_string(
    FieldElem::CC(@symnum.BigRational::from_int(2), @symnum.BigRational::from_int(-3)),
  )
  inspect(cc_str, content="2 - 3i")

  let alg_pretty = fe_algext_to_string(
    [fe_wb_qq(1, 1), fe_wb_qq(1, 1), fe_wb_qq(2, 1)],
    "a",
    minpoly,
  )
  inspect(alg_pretty, content="1 + a + 2*a^2")
  inspect(fe_algext_to_string([fe_wb_qq(0, 1)], "a", minpoly), content="0")

  let bad_cc_proj : Result[@symnum.BigRational, PolyError] = try? fe_expect_rational(
    FieldElem::CC(@symnum.BigRational::one(), @symnum.BigRational::one()),
  )
  guard bad_cc_proj is Err(PolyError::DomainMismatch) else {
    fail("fe_expect_rational should reject non-real CC")
  }

  let gfext_empty = try! fe_expect_rational(FieldElem::GFExt(5, [], [1, 0, 1]))
  inspect(gfext_empty.to_string(), content="0")

  let algext_empty = try! fe_expect_rational(FieldElem::AlgExt(Domain::QQ, [], minpoly, "a"))
  inspect(algext_empty.to_string(), content="0")
}
