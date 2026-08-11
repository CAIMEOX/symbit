///|
test "core wb: add_term merges to zero" {
  let coeffs : Map[Monomial, FieldElem] = Map([])
  let mono = monomial_one(1)
  add_term(coeffs, mono, fe_from_int(1, ZZ), ZZ)
  add_term(coeffs, mono, fe_from_int(-1, ZZ), ZZ)
  assert_true(coeffs.length() == 0)
}

///|
test "core wb: ensure_coeff_domain maps rationals into GF representatives" {
  let c = @symnum.BigRational::new(BigInt::from_int(3), BigInt::from_int(2))
  let fe = ensure_coeff_domain(c, GF(5))
  assert_true(Show::to_string(fe) == "4")
}

///|
test "core wb: ensure_coeff_domain rejects non-integral in ZZ" {
  let c = @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2))
  sympolys_assert_error(
    fn() raise PolyError { ensure_coeff_domain(c, ZZ) },
    "CoefficientNotInteger",
  )
}
