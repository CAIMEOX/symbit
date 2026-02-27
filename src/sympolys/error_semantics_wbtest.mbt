///|
fn fezz_wb(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
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
  guard max_res is Err(PolyError::NonPolynomial) else {
    fail("monomial_max([]) should raise NonPolynomial")
  }
  let min_res : Result[Monomial, PolyError] = try? monomial_min([])
  guard min_res is Err(PolyError::NonPolynomial) else {
    fail("monomial_min([]) should raise NonPolynomial")
  }

  let cauchy_res : Result[FieldElem, PolyError] = try? dup_cauchy_upper_bound(
    [fezz_wb(1)],
    Domain::QQ,
  )
  guard cauchy_res is Err(PolyError::BadExponent) else {
    fail("short cauchy bound should raise BadExponent")
  }

  let sturm_res : Result[Array[Array[FieldElem]], PolyError] = try? dup_sturm(
    [],
    Domain::QQ,
  )
  guard sturm_res is Err(PolyError::NonPolynomial) else {
    fail("dup_sturm([]) should raise NonPolynomial")
  }
}

///|
test "errors: normalize_mod on AlgExt reduces in base domain" {
  let alpha = @symcore.symbol("alpha")
  let rel = (alpha ^ @symcore.int(2)) + @symcore.int(1)
  let d = Domain::AlgExt(Domain::QQ, ["alpha"], [rel])
  let value = try! @symnum.BigRational::new(
    BigInt::from_int(3),
    BigInt::from_int(2),
  )
  let got = normalize_mod(value, d)
  inspect(got.to_string(), content="3/2")
}

///|
test "rr: coefficients are no longer QQ-backed" {
  let half = try! @symnum.BigRational::new(
    BigInt::from_int(1),
    BigInt::from_int(2),
  )
  match ensure_coeff_domain(half, Domain::RR) {
    FieldElem::CC(real, imag) => {
      inspect(real.to_string(), content="1/2")
      inspect(imag.to_string(), content="0")
    }
    _ => fail("RR coefficients should use CC(real, 0) storage")
  }

  let rr_half = try! fe_from_rational(half, Domain::RR)
  let rr_one = try! fe_from_int(1, Domain::RR)
  match fe_add(rr_half, rr_one) {
    FieldElem::CC(real, imag) => {
      inspect(real.to_string(), content="3/2")
      inspect(imag.to_string(), content="0")
    }
    _ => fail("RR arithmetic should stay in the RR/CC representation")
  }
}
