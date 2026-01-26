///|
/// Clear denominators of a QQ polynomial to lift into ZZ.
pub fn clear_denominators(poly : Poly) -> Poly raise PolyError {
  let mut lcm_den = BigInt::from_int(1)
  for _, c in poly.coeffs {
    let r = fe_expect_rational(c)
    let den = r.denominator()
    let g = @symnum.gcd_bigint(lcm_den, den)
    lcm_den = lcm_den.mul(den.div(g))
  }
  let scaled = poly.scale_coeff(FieldElem::QQ(@symnum.BigRational::from_bigint(lcm_den)))
  try_round_to_int(scaled)
}
