///|
/// Computes the indefinite integral of ``f`` in ``K[x]``.

///|
/// Public API `dup_integrate`.
///
/// - Does: Provides the `dup_integrate` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : Array[FieldElem]`, `m : Int`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_integrate(
  f : Array[FieldElem],
  m : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if m <= 0 || f.is_empty() {
    return f
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(m, zero)
  let n = f.length()
  for i in 0..<n {
    let idx = n - 1 - i
    let c = f[idx]
    let mut denom = i + 1
    if m > 1 {
      for j in 1..<m {
        denom = denom * (i + j + 1)
      }
    }
    let inv = fe_inv(fe_from_int(denom, domain))
    out.insert(0, fe_mul(c, inv))
  }
  out
}

///|
/// Computes the indefinite integral of ``f`` in ``x_0`` in ``K[X]``.

///|
/// Public API `dmp_integrate`.
///
/// - Does: Provides the `dmp_integrate` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `m : Int`, `u : Int`, `domain : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_integrate(
  f : DensePoly,
  m : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_integrate(coeffs, m, domain))
  }
  if m <= 0 || dmp_zero_p(f, u) {
    return f
  }
  let out = dmp_zeros(m, u - 1, domain)
  let items = dmp_items(f)
  let n = items.length()
  for i in 0..<n {
    let idx = n - 1 - i
    let c = items[idx]
    let mut denom = i + 1
    if m > 1 {
      for j in 1..<m {
        denom = denom * (i + j + 1)
      }
    }
    let inv = fe_from_int(denom, domain)
    out.insert(0, dmp_exquo_ground(c, inv, u - 1, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
fn rec_integrate_in(
  g : DensePoly,
  m : Int,
  v : Int,
  i : Int,
  j : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i == j {
    return dmp_integrate(g, m, v, domain)
  }
  let items = dmp_items(g)
  let w = v - 1
  let out : Array[DensePoly] = Array::new()
  for c in items {
    out.push(rec_integrate_in(c, m, w, i + 1, j, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
/// Computes the indefinite integral of ``f`` in ``x_j`` in ``K[X]``.

///|
/// Public API `dmp_integrate_in`.
///
/// - Does: Provides the `dmp_integrate_in` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `m : Int`, `j : Int`, `u : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_integrate_in(
  f : DensePoly,
  m : Int,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  rec_integrate_in(f, m, u, 0, j, domain)
}

///|
/// ``m``-th order derivative of a polynomial in ``K[x]``.

///|
/// Public API `dup_diff`.
///
/// - Does: Provides the `dup_diff` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : Array[FieldElem]`, `m : Int`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_diff(
  f : Array[FieldElem],
  m : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if m <= 0 {
    return f
  }
  let n = dup_degree(f)
  if n < m {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::new()
  if m == 1 {
    let mut k = n
    for i in 0..<(f.length() - m) {
      let coeff = fe_mul(fe_from_int(k, domain), f[i])
      out.push(coeff)
      k = k - 1
    }
  } else {
    let mut k = n
    for i in 0..<(f.length() - m) {
      let mut scale = k
      let mut t = k - 1
      let mut left = m - 1
      while left > 0 {
        scale = scale * t
        t = t - 1
        left = left - 1
      }
      let coeff = fe_mul(fe_from_int(scale, domain), f[i])
      out.push(coeff)
      k = k - 1
    }
  }
  dup_strip(out)
}

///|
/// ``m``-th order derivative in ``x_0`` of a polynomial in ``K[X]``.

///|
/// Public API `dmp_diff`.
///
/// - Does: Provides the `dmp_diff` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `m : Int`, `u : Int`, `domain : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_diff(
  f : DensePoly,
  m : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_diff(coeffs, m, domain))
  }
  if m <= 0 || dmp_zero_p(f, u) {
    return f
  }
  let n = dmp_degree(f, u)
  if n < m {
    return dmp_zero(u)
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::new()
  if m == 1 {
    let mut k = n
    for i in 0..<(items.length() - m) {
      let coeff = dmp_mul_ground(
        items[i],
        fe_from_int(k, domain),
        u - 1,
        domain,
      )
      out.push(coeff)
      k = k - 1
    }
  } else {
    let mut k = n
    for i in 0..<(items.length() - m) {
      let mut scale = k
      let mut t = k - 1
      let mut left = m - 1
      while left > 0 {
        scale = scale * t
        t = t - 1
        left = left - 1
      }
      let coeff = dmp_mul_ground(
        items[i],
        fe_from_int(scale, domain),
        u - 1,
        domain,
      )
      out.push(coeff)
      k = k - 1
    }
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
fn rec_diff_in(
  g : DensePoly,
  m : Int,
  v : Int,
  i : Int,
  j : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i == j {
    return dmp_diff(g, m, v, domain)
  }
  let items = dmp_items(g)
  let w = v - 1
  let out : Array[DensePoly] = Array::new()
  for c in items {
    out.push(rec_diff_in(c, m, w, i + 1, j, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
/// ``m``-th order derivative in ``x_j`` of a polynomial in ``K[X]``.

///|
/// Public API `dmp_diff_in`.
///
/// - Does: Provides the `dmp_diff_in` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `m : Int`, `j : Int`, `u : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_diff_in(
  f : DensePoly,
  m : Int,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  rec_diff_in(f, m, u, 0, j, domain)
}

///|
/// Evaluate a polynomial at ``x = a`` in ``K[x]`` using Horner scheme.

///|
/// Public API `dup_eval`.
///
/// - Does: Provides the `dup_eval` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : Array[FieldElem]`, `a : FieldElem`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_eval(
  f : Array[FieldElem],
  a : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(a) {
    return dup_TC(f)
  }
  let mut result = fe_from_int(0, domain)
  for c in f {
    result = fe_add(fe_mul(result, a), c)
  }
  result
}

///|
/// Evaluate a polynomial at ``x_0 = a`` in ``K[X]`` using the Horner scheme.

///|
/// Public API `dmp_eval`.
///
/// - Does: Provides the `dmp_eval` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `a : FieldElem`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_eval(
  f : DensePoly,
  a : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dmp_to_coeffs(f)
    return dmp_ground(dup_eval(coeffs, a, domain), -1)
  }
  if fe_is_zero(a) {
    return dmp_TC(f)
  }
  let items = dmp_items(f)
  let mut result = dmp_LC(f)
  let v = u - 1
  for i in 1..<items.length() {
    result = dmp_mul_ground(result, a, v, domain)
    result = dmp_add(result, items[i], v, domain)
  }
  result
}

///|
fn rec_eval_in(
  g : DensePoly,
  a : FieldElem,
  v : Int,
  i : Int,
  j : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i == j {
    return dmp_eval(g, a, v, domain)
  }
  let items = dmp_items(g)
  let w = v - 1
  let out : Array[DensePoly] = Array::new()
  for c in items {
    out.push(rec_eval_in(c, a, w, i + 1, j, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
/// Evaluate a polynomial at ``x_j = a`` in ``K[X]`` using the Horner scheme.

///|
/// Public API `dmp_eval_in`.
///
/// - Does: Provides the `dmp_eval_in` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `a : FieldElem`, `j : Int`, `u : Int`, `domain
/// : Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_eval_in(
  f : DensePoly,
  a : FieldElem,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  rec_eval_in(f, a, u, 0, j, domain)
}

///|
/// Divide all coefficients by ``LC(f)`` in ``K[x]``.

///|
/// Public API `dup_monic`.
///
/// - Does: Provides the `dup_monic` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : Array[FieldElem]`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_monic(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return f
  }
  let lc = dup_LC(f)
  if fe_is_one(lc) {
    f
  } else {
    dup_exquo_ground(f, lc, domain)
  }
}

///|
/// Divide all coefficients by ``LC(f)`` in ``K[X]``.

///|
/// Public API `dmp_ground_monic`.
///
/// - Does: Provides the `dmp_ground_monic` operation for dense polynomial calculus and evaluation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_ground_monic(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    return dmp_from_coeffs(dup_monic(dmp_to_coeffs(f), domain))
  }
  if dmp_zero_p(f, u) {
    return f
  }
  let lc = dmp_ground_LC(f, u)
  if fe_is_one(lc) {
    f
  } else {
    dmp_exquo_ground(f, lc, u, domain)
  }
}

///|
/// Compute the GCD of coefficients in `K[x]`.
///
/// - Does: Computes the ground content of a univariate dense polynomial.
/// - Input: A dense coefficient array and a coefficient `domain`.
/// - Returns: A coefficient-domain element.
/// - Limits: Exact rational-like domains are supported by the current content
///   helper.
pub fn dup_content(
  f : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let coeffs = dup_strip(f)
  if coeffs.is_empty() {
    return fe_from_int(0, domain)
  }
  field_elems_content(coeffs, domain)
}

///|
/// Compute the GCD of ground coefficients in `K[X]`.
///
/// - Does: Recursively computes the ground content of a dense polynomial.
/// - Input: A dense recursive polynomial, a level `u`, and a coefficient
///   `domain`.
/// - Returns: A coefficient-domain element.
/// - Limits: Exact rational-like domains are supported by the current content
///   helper.
pub fn dmp_ground_content(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  if u == 0 {
    return dup_content(dmp_to_coeffs(f), domain)
  }
  if dmp_zero_p(f, u) {
    return fe_from_int(0, domain)
  }
  let mut content = fe_from_int(0, domain)
  for c in dmp_items(f) {
    content = field_elems_content(
      [content, dmp_ground_content(c, u - 1, domain)],
      domain,
    )
    if fe_is_one(content) {
      break
    }
  }
  content
}

///|
/// Compute content and primitive part in `K[x]`.
///
/// - Does: Splits a dense univariate polynomial into `(content, primitive)`.
/// - Input: A dense coefficient array and a coefficient `domain`.
/// - Returns: A coefficient and a dense coefficient array.
/// - Limits: Exact rational-like domains are supported by the current content
///   helper.
pub fn dup_primitive(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[FieldElem]) raise PolyError {
  let coeffs = dup_strip(f)
  if coeffs.is_empty() {
    return (fe_from_int(0, domain), coeffs)
  }
  let content = dup_content(coeffs, domain)
  if fe_is_one(content) {
    (content, coeffs)
  } else {
    (content, dup_exquo_ground(coeffs, content, domain))
  }
}

///|
/// Compute ground content and primitive part in `K[X]`.
///
/// - Does: Splits a dense recursive polynomial into `(content, primitive)`.
/// - Input: A dense recursive polynomial, a level `u`, and a coefficient
///   `domain`.
/// - Returns: A coefficient and a dense recursive polynomial.
/// - Limits: Exact rational-like domains are supported by the current content
///   helper.
pub fn dmp_ground_primitive(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, DensePoly) raise PolyError {
  if u == 0 {
    let (content, primitive) = dup_primitive(dmp_to_coeffs(f), domain)
    return (content, dmp_from_coeffs(primitive))
  }
  if dmp_zero_p(f, u) {
    return (fe_from_int(0, domain), f)
  }
  let content = dmp_ground_content(f, u, domain)
  if fe_is_one(content) {
    (content, f)
  } else {
    (content, dmp_exquo_ground(f, content, u, domain))
  }
}

///|
fn densetools_centered_mod(
  c : FieldElem,
  p : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(p) {
    raise PolyError::DivisionByZero
  }
  match domain {
    Domain::ZZ => {
      let cr = fe_expect_rational(c)
      let pr = fe_expect_rational(p)
      let modulus = pr.numerator().to_int()
      if modulus == 0 {
        raise PolyError::DivisionByZero
      }
      let m = if modulus < 0 { -modulus } else { modulus }
      let mut r = cr.numerator().to_int() % m
      if r < 0 {
        r = r + m
      }
      if r > m / 2 {
        r = r - m
      }
      fe_from_int(r, domain)
    }
    _ => raise PolyError::BadModulus
  }
}

///|
/// Reduce coefficients modulo a ground constant.
///
/// - Does: Reduces every coefficient of `f` modulo `p`, centered over `ZZ`.
/// - Input: A dense coefficient array, a nonzero modulus coefficient, and a
///   coefficient `domain`.
/// - Returns: A normalized dense coefficient array.
/// - Limits: Current implementation supports the exact integer domain path.
pub fn dup_trunc(
  f : Array[FieldElem],
  p : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for c in f {
    out.push(densetools_centered_mod(c, p, domain))
  }
  dup_strip(out)
}

///|
/// Reduce recursive polynomial coefficients modulo a polynomial.
///
/// - Does: Reduces every coefficient of `f` modulo `p` in the remaining
///   variables.
/// - Input: A dense recursive polynomial `f`, modulus polynomial `p`, level `u`,
///   and coefficient `domain`.
/// - Returns: A normalized dense recursive polynomial.
/// - Limits: Inherits the current dense remainder implementation.
pub fn dmp_trunc(
  f : DensePoly,
  p : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  let v = u - 1
  let out : Array[DensePoly] = Array::new()
  for c in dmp_items(f) {
    out.push(dmp_rem(c, p, v, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
/// Reduce ground coefficients modulo a ground constant.
///
/// - Does: Applies `dup_trunc` recursively to all ground coefficients.
/// - Input: A dense recursive polynomial, a nonzero modulus coefficient, a level,
///   and a coefficient `domain`.
/// - Returns: A normalized dense recursive polynomial.
/// - Limits: Current implementation supports the exact integer domain path.
pub fn dmp_ground_trunc(
  f : DensePoly,
  p : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    return dmp_from_coeffs(dup_trunc(dmp_to_coeffs(f), p, domain))
  }
  let out : Array[DensePoly] = Array::new()
  for c in dmp_items(f) {
    out.push(dmp_ground_trunc(c, p, u - 1, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
/// Extract common ground content from two univariate polynomials.
///
/// - Does: Returns `(gcd_content, f/gcd_content, g/gcd_content)`.
/// - Input: Two dense coefficient arrays and a coefficient `domain`.
/// - Returns: A coefficient and two dense coefficient arrays.
/// - Limits: Exact rational-like domains are supported by the current content
///   helper.
pub fn dup_extract(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[FieldElem], Array[FieldElem]) raise PolyError {
  let fc = dup_content(f, domain)
  let gc = dup_content(g, domain)
  let common = field_elems_content([fc, gc], domain)
  if fe_is_one(common) {
    (common, dup_strip(f), dup_strip(g))
  } else {
    (
      common,
      dup_exquo_ground(f, common, domain),
      dup_exquo_ground(g, common, domain),
    )
  }
}

///|
/// Extract common ground content from two recursive polynomials.
///
/// - Does: Returns `(gcd_content, f/gcd_content, g/gcd_content)`.
/// - Input: Two dense recursive polynomials, a level `u`, and a coefficient
///   `domain`.
/// - Returns: A coefficient and two dense recursive polynomials.
/// - Limits: Exact rational-like domains are supported by the current content
///   helper.
pub fn dmp_ground_extract(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, DensePoly, DensePoly) raise PolyError {
  let fc = dmp_ground_content(f, u, domain)
  let gc = dmp_ground_content(g, u, domain)
  let common = field_elems_content([fc, gc], domain)
  if fe_is_one(common) {
    (common, f, g)
  } else {
    (
      common,
      dmp_exquo_ground(f, common, u, domain),
      dmp_exquo_ground(g, common, u, domain),
    )
  }
}

///|
fn densetools_add_real_imag_term(
  real_terms : Map[Monomial, FieldElem],
  imag_terms : Map[Monomial, FieldElem],
  coeff : FieldElem,
  degree : Int,
  k : Int,
  domain : Domain,
) -> Unit raise PolyError {
  let binom = fe_from_int(int_binomial(degree, k), domain)
  let term_coeff = fe_mul(coeff, binom)
  let mono = monomial_from_array([degree - k, k])
  match k % 4 {
    0 => add_term(real_terms, mono, term_coeff, domain)
    1 => add_term(imag_terms, mono, term_coeff, domain)
    2 => add_term(real_terms, mono, fe_neg(term_coeff), domain)
    _ => add_term(imag_terms, mono, fe_neg(term_coeff), domain)
  }
}

///|
/// Split `f(x + i*y)` into real and imaginary parts.
///
/// - Does: Expands a univariate polynomial after substituting `x + i*y` and
///   returns the real and imaginary bivariate dense polynomials.
/// - Input: A dense univariate coefficient array and a coefficient `domain`.
/// - Returns: `(real_part, imag_part)` as dense recursive polynomials in
///   `K[x, y]`.
/// - Limits: Only integer and rational exact coefficient domains are supported.
pub fn dup_real_imag(
  f : Array[FieldElem],
  domain : Domain,
) -> (DensePoly, DensePoly) raise PolyError {
  match domain {
    Domain::ZZ | Domain::QQ => ()
    _ => raise PolyError::DomainMismatch
  }
  let real_terms : Map[Monomial, FieldElem] = {}
  let imag_terms : Map[Monomial, FieldElem] = {}
  let coeffs = dup_strip(f)
  let degree = dup_degree(coeffs)
  if degree < 0 {
    return (dmp_zero(1), dmp_zero(1))
  }
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if fe_is_zero(coeff) {
      continue
    }
    let exp = degree - i
    for k in 0..<=exp {
      densetools_add_real_imag_term(
        real_terms, imag_terms, coeff, exp, k, domain,
      )
    }
  }
  (dmp_from_dict(real_terms, 1, domain), dmp_from_dict(imag_terms, 1, domain))
}

///|
/// Evaluate `f(-x)`.
///
/// - Does: Negates the coefficients of odd powers.
/// - Input: A dense univariate coefficient array and a coefficient `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Uses exact coefficient negation.
pub fn dup_mirror(
  f : Array[FieldElem],
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out = f.copy()
  let mut i = out.length() - 2
  while i >= 0 {
    out.set(i, fe_neg(out[i]))
    i = i - 2
  }
  dup_normal(out)
}

///|
/// Evaluate `f(a*x)`.
///
/// - Does: Scales coefficients by powers of `a`.
/// - Input: A dense coefficient array, scale `a`, and a coefficient `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Uses exact coefficient multiplication.
pub fn dup_scale(
  f : Array[FieldElem],
  a : FieldElem,
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return []
  }
  let out = f.copy()
  let n = out.length() - 1
  let mut b = a
  let mut i = n - 1
  while i >= 0 {
    out.set(i, fe_mul(b, out[i]))
    b = fe_mul(b, a)
    i = i - 1
  }
  dup_normal(out)
}

///|
/// Evaluate the Taylor shift `f(x + a)`.
///
/// - Does: Applies the in-place Taylor shift algorithm used by SymPy.
/// - Input: A dense coefficient array, shift `a`, and a coefficient `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Uses exact coefficient arithmetic.
pub fn dup_shift(
  f : Array[FieldElem],
  a : FieldElem,
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out = f.copy()
  let n = out.length() - 1
  let mut i = n
  while i > 0 {
    for j in 0..<i {
      out.set(j + 1, fe_add(out[j + 1], fe_mul(a, out[j])))
    }
    i = i - 1
  }
  dup_normal(out)
}

///|
fn densetools_nonzero_shift(values : Array[FieldElem]) -> Bool {
  for value in values {
    if !fe_is_zero(value) {
      return true
    }
  }
  false
}

///|
/// Evaluate the multivariate Taylor shift `f(X + A)`.
///
/// - Does: Recursively shifts lower variables, then shifts the main variable.
/// - Input: A dense recursive polynomial, shift vector `a`, level `u`, and a
///   coefficient `domain`.
/// - Returns: A dense recursive polynomial.
/// - Limits: Requires at least `u + 1` shift values.
pub fn dmp_shift(
  f : DensePoly,
  a : Array[FieldElem],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if a.length() <= u {
    raise PolyError::BadExponent
  }
  if u == 0 {
    return dmp_from_coeffs(dup_shift(dmp_to_coeffs(f), a[0], domain))
  }
  if dmp_zero_p(f, u) {
    return f
  }
  let a0 = a[0]
  let a1 = a[1:].to_owned()
  let items = dmp_items(f)
  let shifted : Array[DensePoly] = Array::new()
  if densetools_nonzero_shift(a1) {
    for c in items {
      shifted.push(dmp_shift(c, a1, u - 1, domain))
    }
  } else {
    for c in items {
      shifted.push(c)
    }
  }
  if !fe_is_zero(a0) {
    let mut i = shifted.length() - 1
    while i > 0 {
      for j in 0..<i {
        let afj = dmp_mul_ground(shifted[j], a0, u - 1, domain)
        shifted.set(j + 1, dmp_add(shifted[j + 1], afj, u - 1, domain))
      }
      i = i - 1
    }
  }
  dmp_strip(DensePoly::Poly(shifted))
}

///|
/// Evaluate `q**n * f(p/q)`.
///
/// - Does: Applies SymPy's dense functional transform algorithm.
/// - Input: Dense coefficient arrays `f`, `p`, `q`, and a coefficient `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Uses exact dense arithmetic.
pub fn dup_transform(
  f : Array[FieldElem],
  p : Array[FieldElem],
  q : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let ff = dup_strip(f)
  if ff.is_empty() {
    return []
  }
  let n = ff.length() - 1
  let powers : Array[Array[FieldElem]] = Array::new()
  powers.push([fe_from_int(1, domain)])
  for i in 0..<n {
    powers.push(dup_mul(powers[i], q, domain))
  }
  let mut h = [ff[0]]
  for i in 1..<ff.length() {
    h = dup_mul(h, p, domain)
    h = dup_add(h, dup_mul_ground(powers[i], ff[i], domain), domain)
  }
  h
}

///|
/// Evaluate `f(g)`.
///
/// - Does: Applies Horner composition for dense univariate polynomials.
/// - Input: Dense coefficient arrays `f`, `g`, and a coefficient `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Uses exact dense arithmetic.
pub fn dup_compose(
  f : Array[FieldElem],
  g : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let gg = dup_strip(g)
  if gg.length() <= 1 {
    let point = if gg.is_empty() { fe_from_int(0, domain) } else { gg[0] }
    return dup_strip([dup_eval(f, point, domain)])
  }
  let ff = dup_strip(f)
  if ff.is_empty() {
    return []
  }
  let mut h = [ff[0]]
  for i in 1..<ff.length() {
    h = dup_add_term(dup_mul(h, gg, domain), ff[i], 0, domain)
  }
  h
}

///|
/// Evaluate `f(g)` in `K[X]`.
///
/// - Does: Applies Horner composition for dense recursive polynomials.
/// - Input: Dense recursive polynomials `f`, `g`, a level `u`, and a coefficient
///   `domain`.
/// - Returns: A dense recursive polynomial.
/// - Limits: Uses exact dense arithmetic.
pub fn dmp_compose(
  f : DensePoly,
  g : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    return dmp_from_coeffs(
      dup_compose(dmp_to_coeffs(f), dmp_to_coeffs(g), domain),
    )
  }
  if dmp_zero_p(f, u) {
    return f
  }
  let items = dmp_items(f)
  let mut h = dmp_strip(DensePoly::Poly([items[0]]))
  for i in 1..<items.length() {
    h = dmp_add_term(dmp_mul(h, g, u, domain), items[i], 0, u, domain)
  }
  h
}

///|
/// Evaluate the tail variables of a dense recursive polynomial.
///
/// - Does: Substitutes values for the last `a.length()` variables.
/// - Input: A dense recursive polynomial, tail values, level `u`, and a
///   coefficient `domain`.
/// - Returns: The evaluated dense polynomial.
/// - Limits: Requires at most `u + 1` tail values.
pub fn dmp_eval_tail(
  f : DensePoly,
  a : Array[FieldElem],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if a.is_empty() {
    return f
  }
  if a.length() > u + 1 {
    raise PolyError::BadExponent
  }
  if dmp_zero_p(f, u) {
    return dmp_zero(u - a.length())
  }
  let mut cur = f
  let mut level = u
  let mut idx = a.length() - 1
  while idx >= 0 {
    cur = dmp_eval_in(cur, a[idx], level, level, domain)
    level = level - 1
    idx = idx - 1
  }
  cur
}

///|
/// Differentiate in one variable and evaluate that variable.
///
/// - Does: Computes `d/dx_j` order `m` and then substitutes `x_j = a`.
/// - Input: A dense recursive polynomial, derivative order, value, variable
///   index `j`, level `u`, and a coefficient `domain`.
/// - Returns: The differentiated-and-evaluated dense polynomial.
/// - Limits: Raises `PolyError::BadExponent` when `j` is outside `0..u`.
pub fn dmp_diff_eval_in(
  f : DensePoly,
  m : Int,
  a : FieldElem,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  dmp_eval_in(dmp_diff_in(f, m, j, u, domain), a, j, u, domain)
}

///|
/// Count sign variations in dense coefficient order.
///
/// - Does: Counts sign changes between consecutive nonzero coefficients.
/// - Input: A dense coefficient array and a coefficient `domain`.
/// - Returns: The number of sign variations.
/// - Limits: Supports ordered exact/real coefficient domains.
pub fn dup_sign_variations(
  f : Array[FieldElem],
  _domain : Domain,
) -> Int raise PolyError {
  let mut prev = fe_from_int(0, Domain::ZZ)
  let mut count = 0
  for coeff in f {
    if fe_is_negative(fe_mul(coeff, prev)) {
      count = count + 1
    }
    if !fe_is_zero(coeff) {
      prev = coeff
    }
  }
  count
}

///|
fn densetools_lcm_bigint(a : BigInt, b : BigInt) -> BigInt {
  if a.is_zero() || b.is_zero() {
    return BigInt::from_int(0)
  }
  let aa = bigint_abs(a)
  let bb = bigint_abs(b)
  let g = @symnum.gcd_bigint(aa, bb)
  aa.div(g).mul(bb)
}

///|
fn densetools_denominator_lcm(
  values : Array[FieldElem],
) -> BigInt raise PolyError {
  let mut common = BigInt::from_int(1)
  for value in values {
    let den = fe_expect_rational(value).denominator()
    common = densetools_lcm_bigint(common, den)
  }
  common
}

///|
fn densetools_clear_coeff(
  value : FieldElem,
  common : BigInt,
  domain : Domain,
) -> FieldElem raise PolyError {
  let q = fe_expect_rational(value)
  let scale = common.div(q.denominator())
  fe_from_rational(
    poly_rational_from_bigints(q.numerator().mul(scale), BigInt::from_int(1)),
    domain,
  )
}

///|
/// Clear rational denominators in `K[x]`.
///
/// - Does: Multiplies by the least common denominator of coefficients.
/// - Input: A dense coefficient array and a coefficient `domain`.
/// - Returns: `(common_denominator, cleared_polynomial)`.
/// - Limits: `convert` is accepted for API shape but coefficients remain encoded
///   as `FieldElem` values in this package.
pub fn dup_clear_denoms(
  f : Array[FieldElem],
  domain : Domain,
  convert? : Bool = false,
) -> (FieldElem, Array[FieldElem]) raise PolyError {
  ignore(convert)
  let common = densetools_denominator_lcm(f)
  let common_elem = fe_from_rational(
    poly_rational_from_bigints(common, BigInt::from_int(1)),
    domain,
  )
  if fe_is_one(common_elem) {
    return (common_elem, dup_strip(f))
  }
  let out : Array[FieldElem] = Array::new()
  for c in f {
    out.push(densetools_clear_coeff(c, common, domain))
  }
  (common_elem, dup_strip(out))
}

///|
fn densetools_dmp_denominator_lcm(
  f : DensePoly,
  u : Int,
) -> BigInt raise PolyError {
  if u == 0 {
    return densetools_denominator_lcm(dmp_to_coeffs(f))
  }
  let mut common = BigInt::from_int(1)
  for c in dmp_items(f) {
    common = densetools_lcm_bigint(
      common,
      densetools_dmp_denominator_lcm(c, u - 1),
    )
  }
  common
}

///|
/// Clear rational denominators in `K[X]`.
///
/// - Does: Multiplies by the least common denominator of all ground
///   coefficients.
/// - Input: A dense recursive polynomial, level `u`, and a coefficient `domain`.
/// - Returns: `(common_denominator, cleared_polynomial)`.
/// - Limits: `convert` is accepted for API shape but coefficients remain encoded
///   as `FieldElem` values in this package.
pub fn dmp_clear_denoms(
  f : DensePoly,
  u : Int,
  domain : Domain,
  convert? : Bool = false,
) -> (FieldElem, DensePoly) raise PolyError {
  ignore(convert)
  if u == 0 {
    let (common, cleared) = dup_clear_denoms(dmp_to_coeffs(f), domain)
    return (common, dmp_from_coeffs(cleared))
  }
  let common = densetools_dmp_denominator_lcm(f, u)
  let common_elem = fe_from_rational(
    poly_rational_from_bigints(common, BigInt::from_int(1)),
    domain,
  )
  if fe_is_one(common_elem) {
    (common_elem, f)
  } else {
    (common_elem, dmp_mul_ground(f, common_elem, u, domain))
  }
}

///|
fn densetools_ceil_log2(n : Int) -> Int {
  if n <= 1 {
    return 0
  }
  let mut pow = 1
  let mut exp = 0
  while pow < n {
    pow = pow * 2
    exp = exp + 1
  }
  exp
}

///|
/// Compute the inverse of `f` modulo `x**n`.
///
/// - Does: Uses SymPy's Newton iteration for univariate dense polynomials.
/// - Input: A dense coefficient array, precision `n`, and a field `domain`.
/// - Returns: A dense coefficient array.
/// - Limits: Requires an invertible trailing coefficient.
pub fn dup_revert(
  f : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return []
  }
  let mut g = [fe_inv(dup_TC(f))]
  let mut h = [
    fe_from_int(1, domain),
    fe_from_int(0, domain),
    fe_from_int(0, domain),
  ]
  let rounds = densetools_ceil_log2(n)
  let mut round = 1
  while round <= rounds {
    let a = dup_mul_ground(g, fe_from_int(2, domain), domain)
    let b = dup_mul(f, dup_sqr(g, domain), domain)
    g = dup_rem(dup_sub(a, b, domain), h, domain)
    h = dup_lshift(h, dup_degree(h), domain)
    round = round + 1
  }
  g
}

///|
/// Compute the inverse of `f` modulo `x**n` in `K[X]`.
///
/// - Does: Delegates to `dup_revert` for univariate input.
/// - Input: A dense recursive polynomial, precision `n`, level `u`, and a field
///   `domain`.
/// - Returns: A dense recursive polynomial.
/// - Limits: Raises `PolyError::NotUnivariate` for `u > 0`.
pub fn dmp_revert(
  f : DensePoly,
  n : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
  dmp_from_coeffs(dup_revert(dmp_to_coeffs(f), n, domain))
}

///|
fn densetools_dup_series_compose_rec(
  f : Array[FieldElem],
  g : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.length() == 1 {
    return [f[0]]
  }
  let m = f.length() / 2
  let split = f.length() - m
  let f_high = f[:split].to_owned()
  let f_low = f[split:].to_owned()
  let comp0 = densetools_dup_series_compose_rec(f_low, g, n, domain)
  let comp1 = densetools_dup_series_compose_rec(f_high, g, n, domain)
  let g_power = dup_series_pow(g, m, n, domain)
  let high_term = dup_series_mul(comp1, g_power, n, domain)
  dup_truncate(dup_add(high_term, comp0, domain), n, domain)
}

///|
/// Compose two univariate series modulo `x**n`.
///
/// - Does: Computes `f(g(x)) mod x**n` using SymPy's divide-and-conquer
///   composition helper.
/// - Input: Dense coefficient arrays `f`, `g`, precision `n`, and a coefficient
///   `domain`.
/// - Returns: A dense coefficient array truncated to precision `n`.
/// - Limits: Uses the current dense series multiplication/power helpers.
pub fn dup_series_compose(
  f : Array[FieldElem],
  g : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let ff = dup_truncate(f, n, domain)
  let gg = dup_truncate(g, n, domain)
  if gg.length() <= 1 {
    let point = if gg.is_empty() { fe_from_int(0, domain) } else { gg[0] }
    return dup_strip([dup_eval(ff, point, domain)])
  }
  if ff.is_empty() {
    return []
  }
  densetools_dup_series_compose_rec(ff, gg, n, domain)
}

///|
fn densetools_dup_series_reversion_small(
  f : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if n < 1 || n > 4 {
    raise PolyError::BadExponent
  }
  let truncated = dup_truncate(f, n, domain)
  let zero = fe_from_int(0, domain)
  let padded : Array[FieldElem] = Array::make(4 - truncated.length(), zero)
  for c in truncated {
    padded.push(c)
  }
  let a = padded[0]
  let b = padded[1]
  let c = padded[2]
  let cinv = fe_inv(c)
  let out : Array[FieldElem] = Array::make(n, zero)
  if n >= 2 {
    out.set(n - 2, cinv)
  }
  if n >= 3 {
    out.set(n - 3, fe_neg(fe_mul(b, fe_pow(cinv, 3))))
  }
  if n >= 4 {
    let two_b2 = fe_mul(fe_from_int(2, domain), fe_mul(b, b))
    let ac = fe_mul(a, c)
    out.set(n - 4, fe_mul(fe_sub(two_b2, ac), fe_pow(cinv, 5)))
  }
  dup_strip(out)
}

///|
fn densetools_ceil_sqrt(n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  let mut r = 0
  while r * r < n {
    r = r + 1
  }
  r
}

///|
fn densetools_div_ground_int(
  value : FieldElem,
  divisor : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  fe_mul(value, fe_inv(fe_from_int(divisor, domain)))
}

///|
/// Compute the compositional inverse of a univariate series.
///
/// - Does: Computes `g` such that `f(g(x)) = x mod x**n`, following SymPy's
///   Lagrange inversion path.
/// - Input: Dense coefficient array `f`, precision `n`, and a field `domain`.
/// - Returns: A dense coefficient array truncated to precision `n`.
/// - Limits: Requires zero constant term and an invertible linear coefficient.
pub fn dup_series_reversion(
  f : Array[FieldElem],
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return []
  }
  if !fe_is_zero(f[f.length() - 1]) {
    raise PolyError::BadExponent
  }
  if n <= 4 {
    return densetools_dup_series_reversion_small(f, n, domain)
  }
  let f1 = dup_rshift(f, 1, domain)
  let f1_inv = dup_revert(f1, n, domain)
  let h = dup_truncate(f1_inv, n, domain)
  let m = densetools_ceil_sqrt(n - 1)
  let powers : Array[Array[FieldElem]] = Array::new()
  powers.push(h)
  let mut pidx = 1
  while pidx < m {
    let h_prev = powers[powers.length() - 1]
    powers.push(dup_series_mul(h_prev, h, n, domain))
    pidx = pidx + 1
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(n, zero)
  let mut i = 1
  while i < m {
    let coeff = dup_nth(powers[i - 1], i - 1)
    out.set(n - i - 1, densetools_div_ground_int(coeff, i, domain))
    i = i + 1
  }
  let mut t = powers[m - 1]
  i = m
  while i < n {
    let coeff = dup_nth(t, i - 1)
    out.set(n - i - 1, densetools_div_ground_int(coeff, i, domain))
    let mut j = 1
    while j < m {
      if i + j >= n {
        break
      }
      let mut sum = zero
      for k in 0..<(i + j) {
        let c1 = dup_nth(t, k)
        let c2 = dup_nth(powers[j - 1], i + j - k - 1)
        sum = fe_add(sum, fe_mul(c1, c2))
      }
      out.set(n - i - j - 1, densetools_div_ground_int(sum, i + j, domain))
      j = j + 1
    }
    t = dup_series_mul(t, powers[m - 1], n, domain)
    i = i + m
  }
  dup_strip(out)
}

///|
fn densetools_from_low_coeffs(
  coeffs : Array[FieldElem],
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  let mut i = coeffs.length() - 1
  while i >= 0 {
    out.push(coeffs[i])
    i = i - 1
  }
  dup_strip(out)
}

///|
fn densetools_dup_right_decompose(
  f : Array[FieldElem],
  s : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let n = dup_degree(f)
  let lc = dup_LC(f)
  let r = n / s
  let zero = fe_from_int(0, domain)
  let coeffs : Array[FieldElem] = Array::make(s + 1, zero)
  coeffs.set(s, fe_from_int(1, domain))
  for i in 1..<s {
    let mut coeff = zero
    for j in 0..<i {
      let fc = dup_nth(f, n + j - i)
      let gc = coeffs[s - j]
      let scale = fe_from_int(i - r * j, domain)
      coeff = fe_add(coeff, fe_mul(scale, fe_mul(fc, gc)))
    }
    let denom = fe_mul(fe_from_int(i * r, domain), lc)
    coeffs.set(s - i, fe_mul(coeff, fe_inv(denom)))
  }
  densetools_from_low_coeffs(coeffs)
}

///|
fn densetools_dup_left_decompose(
  f : Array[FieldElem],
  h : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem]? raise PolyError {
  let coeffs : Array[FieldElem] = Array::new()
  let mut rest = dup_strip(f)
  while !rest.is_empty() {
    let (q, r) = dup_div(rest, h, domain)
    if dup_degree(r) > 0 {
      return None
    }
    coeffs.push(dup_LC(r))
    rest = q
  }
  Some(densetools_from_low_coeffs(coeffs))
}

///|
fn densetools_dup_decompose_once(
  f : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem])? raise PolyError {
  let df = dup_degree(f)
  for s in 2..<df {
    if df % s != 0 {
      continue
    }
    let h = densetools_dup_right_decompose(f, s, domain)
    match densetools_dup_left_decompose(f, h, domain) {
      Some(g) => return Some((g, h))
      None => ()
    }
  }
  None
}

///|
/// Compute functional decomposition of a univariate polynomial.
///
/// - Does: Returns `[f1, f2, ...]` such that `f = f1 o f2 o ...`.
/// - Input: A dense coefficient array and a coefficient `domain`.
/// - Returns: An array of dense coefficient arrays.
/// - Limits: Requires exact dense univariate arithmetic; decomposition over
///   finite-characteristic domains is not normalized as a separate path yet.
pub fn dup_decompose(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let mut current = dup_strip(f)
  let factors : Array[Array[FieldElem]] = Array::new()
  while true {
    match densetools_dup_decompose_once(current, domain) {
      Some((g, h)) => {
        factors.insert(0, h)
        current = g
      }
      None => break
    }
  }
  let out : Array[Array[FieldElem]] = Array::new()
  out.push(current)
  for factor in factors {
    out.push(factor)
  }
  out
}
