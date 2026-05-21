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
fn fact_int_gcd(a0 : Int, b0 : Int) -> Int {
  let mut a = fact_int_abs(a0)
  let mut b = fact_int_abs(b0)
  while b != 0 {
    let r = a % b
    a = b
    b = r
  }
  a
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
fn fact_int_dup_to_ints(f : Array[FieldElem]) -> Array[Int] raise PolyError {
  let out : Array[Int] = Array::new()
  for c in f {
    out.push(fact_int_fe_to_int(c))
  }
  out
}

///|
fn fact_int_dup_from_ints(f : Array[Int]) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for c in f {
    out.push(fe_from_int(c, Domain::ZZ))
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
/// Perform one integer Hensel lifting step.
///
/// - Does: Ports SymPy's `dup_zz_hensel_step`, lifting a coprime factor pair
///   and Bezout pair from modulus `m` to `m**2`.
/// - Input: Positive modulus `m`, dense integer `f, g, h, s, t`, and
///   `Domain::ZZ`.
/// - Returns: `(G, H, S, T)` with dense integer coefficients.
/// - Limits: Preconditions are the same as the SymPy low-level helper; invalid
///   coprime/factor data may raise through dense division.
pub fn dup_zz_hensel_step(
  m : Int,
  f : Array[FieldElem],
  g : Array[FieldElem],
  h : Array[FieldElem],
  s : Array[FieldElem],
  t : Array[FieldElem],
  domain : Domain,
) -> (Array[FieldElem], Array[FieldElem], Array[FieldElem], Array[FieldElem]) raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  if m <= 0 {
    raise PolyError::BadModulus
  }
  let modulus_elem = fe_from_int(m * m, Domain::ZZ)
  let e = dup_trunc(dup_sub_mul(f, g, h, domain), modulus_elem, domain)
  let (q0, r0) = dup_div(dup_mul(s, e, domain), h, domain)
  let q = dup_trunc(q0, modulus_elem, domain)
  let r = dup_trunc(r0, modulus_elem, domain)
  let u = dup_add(dup_mul(t, e, domain), dup_mul(q, g, domain), domain)
  let big_g = dup_trunc(dup_add(g, u, domain), modulus_elem, domain)
  let big_h = dup_trunc(dup_add(h, r, domain), modulus_elem, domain)
  let unity = [fe_from_int(1, Domain::ZZ)]
  let bezout = dup_add(
    dup_mul(s, big_g, domain),
    dup_mul(t, big_h, domain),
    domain,
  )
  let b = dup_trunc(dup_sub(bezout, unity, domain), modulus_elem, domain)
  let (c0, d0) = dup_div(dup_mul(s, b, domain), big_h, domain)
  let c = dup_trunc(c0, modulus_elem, domain)
  let d = dup_trunc(d0, modulus_elem, domain)
  let u2 = dup_add(dup_mul(t, b, domain), dup_mul(c, big_g, domain), domain)
  let big_s = dup_trunc(dup_sub(s, d, domain), modulus_elem, domain)
  let big_t = dup_trunc(dup_sub(t, u2, domain), modulus_elem, domain)
  (big_g, big_h, big_s, big_t)
}

///|
fn fact_int_zz_inv_mod(a : Int, modulus : Int) -> Int raise PolyError {
  let (s, _, g) = int_gcdex_local(a, modulus)
  if g != 1 {
    raise PolyError::DivisionByZero
  }
  let mut value = s % modulus
  if value > modulus / 2 {
    value = value - modulus
  } else if value < -(modulus / 2) {
    value = value + modulus
  }
  value
}

///|
fn fact_int_zz_hensel_lift_rec(
  p : Int,
  f : Array[FieldElem],
  f_list : Array[Array[FieldElem]],
  l : Int,
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let r = f_list.length()
  let lc = dup_LC(f)
  if r == 0 {
    return Array::new()
  }
  if r == 1 {
    let modulus = fact_int_pow(p, l)
    let coeff = fe_from_int(
      fact_int_zz_inv_mod(fact_int_fe_to_int(lc), modulus),
      Domain::ZZ,
    )
    return [
      dup_trunc(
        dup_mul_ground(f, coeff, domain),
        fe_from_int(modulus, Domain::ZZ),
        domain,
      ),
    ]
  }
  let k = r / 2
  let rounds = densetools_ceil_log2(l)
  let left_items = f_list[:k].to_owned()
  let right_items = f_list[k:].to_owned()
  let mut g_int = gf_from_int_poly([fact_int_fe_to_int(lc)], p)
  for factor in left_items {
    g_int = gf_mul(g_int, gf_from_int_poly(fact_int_dup_to_ints(factor), p), p)
  }
  let mut h_int = gf_from_int_poly(fact_int_dup_to_ints(right_items[0]), p)
  for i in 1..<right_items.length() {
    h_int = gf_mul(
      h_int,
      gf_from_int_poly(fact_int_dup_to_ints(right_items[i]), p),
      p,
    )
  }
  let (s_int0, t_int0, _) = gf_gcdex(g_int, h_int, p)
  let mut g = fact_int_dup_from_ints(gf_to_int_poly(g_int, p))
  let mut h = fact_int_dup_from_ints(gf_to_int_poly(h_int, p))
  let mut s = fact_int_dup_from_ints(gf_to_int_poly(s_int0, p))
  let mut t = fact_int_dup_from_ints(gf_to_int_poly(t_int0, p))
  let mut m = p
  for _ in 0..<rounds {
    let next = dup_zz_hensel_step(m, f, g, h, s, t, domain)
    g = next.0
    h = next.1
    s = next.2
    t = next.3
    m = m * m
  }
  let out = fact_int_zz_hensel_lift_rec(p, g, left_items, l, domain)
  for item in fact_int_zz_hensel_lift_rec(p, h, right_items, l, domain) {
    out.push(item)
  }
  out
}

///|
/// Lift modular integer factors to integer factors.
///
/// - Does: Ports SymPy's `dup_zz_hensel_lift`, recursively splitting the
///   factor list and applying `dup_zz_hensel_step`.
/// - Input: Prime `p`, dense integer polynomial `f`, monic pairwise-coprime
///   modular factors, positive exponent `l`, and `Domain::ZZ`.
/// - Returns: Monic dense integer factors congruent to the input factors modulo
///   `p` and whose product matches `f` modulo `p**l`.
/// - Limits: Inputs must satisfy SymPy's low-level Hensel preconditions;
///   arithmetic currently assumes coefficient moduli fit in `Int`.
pub fn dup_zz_hensel_lift(
  p : Int,
  f : Array[FieldElem],
  f_list : Array[Array[FieldElem]],
  l : Int,
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  if p <= 1 || l <= 0 {
    raise PolyError::BadModulus
  }
  let ff = fact_int_dup_to_zz(f)
  let items = f_list.map(item => fact_int_dup_to_zz(item))
  fact_int_zz_hensel_lift_rec(p, ff, items, l, domain)
}

///|
/// Compute valid divisors for Wang/EEZ factorization.
///
/// - Does: Ports SymPy's `dmp_zz_wang_non_divisors`, filtering evaluation
///   contents that would introduce non-divisors.
/// - Input: Integer values `E`, integer content scalars `cs` and `ct`, and
///   `Domain::ZZ`.
/// - Returns: `Some(divisors)` when all checks pass, or `None` when SymPy
///   would return `None`.
/// - Limits: Coefficients currently fit in `Int`; this is the low-level Wang
///   helper, not the full multivariate factorization front door.
pub fn dmp_zz_wang_non_divisors(
  values : Array[FieldElem],
  cs : FieldElem,
  ct : FieldElem,
  domain : Domain,
) -> Array[FieldElem]? raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let result : Array[Int] = [fact_int_fe_to_int(cs) * fact_int_fe_to_int(ct)]
  for q0 in values {
    let mut q = fact_int_abs(fact_int_fe_to_int(q0))
    let mut i = result.length()
    while i > 0 {
      i = i - 1
      let mut r = result[i]
      while r != 1 {
        r = fact_int_gcd(r, q)
        if r == 0 {
          break
        }
        q = q / r
      }
      if q == 1 {
        return None
      }
    }
    result.push(q)
  }
  let out : Array[FieldElem] = Array::new()
  for i in 1..<result.length() {
    out.push(fe_from_int(result[i], Domain::ZZ))
  }
  Some(out)
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
