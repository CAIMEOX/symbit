///|
/// Dense Euclidean algorithms, GCD cofactors, and PRS helpers.

///|
fn euclidtools_require_field(domain : Domain) -> Unit raise PolyError {
  if !domain_is_field_pred(domain) {
    raise PolyError::DomainNotField
  }
}

///|
fn euclidtools_dup_is_one(coeffs : Array[FieldElem]) -> Bool {
  coeffs.length() == 1 && fe_is_one(coeffs[0])
}

///|
/// Half extended Euclidean algorithm in `F[x]`.
///
/// - Does: Returns `(s, h)` such that `h = gcd(f, g)` and
///   `s * f = h mod g`.
/// - Input: Two univariate dense coefficient arrays over a field `domain`.
/// - Returns: A pair of dense coefficient arrays `(s, h)`.
/// - Limits: Raises `PolyError::DomainNotField` when `domain` is not a field.
pub fn dup_half_gcdex(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem]) raise PolyError {
  euclidtools_require_field(domain)
  let mut ff = dup_strip(f)
  let mut gg = dup_strip(g)
  let mut a = [fe_from_int(1, domain)]
  let mut b : Array[FieldElem] = []
  while !gg.is_empty() {
    let (q, r) = dup_div(ff, gg, domain)
    ff = gg
    gg = r
    let next = dup_sub_mul(a, q, b, domain)
    a = b
    b = next
  }
  if ff.is_empty() {
    raise PolyError::DivisionByZero
  }
  let lc = dup_LC(ff)
  (dup_exquo_ground(a, lc, domain), dup_monic(ff, domain))
}

///|
/// Half extended Euclidean algorithm in `F[X]`.
///
/// - Does: Delegates to `dup_half_gcdex` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a field `domain`.
/// - Returns: A pair of dense recursive polynomials `(s, h)`.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_half_gcdex(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, DensePoly) raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  let (s, h) = dup_half_gcdex(dmp_to_coeffs(f), dmp_to_coeffs(g), domain)
  (dmp_from_coeffs(s), dmp_from_coeffs(h))
}

///|
/// Extended Euclidean algorithm in `F[x]`.
///
/// - Does: Returns `(s, t, h)` such that `s*f + t*g = h`.
/// - Input: Two univariate dense coefficient arrays over a field `domain`.
/// - Returns: Three dense coefficient arrays `(s, t, h)`.
/// - Limits: Raises `PolyError::DomainNotField` when `domain` is not a field.
pub fn dup_gcdex(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem], Array[FieldElem]) raise PolyError {
  let (s, h) = dup_half_gcdex(f, g, domain)
  let diff = dup_sub_mul(h, s, dup_strip(f), domain)
  let t = dup_quo(diff, dup_strip(g), domain)
  (s, t, h)
}

///|
/// Extended Euclidean algorithm in `F[X]`.
///
/// - Does: Delegates to `dup_gcdex` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a field `domain`.
/// - Returns: Three dense recursive polynomials `(s, t, h)`.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_gcdex(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, DensePoly, DensePoly) raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  let (s, t, h) = dup_gcdex(dmp_to_coeffs(f), dmp_to_coeffs(g), domain)
  (dmp_from_coeffs(s), dmp_from_coeffs(t), dmp_from_coeffs(h))
}

///|
/// Multiplicative inverse of `f` modulo `g` in `F[x]`.
///
/// - Does: Computes a representative of `f**(-1) mod g` when the gcd is one.
/// - Input: Two univariate dense coefficient arrays over a field `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Raises `PolyError::ExactQuotientFailed` for zero divisors because
///   this package does not expose a separate `NotInvertible` error variant.
pub fn dup_invert(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let (s, h) = dup_half_gcdex(f, g, domain)
  if euclidtools_dup_is_one(h) {
    dup_rem(s, dup_strip(g), domain)
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
/// Multiplicative inverse of `f` modulo `g` in `F[X]`.
///
/// - Does: Delegates to `dup_invert` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a field `domain`.
/// - Returns: A dense recursive polynomial.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_invert(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  dmp_from_coeffs(dup_invert(dmp_to_coeffs(f), dmp_to_coeffs(g), domain))
}

///|
/// Euclidean polynomial remainder sequence in `K[x]`.
///
/// - Does: Repeatedly appends polynomial remainders until the remainder is zero.
/// - Input: Two univariate dense coefficient arrays and a coefficient `domain`.
/// - Returns: An array of dense coefficient arrays.
/// - Limits: Uses ordinary remainder division, matching the Euclidean PRS front
///   door rather than primitive or subresultant PRS variants.
pub fn dup_euclidean_prs(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let mut ff = dup_strip(f)
  let mut gg = dup_strip(g)
  let prs : Array[Array[FieldElem]] = [ff, gg]
  let mut h = dup_rem(ff, gg, domain)
  while !h.is_empty() {
    prs.push(h)
    ff = gg
    gg = h
    h = dup_rem(ff, gg, domain)
  }
  prs
}

///|
/// Euclidean polynomial remainder sequence in `K[X]`.
///
/// - Does: Delegates to `dup_euclidean_prs` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: An array of dense recursive polynomials.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_euclidean_prs(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> Array[DensePoly] raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  let raw = dup_euclidean_prs(dmp_to_coeffs(f), dmp_to_coeffs(g), domain)
  raw.map(poly => dmp_from_coeffs(poly))
}
