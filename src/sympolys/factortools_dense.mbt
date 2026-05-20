///|
/// Dense factorization front doors mirroring SymPy's `factortools`.
///
/// Current Limits:
/// - `dup_*` covers the dense univariate symbolic front doors.
/// - `dmp_*` delegates to the univariate path for `u == 0`; recursive
///   multivariate dense factorization currently raises `PolyError::NotUnivariate`.

///|
fn fact_dense_require_dmp_univariate(u : Int) -> Unit raise PolyError {
  if u != 0 {
    raise PolyError::NotUnivariate
  }
}

///|
fn fact_dense_compare_factor(
  a : (Array[FieldElem], Int),
  b : (Array[FieldElem], Int),
) -> Int {
  let len_diff = a.0.length() - b.0.length()
  if len_diff != 0 {
    len_diff
  } else if a.1 != b.1 {
    a.1 - b.1
  } else {
    let a_text = a.0.map(c => c.to_string()).join(",")
    let b_text = b.0.map(c => c.to_string()).join(",")
    a_text.compare(b_text)
  }
}

///|
fn fact_dense_sort_factors(
  factors : Array[(Array[FieldElem], Int)],
) -> Array[(Array[FieldElem], Int)] {
  let out = factors.copy()
  out.sort_by(fact_dense_compare_factor)
  out
}

///|
fn fact_dense_dup_factor_list_include_from_parts(
  coeff : FieldElem,
  factors : Array[(Array[FieldElem], Int)],
  domain : Domain,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  if factors.is_empty() {
    [(dup_strip([coeff]), 1)]
  } else {
    let out : Array[(Array[FieldElem], Int)] = Array::new()
    let first = factors[0]
    out.push((dup_mul_ground(first.0, coeff, domain), first.1))
    for i in 1..<factors.length() {
      out.push(factors[i])
    }
    out
  }
}

///|
/// Factor a finite-field dense polynomial.
///
/// - Does: Converts `GF(p)` coefficients to the integer representation used by
///   `gf_factor`, factors there, then converts factors back to `FieldElem`.
/// - Input: Dense high-to-low coefficients over `Domain::GF(p)`.
/// - Returns: `(leading_coefficient, [(factor, multiplicity), ...])`.
/// - Limits: Only prime finite-field coefficient domains are accepted.
pub fn dup_gf_factor(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  let p = sqf_dense_gf_modulus(domain)
  let ints = sqf_dense_dup_to_gf_ints(f, p)
  let (coeff, factors) = gf_factor(ints, p)
  let out : Array[(Array[FieldElem], Int)] = Array::new()
  for item in factors {
    out.push((sqf_dense_gf_ints_to_dup(item.0, p), item.1))
  }
  (FieldElem::GFp(p, coeff), out)
}

///|
/// Multivariate finite-field dense factorization placeholder.
///
/// - Does: Matches SymPy's public `dmp_gf_factor` front door as an unsupported
///   multivariate finite-field path.
/// - Input: Recursive dense polynomial, level, and `GF(p)` domain.
/// - Returns: No value; this path raises.
/// - Limits: SymPy also leaves this front door unimplemented.
pub fn dmp_gf_factor(
  _f : DensePoly,
  _u : Int,
  _domain : Domain,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  raise PolyError::NotUnivariate
}

///|
/// Factor a dense polynomial including its content in the first factor.
///
/// - Does: Runs `dup_factor_list`, then multiplies the returned coefficient
///   into the first factor, following SymPy's `dup_factor_list_include`.
/// - Input: Dense high-to-low coefficients and a coefficient domain.
/// - Returns: `[(factor, multiplicity), ...]`, including the content.
/// - Limits: Same univariate factorization limits as `dup_factor_list`.
pub fn dup_factor_list_include(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  let (coeff, factors) = dup_factor_list(f, domain)
  fact_dense_dup_factor_list_include_from_parts(coeff, factors, domain)
}

///|
/// Factor a recursive dense polynomial.
///
/// - Does: Delegates to `dup_factor_list` for `u == 0`.
/// - Input: Recursive dense polynomial, level, and coefficient domain.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_factor_list(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  fact_dense_require_dmp_univariate(u)
  let (coeff, factors) = dup_factor_list(dmp_to_coeffs(f), domain)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  (coeff, out)
}

///|
/// Factor a recursive dense polynomial including content.
///
/// - Does: Delegates to `dup_factor_list_include` for `u == 0`.
/// - Input: Recursive dense polynomial, level, and coefficient domain.
/// - Returns: `[(factor, multiplicity), ...]`, including the content.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_factor_list_include(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Array[(DensePoly, Int)] raise PolyError {
  fact_dense_require_dmp_univariate(u)
  let factors = dup_factor_list_include(dmp_to_coeffs(f), domain)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  out
}

///|
/// Determine factor multiplicities by trial division.
///
/// - Does: Repeatedly divides `f` by each candidate factor and records the
///   multiplicity once the remainder becomes non-zero.
/// - Input: A dense polynomial, candidate dense factors, and a coefficient
///   domain.
/// - Returns: Sorted `(factor, multiplicity)` pairs.
/// - Limits: Raises `PolyError::PolynomialDivisionFailed` if a candidate does
///   not divide the remaining polynomial at least once.
pub fn dup_trial_division(
  f : Array[FieldElem],
  factors : Array[Array[FieldElem]],
  domain : Domain,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  let mut rest = dup_strip(f)
  let result : Array[(Array[FieldElem], Int)] = Array::new()
  for factor in factors {
    let trial = dup_strip(factor)
    let mut multiplicity = 0
    while true {
      let (q, r) = dup_div(rest, trial, domain)
      if r.is_empty() {
        rest = q
        multiplicity = multiplicity + 1
      } else {
        break
      }
    }
    if multiplicity == 0 {
      raise PolyError::PolynomialDivisionFailed
    }
    result.push((trial, multiplicity))
  }
  fact_dense_sort_factors(result)
}

///|
/// Determine recursive dense factor multiplicities by trial division.
///
/// - Does: Delegates to `dup_trial_division` for `u == 0`.
/// - Input: Recursive dense polynomial, candidate recursive dense factors,
///   level, and domain.
/// - Returns: Sorted `(factor, multiplicity)` pairs.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_trial_division(
  f : DensePoly,
  factors : Array[DensePoly],
  u : Int,
  domain : Domain,
) -> Array[(DensePoly, Int)] raise PolyError {
  fact_dense_require_dmp_univariate(u)
  let dup_factors = factors.map(item => dmp_to_coeffs(item))
  let result = dup_trial_division(dmp_to_coeffs(f), dup_factors, domain)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in result {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  out
}

///|
/// Test whether a dense polynomial is irreducible over its domain.
///
/// - Does: Factors the polynomial and applies SymPy's public predicate rule:
///   no factors is irreducible, one factor is irreducible only at
///   multiplicity `1`, and multiple factors is reducible.
/// - Input: Dense high-to-low coefficients and a coefficient domain.
/// - Returns: `true` when the factor list has no proper split.
/// - Limits: Same univariate factorization limits as `dup_factor_list`.
pub fn dup_irreducible_p(
  f : Array[FieldElem],
  domain : Domain,
) -> Bool raise PolyError {
  dmp_irreducible_p(dmp_from_coeffs(f), 0, domain)
}

///|
/// Test whether a recursive dense polynomial is irreducible.
///
/// - Does: Runs `dmp_factor_list` and follows SymPy's factor-count rule.
/// - Input: Recursive dense polynomial, level, and coefficient domain.
/// - Returns: `true` when the polynomial has no proper factorization.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_irreducible_p(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Bool raise PolyError {
  let (_, factors) = dmp_factor_list(f, u, domain)
  if factors.is_empty() {
    true
  } else if factors.length() > 1 {
    false
  } else {
    factors[0].1 == 1
  }
}
