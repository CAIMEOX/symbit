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
fn fact_dense_gaussian_alg_domain() -> Domain raise PolyError {
  let i = Expr::Symbol("I")
  let minpoly = PolyBuilder::new(["I"], Domain::QQ).from_expr(
    (i ^ int(2)) + int(1),
  )
  Domain::AlgExt(Domain::QQ, ["I"], [minpoly.to_expr()])
}

///|
fn fact_dense_gaussian_parts(
  domain : Domain,
) -> (Domain, Poly, String) raise PolyError {
  match domain {
    Domain::AlgExt(base, gens, rels) => {
      let (minpoly, gen) = load_algext_minpoly(base, gens, rels)
      (base, minpoly, gen)
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
fn fact_dense_gaussian_to_alg(
  coeff : FieldElem,
  alg_domain : Domain,
) -> FieldElem raise PolyError {
  let (base, minpoly, gen) = fact_dense_gaussian_parts(alg_domain)
  match coeff {
    FieldElem::QQ(value) =>
      FieldElem::AlgExt(base, [FieldElem::QQ(value)], minpoly, gen)
    FieldElem::CC(real, imag) => {
      let coeffs = if imag.is_zero() {
        [FieldElem::QQ(real)]
      } else {
        [FieldElem::QQ(real), FieldElem::QQ(imag)]
      }
      FieldElem::AlgExt(base, coeffs, minpoly, gen)
    }
    FieldElem::AlgExt(_, _, _, _) => coeff
    _ => raise PolyError::DomainMismatch
  }
}

///|
fn fact_dense_gaussian_from_alg(
  coeff : FieldElem,
  target : Domain,
) -> FieldElem raise PolyError {
  let zero = @symnum.BigRational::zero()
  let (real, imag) = match coeff {
    FieldElem::QQ(value) => (value, zero)
    FieldElem::CC(real, imag) => (real, imag)
    FieldElem::AlgExt(_, coeffs, _, _) => {
      let real = if coeffs.length() > 0 {
        fe_expect_rational(coeffs[0])
      } else {
        zero
      }
      let imag = if coeffs.length() > 1 {
        fe_expect_rational(coeffs[1])
      } else {
        zero
      }
      for i in 2..<coeffs.length() {
        if !fe_is_zero(coeffs[i]) {
          raise PolyError::DomainMismatch
        }
      }
      (real, imag)
    }
    _ => raise PolyError::DomainMismatch
  }
  match target {
    Domain::ZZ_I => {
      if !real.is_integral() || !imag.is_integral() {
        raise PolyError::CoefficientNotInteger
      }
      FieldElem::CC(real, imag)
    }
    Domain::QQ_I => FieldElem::CC(real, imag)
    _ => raise PolyError::DomainMismatch
  }
}

///|
fn fact_dense_convert_gaussian_to_alg(
  f : Array[FieldElem],
  alg_domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for coeff in f {
    out.push(fact_dense_gaussian_to_alg(coeff, alg_domain))
  }
  dup_strip(out)
}

///|
fn fact_dense_convert_alg_to_gaussian(
  f : Array[FieldElem],
  target : Domain,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for coeff in f {
    out.push(fact_dense_gaussian_from_alg(coeff, target))
  }
  dup_strip(out)
}

///|
fn fact_dense_convert_alg_factors_to_gaussian(
  factors : Array[(Array[FieldElem], Int)],
  target : Domain,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  let out : Array[(Array[FieldElem], Int)] = Array::new()
  for item in factors {
    out.push((fact_dense_convert_alg_to_gaussian(item.0, target), item.1))
  }
  out.sort_by(fact_dense_compare_gaussian_factor)
  out
}

///|
fn fact_dense_gaussian_coeff_key(coeff : FieldElem) -> String {
  match coeff {
    FieldElem::CC(real, imag) => {
      let sign_key = if imag.numerator().op_lt(BigInt::from_int(0)) {
        "0"
      } else {
        "1"
      }
      let imag_abs = if imag.numerator().op_lt(BigInt::from_int(0)) {
        imag.neg_r()
      } else {
        imag
      }
      "\{real}:\{sign_key}:\{imag_abs}"
    }
    _ => coeff.to_string()
  }
}

///|
fn fact_dense_gaussian_factor_key(factor : Array[FieldElem]) -> String {
  factor.map(fact_dense_gaussian_coeff_key).join(",")
}

///|
fn fact_dense_compare_gaussian_factor(
  a : (Array[FieldElem], Int),
  b : (Array[FieldElem], Int),
) -> Int {
  let len_diff = a.0.length() - b.0.length()
  if len_diff != 0 {
    len_diff
  } else if a.1 != b.1 {
    a.1 - b.1
  } else {
    fact_dense_gaussian_factor_key(a.0).compare(
      fact_dense_gaussian_factor_key(b.0),
    )
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
fn fact_dense_dmp_key(f : DensePoly) -> String {
  match f {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) =>
      "[" + items.map(item => fact_dense_dmp_key(item)).join(",") + "]"
  }
}

///|
fn fact_dense_compare_dmp_factor(
  a : (DensePoly, Int),
  b : (DensePoly, Int),
) -> Int {
  if a.1 != b.1 {
    return a.1 - b.1
  }
  fact_dense_dmp_key(b.0).compare(fact_dense_dmp_key(a.0))
}

///|
fn fact_dense_sort_dmp_factors(
  factors : Array[(DensePoly, Int)],
) -> Array[(DensePoly, Int)] {
  let out = factors.copy()
  out.sort_by(fact_dense_compare_dmp_factor)
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
/// Factor a dense polynomial over an algebraic extension.
///
/// - Does: Mirrors SymPy `dup_ext_factor` for the public front door by
///   factoring in the supplied algebraic extension domain.
/// - Input: Dense high-to-low coefficients over `Domain::AlgExt`.
/// - Returns: `(leading/content coefficient, [(factor, multiplicity), ...])`.
/// - Limits: Uses the package algebraic-extension factor-list backend; domains
///   that are not algebraic extensions raise `PolyError::DomainMismatch`.
pub fn dup_ext_factor(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  match domain {
    Domain::AlgExt(_, _, _) => dup_factor_list(f, domain)
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Factor a recursive dense polynomial over an algebraic extension.
///
/// - Does: Mirrors SymPy `dmp_ext_factor` for the public front door.
/// - Input: Recursive dense polynomial, level, and `Domain::AlgExt`.
/// - Returns: `(leading/content coefficient, [(factor, multiplicity), ...])`.
/// - Limits: The current recursive dense factor backend supports `u == 0`;
///   higher levels raise `PolyError::NotUnivariate`.
pub fn dmp_ext_factor(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  match domain {
    Domain::AlgExt(_, _, _) => dmp_factor_list(f, u, domain)
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Factor a dense polynomial over Gaussian rationals.
///
/// - Does: Mirrors SymPy's `dup_qq_i_factor` by converting `QQ_I` to the
///   algebraic field `QQ<I>`, factoring there, then converting factors back.
/// - Input: Dense high-to-low coefficients over `Domain::QQ_I`.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: Shares the current algebraic-extension factorization limits.
pub fn dup_qq_i_factor(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  if domain.not_equal(Domain::QQ_I) {
    raise PolyError::DomainMismatch
  }
  let alg_domain = fact_dense_gaussian_alg_domain()
  let alg_f = fact_dense_convert_gaussian_to_alg(f, alg_domain)
  let (coeff, factors) = dup_ext_factor(alg_f, alg_domain)
  (
    fact_dense_gaussian_from_alg(coeff, Domain::QQ_I),
    fact_dense_convert_alg_factors_to_gaussian(factors, Domain::QQ_I),
  )
}

///|
/// Factor a dense polynomial over Gaussian integers.
///
/// - Does: Mirrors SymPy's `dup_zz_i_factor` main path by factoring over
///   `QQ_I` and returning Gaussian-integer coefficients when the converted
///   factors are already integral.
/// - Input: Dense high-to-low coefficients over `Domain::ZZ_I`.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: Full Gaussian integer primitive normalization with non-trivial
///   denominators is not yet expanded; non-integral converted coefficients
///   raise `PolyError::CoefficientNotInteger`.
pub fn dup_zz_i_factor(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  if domain.not_equal(Domain::ZZ_I) {
    raise PolyError::DomainMismatch
  }
  let qq_f = f.map(coeff => fact_dense_gaussian_from_alg(coeff, Domain::QQ_I))
  let (coeff, factors) = dup_qq_i_factor(qq_f, Domain::QQ_I)
  (
    fact_dense_gaussian_from_alg(coeff, Domain::ZZ_I),
    factors.map(item => {
      (fact_dense_convert_alg_to_gaussian(item.0, Domain::ZZ_I), item.1)
    }),
  )
}

///|
/// Factor a recursive dense polynomial over Gaussian rationals.
///
/// - Does: Delegates to `dup_qq_i_factor` for `u == 0`.
/// - Input: Recursive dense polynomial, level, and `Domain::QQ_I`.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`.
pub fn dmp_qq_i_factor(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  fact_dense_require_dmp_univariate(u)
  let (coeff, factors) = dup_qq_i_factor(dmp_to_coeffs(f), domain)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  (coeff, out)
}

///|
/// Factor a recursive dense polynomial over Gaussian integers.
///
/// - Does: Delegates to `dup_zz_i_factor` for `u == 0`.
/// - Input: Recursive dense polynomial, level, and `Domain::ZZ_I`.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: `u > 0` raises `PolyError::NotUnivariate`; denominator-heavy
///   primitive normalization follows the univariate front-door limit.
pub fn dmp_zz_i_factor(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  fact_dense_require_dmp_univariate(u)
  let (coeff, factors) = dup_zz_i_factor(dmp_to_coeffs(f), domain)
  let out : Array[(DensePoly, Int)] = Array::new()
  for item in factors {
    out.push((dmp_from_coeffs(item.0), item.1))
  }
  (coeff, out)
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
/// - Limits: Raises `PolyError::PolynomialDivisionFailed` if a candidate does
///   not divide `f`.
pub fn dmp_trial_division(
  f : DensePoly,
  factors : Array[DensePoly],
  u : Int,
  domain : Domain,
) -> Array[(DensePoly, Int)] raise PolyError {
  if u == 0 {
    let dup_factors = factors.map(item => dmp_to_coeffs(item))
    let result = dup_trial_division(dmp_to_coeffs(f), dup_factors, domain)
    let out : Array[(DensePoly, Int)] = Array::new()
    for item in result {
      out.push((dmp_from_coeffs(item.0), item.1))
    }
    return out
  }
  let mut rest = f
  let result : Array[(DensePoly, Int)] = Array::new()
  for factor in factors {
    let mut multiplicity = 0
    while true {
      let (q, r) = dmp_div(rest, factor, u, domain)
      if dmp_zero_p(r, u) {
        rest = q
        multiplicity = multiplicity + 1
      } else {
        break
      }
    }
    if multiplicity == 0 {
      raise PolyError::PolynomialDivisionFailed
    }
    result.push((factor, multiplicity))
  }
  fact_dense_sort_dmp_factors(result)
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
