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
