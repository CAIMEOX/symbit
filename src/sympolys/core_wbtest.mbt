///|
test "core wb: add_term merges to zero" {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  let mono = monomial_one(1)
  add_term(coeffs, mono, fe_from_int(1, Domain::ZZ), Domain::ZZ)
  add_term(coeffs, mono, fe_from_int(-1, Domain::ZZ), Domain::ZZ)
  assert_eq(coeffs.length(), 0)
}

///|
test "core wb: ensure_coeff_domain maps rationals into GF representatives" {
  let c = @symnum.BigRational::new(BigInt::from_int(3), BigInt::from_int(2))
  let fe = ensure_coeff_domain(c, Domain::GF(5))
  assert_eq(fe.to_string(), "4")
}

///|
test "core wb: ensure_coeff_domain rejects non-integral in ZZ" {
  let c = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  let res : Result[FieldElem, PolyError] = try? ensure_coeff_domain(
    c,
    Domain::ZZ,
  )
  assert_true(res is Err(PolyError::CoefficientNotInteger))
}
