///|
/// Dense square-free decomposition front doors.
///
/// Current Limits:
/// - `dup_*` follows the single-variable dense algorithms used by SymPy.
/// - `dmp_*` is exact for `u == 0`; higher recursive levels still depend on
///   multivariate dense GCD and currently raise `PolyError::NotUnivariate`.

///|
fn sqf_dense_domain_is_gf(domain : Domain) -> Bool {
  match domain {
    Domain::GF(_) => true
    _ => false
  }
}

///|
fn sqf_dense_gf_modulus(domain : Domain) -> Int raise PolyError {
  match domain {
    Domain::GF(p) => p
    _ => raise PolyError::DomainMismatch
  }
}

///|
fn sqf_dense_fe_to_gf_int(c : FieldElem, p : Int) -> Int raise PolyError {
  match c {
    FieldElem::GFp(q, value) =>
      if p == q {
        value
      } else {
        raise PolyError::DomainMismatch
      }
    _ => fe_expect_rational(c).numerator().to_int()
  }
}

///|
fn sqf_dense_dup_to_gf_ints(
  f : Array[FieldElem],
  p : Int,
) -> Array[Int] raise PolyError {
  let out : Array[Int] = Array::new()
  for c in f {
    out.push(sqf_dense_fe_to_gf_int(c, p))
  }
  gf_trunc(out, p)
}

///|
fn sqf_dense_gf_ints_to_dup(
  f : Array[Int],
  p : Int,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for c in gf_trunc(f, p) {
    out.push(FieldElem::GFp(p, c))
  }
  dup_strip(out)
}

///|
fn sqf_dense_coeff_neg(c : FieldElem) -> FieldElem {
  fe_neg(c)
}

///|
fn sqf_dense_require_dmp_univariate(u : Int) -> Unit raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
}

///|
/// Test whether a dense univariate polynomial is square-free.
///
/// - Does: Checks whether `gcd(f, diff(f))` has degree zero.
/// - Input: Dense high-to-low coefficients and a coefficient `Domain`.
/// - Returns: `true` when no nonconstant repeated factor is present.
/// - Limits: Uses the available dense GCD front door for the coefficient
///   domain.
pub fn dup_sqf_p(f : Array[FieldElem], domain : Domain) -> Bool raise PolyError {
  let ff = dup_strip(f)
  if ff.is_empty() {
    return true
  }
  let g = dup_gcd(ff, dup_diff(ff, 1, domain), domain)
  dup_degree(g) == 0
}

///|
/// Test whether a recursive dense polynomial is square-free.
///
/// - Does: Delegates to `dup_sqf_p` for `u == 0`.
/// - Input: A recursive dense polynomial, level `u`, and coefficient domain.
/// - Returns: `true` when the univariate dense polynomial is square-free.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_sqf_p(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Bool raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  dup_sqf_p(dmp_to_coeffs(f), domain)
}

///|
/// Compute the square-free part over a prime finite field.
///
/// - Does: Converts dense `GF(p)` coefficients to the integer representation
///   expected by `gf_sqf_part`, then converts the result back to `FieldElem`.
/// - Input: Dense high-to-low coefficients over `Domain::GF(p)`.
/// - Returns: A monic dense square-free part over the same field.
/// - Limits: Only prime-field dense coefficients are accepted.
pub fn dup_gf_sqf_part(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let p = sqf_dense_gf_modulus(domain)
  let ints = sqf_dense_dup_to_gf_ints(f, p)
  sqf_dense_gf_ints_to_dup(gf_sqf_part(ints, p), p)
}

///|
/// Compute the recursive dense finite-field square-free part.
///
/// - Does: Delegates to `dup_gf_sqf_part` for `u == 0`.
/// - Input: A recursive dense polynomial over `Domain::GF(p)`.
/// - Returns: The square-free part as `DensePoly`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`, matching the current
///   lack of multivariate finite-field dense support.
pub fn dmp_gf_sqf_part(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  dmp_from_coeffs(dup_gf_sqf_part(dmp_to_coeffs(f), domain))
}

///|
/// Return the square-free part of a dense univariate polynomial.
///
/// - Does: Divides by `gcd(f, diff(f))`, then normalizes to monic form over
///   fields or primitive form over rings.
/// - Input: Dense high-to-low coefficients and a coefficient domain.
/// - Returns: Dense high-to-low coefficients for the square-free part.
/// - Limits: Multivariate structure is not represented by this `dup` front
///   door.
pub fn dup_sqf_part(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if sqf_dense_domain_is_gf(domain) {
    return dup_gf_sqf_part(f, domain)
  }
  let mut ff = dup_strip(f)
  if ff.is_empty() {
    return ff
  }
  if fe_is_negative(dup_LC(ff)) {
    ff = dup_neg(ff, domain)
  }
  let gcd = dup_gcd(ff, dup_diff(ff, 1, domain), domain)
  let sqf = dup_quo(ff, gcd, domain)
  if domain_is_field_pred(domain) {
    dup_monic(sqf, domain)
  } else {
    dup_primitive(sqf, domain).1
  }
}

///|
/// Return the square-free part of a recursive dense polynomial.
///
/// - Does: Delegates to `dup_sqf_part` for `u == 0`.
/// - Input: A recursive dense polynomial, level `u`, and coefficient domain.
/// - Returns: The square-free part as `DensePoly`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_sqf_part(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  dmp_from_coeffs(dup_sqf_part(dmp_to_coeffs(f), domain))
}

///|
/// Compute square-free decomposition over a prime finite field.
///
/// - Does: Uses `gf_sqf_list` and converts factors back to dense `FieldElem`
///   coefficients.
/// - Input: Dense `GF(p)` coefficients and `Domain::GF(p)`.
/// - Returns: `(leading_coefficient, factor/multiplicity pairs)`.
/// - Limits: The `all` flag is accepted for API parity but finite-field
///   low-level support currently follows the exposed `gf_sqf_list` behavior.
pub fn dup_gf_sqf_list(
  f : Array[FieldElem],
  domain : Domain,
  all? : Bool = false,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  ignore(all)
  let p = sqf_dense_gf_modulus(domain)
  let ints = sqf_dense_dup_to_gf_ints(f, p)
  let (coeff, factors) = gf_sqf_list(ints, p)
  let out : Array[(Array[FieldElem], Int)] = Array::new()
  for item in factors {
    out.push((sqf_dense_gf_ints_to_dup(item.0, p), item.1))
  }
  (FieldElem::GFp(p, coeff), out)
}

///|
/// Compute recursive dense finite-field square-free decomposition.
///
/// - Does: Delegates to `dup_gf_sqf_list` for `u == 0`.
/// - Input: A recursive dense polynomial over `Domain::GF(p)`.
/// - Returns: `(leading_coefficient, factor/multiplicity pairs)`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_gf_sqf_list(
  f : DensePoly,
  u : Int,
  domain : Domain,
  all? : Bool = false,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  let (coeff, factors) = dup_gf_sqf_list(dmp_to_coeffs(f), domain, all~)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  (coeff, out)
}

///|
/// Return the square-free decomposition of a dense univariate polynomial.
///
/// - Does: Ports SymPy's Yun decomposition: normalize content, compute
///   `gcd(f, f')`, then peel factors by increasing multiplicity.
/// - Input: Dense high-to-low coefficients, a domain, and optional `all`.
/// - Returns: `(content, Array[(factor, multiplicity)])`.
/// - Limits: The input is a single-variable dense polynomial.
pub fn dup_sqf_list(
  f : Array[FieldElem],
  domain : Domain,
  all? : Bool = false,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  if sqf_dense_domain_is_gf(domain) {
    return dup_gf_sqf_list(f, domain, all~)
  }
  let f_orig = dup_strip(f)
  if f_orig.is_empty() {
    return (fe_from_int(0, domain), [])
  }
  let mut ff = f_orig
  let mut coeff : FieldElem = fe_from_int(1, domain)
  if domain_is_field_pred(domain) {
    coeff = dup_LC(ff)
    ff = dup_monic(ff, domain)
  } else {
    let primitive = dup_primitive(ff, domain)
    coeff = primitive.0
    ff = primitive.1
    if !ff.is_empty() && fe_is_negative(dup_LC(ff)) {
      ff = dup_neg(ff, domain)
      coeff = sqf_dense_coeff_neg(coeff)
    }
  }
  if dup_degree(ff) <= 0 {
    return (coeff, [])
  }
  let result : Array[(Array[FieldElem], Int)] = Array::new()
  let mut i = 1
  let h0 = dup_diff(ff, 1, domain)
  let inner0 = dup_inner_gcd(ff, h0, domain)
  let mut p = inner0.1
  let mut q = inner0.2
  while true {
    let d = dup_diff(p, 1, domain)
    let h = dup_sub(q, d, domain)
    if h.is_empty() {
      result.push((p, i))
      break
    }
    let inner = dup_inner_gcd(p, h, domain)
    let g = inner.0
    p = inner.1
    q = inner.2
    if all || dup_degree(g) > 0 {
      result.push((g, i))
    }
    i = i + 1
  }
  (coeff, result)
}

///|
/// Return square-free decomposition with content included as a factor.
///
/// - Does: Calls `dup_sqf_list` and folds the scalar content into the first
///   multiplicity-one factor when possible.
/// - Input: Dense high-to-low coefficients, a domain, and optional `all`.
/// - Returns: `Array[(factor, multiplicity)]`.
/// - Limits: Same as `dup_sqf_list`.
pub fn dup_sqf_list_include(
  f : Array[FieldElem],
  domain : Domain,
  all? : Bool = false,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  let (coeff, factors) = dup_sqf_list(f, domain, all~)
  if factors.length() > 0 && factors[0].1 == 1 {
    let out : Array[(Array[FieldElem], Int)] = Array::new()
    out.push((dup_mul_ground(factors[0].0, coeff, domain), 1))
    for i in 1..<factors.length() {
      out.push(factors[i])
    }
    out
  } else {
    let out : Array[(Array[FieldElem], Int)] = [(dup_strip([coeff]), 1)]
    for item in factors {
      out.push(item)
    }
    out
  }
}

///|
/// Return recursive dense square-free decomposition.
///
/// - Does: Delegates to `dup_sqf_list` for `u == 0`.
/// - Input: A recursive dense polynomial, level `u`, domain, and optional
///   `all`.
/// - Returns: `(content, Array[(factor, multiplicity)])`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_sqf_list(
  f : DensePoly,
  u : Int,
  domain : Domain,
  all? : Bool = false,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  let (coeff, factors) = dup_sqf_list(dmp_to_coeffs(f), domain, all~)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  (coeff, out)
}

///|
/// Return recursive dense square-free decomposition including content.
///
/// - Does: Delegates to `dup_sqf_list_include` for `u == 0`.
/// - Input: A recursive dense polynomial, level `u`, domain, and optional
///   `all`.
/// - Returns: `Array[(factor, multiplicity)]`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_sqf_list_include(
  f : DensePoly,
  u : Int,
  domain : Domain,
  all? : Bool = false,
) -> Array[(DensePoly, Int)] raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  let factors = dup_sqf_list_include(dmp_to_coeffs(f), domain, all~)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  out
}

///|
/// Compute greatest factorial factorization for dense univariate input.
///
/// - Does: Ports SymPy's recursive `dup_gff_list`: recurse on
///   `gcd(f, shift(f, 1))`, adjust shifted factors, then return the residual
///   degree-one layer first.
/// - Input: A non-zero dense univariate polynomial and a coefficient domain.
/// - Returns: `Array[(factor, multiplicity)]`.
/// - Limits: Zero input raises `PolyError::BadExponent`.
pub fn dup_gff_list(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  let mut ff = dup_strip(f)
  if ff.is_empty() {
    raise PolyError::BadExponent
  }
  ff = dup_monic(ff, domain)
  if dup_degree(ff) == 0 {
    return []
  }
  let one = fe_from_int(1, domain)
  let mut g = dup_gcd(ff, dup_shift(ff, one, domain), domain)
  let h_factors = dup_gff_list(g, domain)
  let out : Array[(Array[FieldElem], Int)] = Array::new()
  for item in h_factors {
    let shift_amount = fe_neg(fe_from_int(item.1, domain))
    g = dup_mul(g, dup_shift(item.0, shift_amount, domain), domain)
    out.push((item.0, item.1 + 1))
  }
  let rest = dup_quo(ff, g, domain)
  if dup_degree(rest) == 0 {
    out
  } else {
    let result : Array[(Array[FieldElem], Int)] = [(rest, 1)]
    for item in out {
      result.push(item)
    }
    result
  }
}

///|
/// Compute greatest factorial factorization for recursive dense input.
///
/// - Does: Delegates to `dup_gff_list` for `u == 0`.
/// - Input: A recursive dense polynomial, level `u`, and domain.
/// - Returns: `Array[(factor, multiplicity)]`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_gff_list(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Array[(DensePoly, Int)] raise PolyError {
  sqf_dense_require_dmp_univariate(u)
  let factors = dup_gff_list(dmp_to_coeffs(f), domain)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  out
}
