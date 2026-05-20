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
