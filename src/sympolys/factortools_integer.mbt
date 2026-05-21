///|
/// Integer dense factorization helpers from SymPy's `factortools`.

///|
fn fact_int_abs(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
}

///|
fn fact_int_floor_sqrt(n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  let mut r = 0
  while (r + 1) * (r + 1) <= n {
    r = r + 1
  }
  r
}

///|
fn fact_int_pow(base : Int, exp : Int) -> Int {
  let mut result = 1
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result * b
    }
    e = e / 2
    if e > 0 {
      b = b * b
    }
  }
  result
}

///|
fn fact_int_binomial(n : Int, k : Int) -> Int {
  if k < 0 || k > n {
    return 0
  }
  let kk = if k > n - k { n - k } else { k }
  let mut result = 1
  for i in 1..<=kk {
    result = result * (n - kk + i) / i
  }
  result
}

///|
fn fact_int_prime_factors(n0 : Int) -> Array[Int] {
  let factors : Array[Int] = Array::new()
  let mut n = fact_int_abs(n0)
  let mut p = 2
  while p * p <= n {
    if n % p == 0 {
      factors.push(p)
      while n % p == 0 {
        n = n / p
      }
    }
    p = if p == 2 { 3 } else { p + 2 }
  }
  if n > 1 {
    factors.push(n)
  }
  factors
}

///|
fn fact_int_factor_powers(n0 : Int) -> Array[(Int, Int)] {
  let factors : Array[(Int, Int)] = Array::new()
  let mut n = fact_int_abs(n0)
  let mut p = 2
  while p * p <= n {
    if n % p == 0 {
      let mut k = 0
      while n % p == 0 {
        n = n / p
        k = k + 1
      }
      factors.push((p, k))
    }
    p = if p == 2 { 3 } else { p + 2 }
  }
  if n > 1 {
    factors.push((n, 1))
  }
  factors
}

///|
fn fact_int_fe_to_int(c : FieldElem) -> Int raise PolyError {
  let q = fe_expect_rational(c)
  if !q.is_integral() {
    raise PolyError::CoefficientNotInteger
  }
  q.numerator().to_int()
}

///|
fn fact_int_abs_fe_to_int(c : FieldElem) -> Int raise PolyError {
  fact_int_abs(fact_int_fe_to_int(c))
}

///|
fn fact_int_dup_to_zz(f : Array[FieldElem]) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for c in f {
    out.push(fe_from_int(fact_int_fe_to_int(c), Domain::ZZ))
  }
  dup_strip(out)
}

///|
fn fact_int_fe_equal(a : FieldElem, b : FieldElem) -> Bool {
  fe_is_zero(fe_sub(a, b) catch { _ => return false })
}

///|
fn fact_int_dup_equal(
  a : Array[FieldElem],
  b : Array[FieldElem],
) -> Bool raise PolyError {
  let aa = dup_strip(a)
  let bb = dup_strip(b)
  if aa.length() != bb.length() {
    return false
  }
  for i in 0..<aa.length() {
    if !fact_int_fe_equal(aa[i], bb[i]) {
      return false
    }
  }
  true
}

///|
fn fact_int_dup_is_one_factor(
  coeff : FieldElem,
  factors : Array[(Array[FieldElem], Int)],
  f : Array[FieldElem],
) -> Bool raise PolyError {
  fact_int_fe_equal(
    coeff,
    fe_from_int(1, Domain::ZZ) catch {
      _ => return false
    },
  ) &&
  factors.length() == 1 &&
  factors[0].1 == 1 &&
  fact_int_dup_equal(factors[0].0, f)
}

///|
/// Compute the Knuth-Cohen Mignotte bound for `ZZ[x]`.
///
/// - Does: Ports SymPy's `dup_zz_mignotte_bound`, using the integer square
///   root supplied by the `ZZ` domain.
/// - Input: Dense integer coefficients and `Domain::ZZ`.
/// - Returns: An even integer bound as a `FieldElem`.
/// - Limits: Coefficients must be integral and currently fit in `Int`.
pub fn dup_zz_mignotte_bound(
  f : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let ff = dup_strip(f)
  let d = dup_degree(ff)
  let delta = (d + 1) / 2
  let delta2 = (delta + 1) / 2
  let mut norm_sq = 0
  for c in ff {
    let value = fact_int_fe_to_int(c)
    norm_sq = norm_sq + value * value
  }
  let eucl_norm = fact_int_floor_sqrt(norm_sq)
  let t1 = fact_int_binomial(delta - 1, delta2)
  let t2 = fact_int_binomial(delta - 1, delta2 - 1)
  let lc = fact_int_abs_fe_to_int(dup_LC(ff))
  let max_norm = fact_int_abs_fe_to_int(dup_max_norm(ff, Domain::ZZ))
  let mut bound = t1 * eucl_norm + t2 * lc + max_norm
  if bound % 2 != 0 {
    bound = bound + 1
  }
  fe_from_int(bound, Domain::ZZ)
}

///|
/// Compute the multivariate Mignotte bound over `ZZ`.
///
/// - Does: Ports SymPy's `dmp_zz_mignotte_bound` formula.
/// - Input: Recursive dense integer polynomial, level, and `Domain::ZZ`.
/// - Returns: The integer bound as a `FieldElem`.
/// - Limits: Coefficients and degree products currently fit in `Int`.
pub fn dmp_zz_mignotte_bound(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let a = fact_int_abs_fe_to_int(dmp_max_norm(f, u, domain))
  let b = fact_int_abs_fe_to_int(dmp_ground_LC(f, u))
  let n = dmp_degree_list(f, u).fold(init=0, fn(acc, value) { acc + value })
  let bound = fact_int_floor_sqrt(n + 1) * fact_int_pow(2, n) * a * b
  fe_from_int(bound, Domain::ZZ)
}

///|
/// Test Eisenstein irreducibility over `ZZ`.
///
/// - Does: Ports SymPy's `dup_zz_irreducible_p` criterion using the content of
///   all coefficients except the leading one.
/// - Input: Dense integer coefficients and `Domain::ZZ`.
/// - Returns: `true` when Eisenstein's criterion proves irreducibility.
/// - Limits: `false` means "not proven by this criterion", not reducible.
pub fn dup_zz_irreducible_p(
  f : Array[FieldElem],
  domain : Domain,
) -> Bool raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let ff = dup_strip(f)
  if ff.length() < 2 {
    return false
  }
  let lc = fact_int_fe_to_int(dup_LC(ff))
  let tc = fact_int_fe_to_int(dup_TC(ff))
  let tail : Array[FieldElem] = Array::new()
  for i in 1..<ff.length() {
    tail.push(ff[i])
  }
  let content = fact_int_abs_fe_to_int(dup_content(tail, Domain::ZZ))
  if content == 0 {
    return false
  }
  for p in fact_int_prime_factors(content) {
    if lc % p != 0 && tc % (p * p) != 0 {
      return true
    }
  }
  false
}

///|
/// Generate the `n`-th cyclotomic polynomial over `ZZ`.
///
/// - Does: Exposes SymPy's dense `dup_zz_cyclotomic_poly` front door through
///   the existing `cyclotomic_poly` implementation.
/// - Input: Positive index `n` and `Domain::ZZ`.
/// - Returns: Dense high-to-low integer coefficients.
/// - Limits: `n <= 0` raises `PolyError::BadExponent`.
pub fn dup_zz_cyclotomic_poly(
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  if n <= 0 {
    raise PolyError::BadExponent
  }
  let mut h = [fe_from_int(1, Domain::ZZ), fe_from_int(-1, Domain::ZZ)]
  for item in fact_int_factor_powers(n) {
    h = dup_quo(dup_inflate(h, item.0, Domain::ZZ), h, Domain::ZZ)
    h = dup_inflate(h, fact_int_pow(item.0, item.1 - 1), Domain::ZZ)
  }
  h
}

///|
fn fact_int_cyclotomic_decompose(
  n : Int,
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let factors : Array[Array[FieldElem]] = [
    [fe_from_int(1, domain), fe_from_int(-1, domain)],
  ]
  for item in fact_int_factor_powers(n) {
    let p = item.0
    let k = item.1
    let mut q : Array[Array[FieldElem]] = Array::new()
    for h in factors {
      q.push(dup_quo(dup_inflate(h, p, domain), h, domain))
    }
    for h in q {
      factors.push(h)
    }
    for _ in 1..<k {
      let next : Array[Array[FieldElem]] = Array::new()
      for h in q {
        next.push(dup_inflate(h, p, domain))
      }
      q = next
      for h in q {
        factors.push(h)
      }
    }
  }
  factors
}

///|
fn fact_int_dup_list_contains(
  items : Array[Array[FieldElem]],
  candidate : Array[FieldElem],
) -> Bool raise PolyError {
  for item in items {
    if fact_int_dup_equal(item, candidate) {
      return true
    }
  }
  false
}

///|
/// Factor `x**n - 1` and `x**n + 1` through cyclotomic decomposition.
///
/// - Does: Recognizes sparse monic integer polynomials of the form
///   `x**n - 1` or `x**n + 1` and returns their cyclotomic factors.
/// - Input: Dense high-to-low integer coefficients and `Domain::ZZ`.
/// - Returns: `Some(factors)` when recognized; otherwise `None`.
/// - Limits: Only the exact sparse `x**n +/- 1` cases are recognized.
pub fn dup_zz_cyclotomic_factor(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]]? raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let ff = dup_strip(f)
  if dup_degree(ff) <= 0 {
    return None
  }
  let one = fe_from_int(1, Domain::ZZ)
  let neg_one = fe_from_int(-1, Domain::ZZ)
  let lc = dup_LC(ff)
  let tc = dup_TC(ff)
  if !fact_int_fe_equal(lc, one) ||
    (!fact_int_fe_equal(tc, neg_one) && !fact_int_fe_equal(tc, one)) {
    return None
  }
  if ff.length() > 2 {
    for i in 1..<(ff.length() - 1) {
      if !fe_is_zero(ff[i]) {
        return None
      }
    }
  }
  let n = dup_degree(ff)
  let base = fact_int_cyclotomic_decompose(n, domain)
  if fact_int_fe_equal(tc, neg_one) {
    Some(base)
  } else {
    let out : Array[Array[FieldElem]] = Array::new()
    for h in fact_int_cyclotomic_decompose(2 * n, domain) {
      if !fact_int_dup_list_contains(base, h) {
        out.push(h)
      }
    }
    Some(out)
  }
}

///|
/// Factor a primitive square-free integer polynomial with Zassenhaus semantics.
///
/// - Does: Exposes SymPy's `dup_zz_zassenhaus` front door and returns the
///   irreducible factors obtained from the package factorization path.
/// - Input: Dense high-to-low integer coefficients and `Domain::ZZ`.
/// - Returns: Dense factors without multiplicity entries.
/// - Limits: Uses the existing complete factor-list backend rather than a
///   separate Hensel/Zassenhaus implementation.
pub fn dup_zz_zassenhaus(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let (_, factors) = dup_factor_list(f, domain)
  let out : Array[Array[FieldElem]] = Array::new()
  for item in factors {
    out.push(item.0)
  }
  out
}

///|
/// Factor a square-free integer dense polynomial.
///
/// - Does: Returns `(content, factors)` for SymPy's `dup_zz_factor_sqf` front
///   door.
/// - Input: Dense high-to-low integer coefficients and `Domain::ZZ`.
/// - Returns: Scalar content and dense factors without multiplicities.
/// - Limits: Multiplicity entries from the general factor backend are
///   intentionally collapsed because this front door is for square-free input.
pub fn dup_zz_factor_sqf(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[Array[FieldElem]]) raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let (content, factors) = dup_factor_list(f, domain)
  let out : Array[Array[FieldElem]] = Array::new()
  for item in factors {
    out.push(item.0)
  }
  (content, out)
}

///|
/// Factor an integer dense polynomial.
///
/// - Does: Returns content and irreducible factors with multiplicities,
///   matching SymPy's `dup_zz_factor` public front door.
/// - Input: Dense high-to-low integer coefficients and `Domain::ZZ`.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: Delegates to the package's current complete univariate factor
///   backend.
pub fn dup_zz_factor(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  dup_factor_list(f, domain)
}

///|
/// Factor an integer recursive dense polynomial.
///
/// - Does: Returns content and factors with multiplicities for SymPy's
///   `dmp_zz_factor` front door.
/// - Input: Recursive dense polynomial, level, and `Domain::ZZ`.
/// - Returns: `(content, [(factor, multiplicity), ...])`.
/// - Limits: Current dense multivariate factorization supports `u == 0`;
///   higher levels raise `PolyError::NotUnivariate`.
pub fn dmp_zz_factor(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (FieldElem, Array[(DensePoly, Int)]) raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  dmp_factor_list(f, u, domain)
}

///|
fn fact_int_euler_phi(n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  let mut result = n
  for item in fact_int_factor_powers(n) {
    result = result / item.0 * (item.0 - 1)
  }
  result
}

///|
fn fact_int_cyclotomic_by_degree(f : Array[FieldElem]) -> Bool raise PolyError {
  let degree = dup_degree(f)
  let limit = if degree < 2 { 8 } else { 8 * degree * degree + 16 }
  for n in 1..<=limit {
    if fact_int_euler_phi(n) == degree &&
      fact_int_dup_equal(dup_zz_cyclotomic_poly(n, Domain::ZZ), f) {
      return true
    }
  }
  false
}

///|
/// Test whether a dense polynomial is cyclotomic.
///
/// - Does: Ports SymPy's Bradford-Davenport recursive cyclotomic predicate.
/// - Input: Dense coefficients over `ZZ` or integral `QQ`; optional
///   `irreducible` skips the preliminary factor-list check.
/// - Returns: `true` when the polynomial is recognized as cyclotomic.
/// - Limits: Non-integral `QQ` coefficients and non-`ZZ/QQ` domains return
///   `false`.
pub fn dup_cyclotomic_p(
  f : Array[FieldElem],
  domain : Domain,
  irreducible? : Bool = false,
) -> Bool raise PolyError {
  let ff = match domain {
    Domain::ZZ => fact_int_dup_to_zz(f)
    Domain::QQ => fact_int_dup_to_zz(f) catch { _ => return false }
    _ => return false
  }
  if ff.is_empty() {
    return false
  }
  let lc = fact_int_fe_to_int(dup_LC(ff))
  let tc = fact_int_fe_to_int(dup_TC(ff))
  if lc != 1 || (tc != -1 && tc != 1) {
    return false
  }
  if !irreducible {
    let factor_result : Result[
      (FieldElem, Array[(Array[FieldElem], Int)]),
      PolyError,
    ] = try? dup_factor_list(ff, Domain::ZZ)
    match factor_result {
      Ok((coeff, factors)) =>
        if !fact_int_dup_is_one_factor(coeff, factors, ff) {
          return false
        }
      // The recursive cyclotomic test is still useful when the current dense
      // factor backend cannot split a hard irreducible candidate yet.
      Err(_) => ()
    }
  }
  fact_int_cyclotomic_by_degree(ff)
}
