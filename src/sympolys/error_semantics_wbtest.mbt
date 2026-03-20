///|
fn fezz_wb(n : Int) -> FieldElem {
  FieldElem::QQ(@symnum.BigRational::from_int(n))
}

///|
test "errors: exact division failures are explicit" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let p = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let q = b.from_expr(x + @symcore.int(1))
  let exact_res : Result[Poly, PolyError] = try? p.div_exact_univar(q)
  match exact_res {
    Err(PolyError::ExactQuotientFailed) => ()
    _ => fail("expected ExactQuotientFailed for div_exact_univar")
  }

  let exquo_res : Result[Array[FieldElem], PolyError] = try? dup_exquo_ground(
    [fezz_wb(1)],
    fezz_wb(2),
    Domain::ZZ,
  )
  match exquo_res {
    Err(PolyError::ExactQuotientFailed) => ()
    _ => fail("expected ExactQuotientFailed for dup_exquo_ground")
  }
}

///|
test "errors: empty monomial and root-isolation inputs are typed" {
  let max_res : Result[Monomial, PolyError] = try? monomial_max([])
  assert_true(max_res is Err(PolyError::NonPolynomial))
  let min_res : Result[Monomial, PolyError] = try? monomial_min([])
  assert_true(min_res is Err(PolyError::NonPolynomial))

  let cauchy_res : Result[FieldElem, PolyError] = try? dup_cauchy_upper_bound(
    [fezz_wb(1)],
    Domain::QQ,
  )
  assert_true(cauchy_res is Err(PolyError::BadExponent))

  let sturm_res : Result[Array[Array[FieldElem]], PolyError] = try? dup_sturm(
    [],
    Domain::QQ,
  )
  assert_true(sturm_res is Err(PolyError::NonPolynomial))
}

///|
test "errors: normalize_mod on AlgExt reduces in base domain" {
  let alpha = @symcore.symbol("alpha")
  let rel = (alpha ^ @symcore.int(2)) + @symcore.int(1)
  let d = Domain::AlgExt(Domain::QQ, ["alpha"], [rel])
  let value = @symnum.BigRational::new(BigInt::from_int(3), BigInt::from_int(2))
  let got = normalize_mod(value, d)
  inspect(got.to_string(), content="3/2")
}

///|
test "rr: coefficients are no longer QQ-backed" {
  let half = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  match ensure_coeff_domain(half, Domain::RR) {
    FieldElem::CC(real, imag) => {
      inspect(real.to_string(), content="1/2")
      inspect(imag.to_string(), content="0")
    }
    _ => fail("RR coefficients should use CC(real, 0) storage")
  }

  let rr_half = fe_from_rational(half, Domain::RR)
  let rr_one = fe_from_int(1, Domain::RR)
  match fe_add(rr_half, rr_one) {
    FieldElem::CC(real, imag) => {
      inspect(real.to_string(), content="3/2")
      inspect(imag.to_string(), content="0")
    }
    _ => fail("RR arithmetic should stay in the RR/CC representation")
  }
}
