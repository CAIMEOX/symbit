///|
test "core wb: add_term merges to zero" {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  let mono = monomial_one(1)
  add_term(coeffs, mono, fe_from_int(1, Domain::ZZ), Domain::ZZ)
  add_term(coeffs, mono, fe_from_int(-1, Domain::ZZ), Domain::ZZ)
  guard coeffs.length() == 0 else {
    fail("expected zero after canceling terms")
  }
}

///|
test "core wb: ensure_coeff_domain maps rationals into GF representatives" {
  let c = @symnum.BigRational::new(BigInt::from_int(3), BigInt::from_int(2))
  let fe = ensure_coeff_domain(c, Domain::GF(5))
  guard fe.to_string() == "4" else {
    fail("3/2 over GF(5) should normalize to 4")
  }
}

///|
test "core wb: ensure_coeff_domain rejects non-integral in ZZ" {
  let c = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  let res : Result[FieldElem, PolyError] = try? ensure_coeff_domain(
    c,
    Domain::ZZ,
  )
  guard res is Err(PolyError::CoefficientNotInteger) else {
    fail("expected CoefficientNotInteger")
  }
}
