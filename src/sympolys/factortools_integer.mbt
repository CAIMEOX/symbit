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
