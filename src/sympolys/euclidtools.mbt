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
fn euclidtools_dup_primitive(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[FieldElem]) raise PolyError {
  let coeffs = dup_strip(f)
  if coeffs.is_empty() {
    return (fe_from_int(0, domain), coeffs)
  }
  let content = match domain {
    Domain::ZZ
    | Domain::QQ
    | Domain::RR
    | Domain::CC
    | Domain::ZZ_I
    | Domain::QQ_I => field_elems_content(coeffs, domain)
    _ => fe_from_int(1, domain)
  }
  if fe_is_zero(content) {
    (content, coeffs)
  } else {
    (content, dup_exquo_ground(coeffs, content, domain))
  }
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

///|
/// Primitive polynomial remainder sequence in `K[x]`.
///
/// - Does: Uses pseudo-remainders and removes coefficient content from each
///   nonzero remainder.
/// - Input: Two univariate dense coefficient arrays and a coefficient `domain`.
/// - Returns: An array of primitive dense coefficient arrays.
/// - Limits: Content extraction is exact for rational-like domains; other
///   domains are treated as already primitive.
pub fn dup_primitive_prs(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let mut ff = dup_strip(f)
  let mut gg = dup_strip(g)
  let prs : Array[Array[FieldElem]] = [ff, gg]
  let (_, first) = euclidtools_dup_primitive(dup_prem(ff, gg, domain), domain)
  let mut h = first
  while !h.is_empty() {
    prs.push(h)
    ff = gg
    gg = h
    let (_, next) = euclidtools_dup_primitive(dup_prem(ff, gg, domain), domain)
    h = next
  }
  prs
}

///|
/// Primitive polynomial remainder sequence in `K[X]`.
///
/// - Does: Delegates to `dup_primitive_prs` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: An array of dense recursive polynomials.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_primitive_prs(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> Array[DensePoly] raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  dup_primitive_prs(dmp_to_coeffs(f), dmp_to_coeffs(g), domain).map(poly => {
    dmp_from_coeffs(poly)
  })
}

///|
/// Subresultant PRS and scalar subresultants in `K[x]`.
///
/// - Does: Computes the Brown subresultant PRS together with the nonzero
///   scalar subresultants.
/// - Input: Two univariate dense coefficient arrays and a coefficient `domain`.
/// - Returns: `(prs, scalar_subresultants)`.
/// - Limits: Requires exact pseudo-division and exact ground quotients.
pub fn dup_inner_subresultants(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (Array[Array[FieldElem]], Array[FieldElem]) raise PolyError {
  let mut ff = dup_strip(f)
  let mut gg = dup_strip(g)
  let mut n = dup_degree(ff)
  let mut m = dup_degree(gg)
  if n < m {
    let tmp = ff
    ff = gg
    gg = tmp
    let tmp_d = n
    n = m
    m = tmp_d
  }
  if ff.is_empty() {
    return ([], [])
  }
  let one = fe_from_int(1, domain)
  if gg.is_empty() {
    return ([ff], [one])
  }
  let prs : Array[Array[FieldElem]] = [ff, gg]
  let mut d = n - m
  let mut b = fe_pow(fe_neg(one), d + 1)
  let mut h = dup_mul_ground(dup_prem(ff, gg, domain), b, domain)
  let mut lc = dup_LC(gg)
  let mut c = fe_pow(lc, d)
  let scalars : Array[FieldElem] = [one, c]
  c = fe_neg(c)
  while !h.is_empty() {
    let k = dup_degree(h)
    prs.push(h)
    let old_m = m
    ff = gg
    gg = h
    m = k
    d = old_m - k
    b = fe_mul(fe_neg(lc), fe_pow(c, d))
    h = dup_exquo_ground(dup_prem(ff, gg, domain), b, domain)
    lc = dup_LC(gg)
    c = if d > 1 {
      let q = fe_pow(c, d - 1)
      fe_exquo_ground(fe_pow(fe_neg(lc), d), q, domain)
    } else {
      fe_neg(lc)
    }
    scalars.push(fe_neg(c))
  }
  (prs, scalars)
}

///|
/// Subresultant PRS in `K[x]`.
///
/// - Does: Returns only the polynomial PRS from `dup_inner_subresultants`.
/// - Input: Two univariate dense coefficient arrays and a coefficient `domain`.
/// - Returns: An array of dense coefficient arrays.
/// - Limits: Same exactness requirements as `dup_inner_subresultants`.
pub fn dup_subresultants(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  dup_inner_subresultants(f, g, domain).0
}

///|
/// Resultant and subresultant PRS in `K[x]`.
///
/// - Does: Computes the scalar resultant using the subresultant PRS algorithm.
/// - Input: Two univariate dense coefficient arrays and a coefficient `domain`.
/// - Returns: `(resultant, prs)`.
/// - Limits: Returns zero when the final subresultant still has positive degree.
pub fn dup_prs_resultant(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[Array[FieldElem]]) raise PolyError {
  if f.is_empty() || g.is_empty() {
    return (fe_from_int(0, domain), [])
  }
  let (prs, scalars) = dup_inner_subresultants(f, g, domain)
  if prs.is_empty() || dup_degree(prs[prs.length() - 1]) > 0 {
    return (fe_from_int(0, domain), prs)
  }
  (scalars[scalars.length() - 1], prs)
}

///|
/// Resultant in `K[x]`.
///
/// - Does: Computes the scalar resultant through `dup_prs_resultant`.
/// - Input: Two univariate dense coefficient arrays and a coefficient `domain`.
/// - Returns: A `FieldElem` scalar.
/// - Limits: The Python `includePRS=True` union return is exposed separately as
///   `dup_prs_resultant`.
pub fn dup_resultant(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  dup_prs_resultant(f, g, domain).0
}

///|
/// Subresultant PRS and scalar subresultants in `K[X]`.
///
/// - Does: Delegates to `dup_inner_subresultants` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: `(prs, scalar_subresultants)`.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_inner_subresultants(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (Array[DensePoly], Array[DensePoly]) raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  let (prs, scalars) = dup_inner_subresultants(
    dmp_to_coeffs(f),
    dmp_to_coeffs(g),
    domain,
  )
  (
    prs.map(poly => dmp_from_coeffs(poly)),
    scalars.map(value => DensePoly::Coef(value)),
  )
}

///|
/// Subresultant PRS in `K[X]`.
///
/// - Does: Delegates to `dup_subresultants` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: An array of dense recursive polynomials.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_subresultants(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> Array[DensePoly] raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  dup_subresultants(dmp_to_coeffs(f), dmp_to_coeffs(g), domain).map(poly => {
    dmp_from_coeffs(poly)
  })
}

///|
/// Resultant and subresultant PRS in `K[X]`.
///
/// - Does: Delegates to `dup_prs_resultant` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: `(resultant, prs)`.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_prs_resultant(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (DensePoly, Array[DensePoly]) raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  let (res, prs) = dup_prs_resultant(dmp_to_coeffs(f), dmp_to_coeffs(g), domain)
  (DensePoly::Coef(res), prs.map(poly => dmp_from_coeffs(poly)))
}

///|
/// Resultant in `K[X]`.
///
/// - Does: Delegates to `dup_resultant` for univariate input.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: A dense scalar coefficient node.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_resultant(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  DensePoly::Coef(dup_resultant(dmp_to_coeffs(f), dmp_to_coeffs(g), domain))
}

///|
/// Discriminant in `K[x]`.
///
/// - Does: Computes `res(f, f') / (LC(f) * (-1)**(n*(n-1)/2))`.
/// - Input: One univariate dense coefficient array and a coefficient `domain`.
/// - Returns: A `FieldElem` scalar.
/// - Limits: Requires exact ground quotient in the coefficient domain.
pub fn dup_discriminant(
  f : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let coeffs = dup_strip(f)
  let d = dup_degree(coeffs)
  if d <= 0 {
    return fe_from_int(0, domain)
  }
  let sign = if d * (d - 1) / 2 % 2 == 0 { 1 } else { -1 }
  let c = dup_LC(coeffs)
  let r = dup_resultant(coeffs, dup_diff(coeffs, 1, domain), domain)
  fe_exquo_ground(r, fe_mul(c, fe_from_int(sign, domain)), domain)
}

///|
/// Discriminant in `K[X]`.
///
/// - Does: Delegates to `dup_discriminant` for univariate input.
/// - Input: One dense recursive polynomial, a level `u`, and a coefficient
///   `domain`.
/// - Returns: A dense scalar coefficient node.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_discriminant(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  DensePoly::Coef(dup_discriminant(dmp_to_coeffs(f), domain))
}
