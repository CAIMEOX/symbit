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
fn fact_int_factorial(n : Int) -> Int {
  let mut result = 1
  for i in 2..<=n {
    result = result * i
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
fn fact_int_dmp_to_coeffs_with_zeros(
  f : DensePoly,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  match f {
    DensePoly::Coef(c) => dup_strip([c])
    DensePoly::Poly(items) => {
      if items.is_empty() {
        return Array::new()
      }
      let zero = fe_from_int(0, domain)
      let coeffs : Array[FieldElem] = Array::new()
      for item in items {
        match item {
          DensePoly::Coef(c) => coeffs.push(c)
          DensePoly::Poly(_) =>
            if dmp_zero_p(item, 0) {
              coeffs.push(zero)
            } else {
              raise PolyError::NotUnivariate
            }
        }
      }
      dup_strip(coeffs)
    }
  }
}

///|
fn fact_int_dmp_quo_ground_with_zeros(
  f : DensePoly,
  c : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    return dmp_from_coeffs(
      dup_quo_ground(fact_int_dmp_to_coeffs_with_zeros(f, domain), c, domain),
    )
  }
  dmp_quo_ground(f, c, u, domain)
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
fn fact_int_dup_zz_diophantine_coeff(
  factors : Array[Array[FieldElem]],
  coeffs : Array[FieldElem],
  p : Int,
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let result : Array[Array[FieldElem]] = Array::new()
  for _ in factors {
    result.push(Array::new())
  }
  let n = dup_degree(coeffs)
  let modulus = fe_from_int(p, Domain::ZZ)
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if fe_is_zero(coeff) {
      continue
    }
    let terms = dup_zz_diophantine(factors, n - i, p, domain)
    for j in 0..<result.length() {
      let scaled = dup_mul_ground(terms[j], coeff, domain)
      result.set(
        j,
        dup_trunc(dup_add(result[j], scaled, domain), modulus, domain),
      )
    }
  }
  result
}

///|
/// Solve a univariate Wang/EEZ Diophantine equation.
///
/// - Does: Ports SymPy's `dup_zz_diophantine`, including the recursive
///   multi-factor reduction through the empty-evaluation `dmp` branch.
/// - Input: Integer dense factors `F`, shift `m`, prime modulus `p`, and
///   `Domain::ZZ`.
/// - Returns: Dense integer solution polynomials in the same order as `F`.
/// - Limits: Coefficients and moduli currently fit in `Int`.
pub fn dup_zz_diophantine(
  factors : Array[Array[FieldElem]],
  m : Int,
  p : Int,
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  if p <= 1 || factors.length() < 2 {
    raise PolyError::BadModulus
  }
  let normalized = factors.map(f => fact_int_dup_to_zz(f))
  if normalized.length() == 2 {
    let a = normalized[0]
    let b = normalized[1]
    let f = gf_from_int_poly(fact_int_dup_to_ints(a), p)
    let g = gf_from_int_poly(fact_int_dup_to_ints(b), p)
    let (s0, t0, _) = gf_gcdex(g, f, p)
    let shifted_s = gf_lshift(s0, m)
    let shifted_t = gf_lshift(t0, m)
    let (q, rem_s) = gf_div(shifted_s, f, p)
    let final_t = gf_add_mul(shifted_t, q, g, p)
    [
      fact_int_dup_from_ints(gf_to_int_poly(rem_s, p)),
      fact_int_dup_from_ints(gf_to_int_poly(final_t, p)),
    ]
  } else {
    let products : Array[Array[FieldElem]] = [
      normalized[normalized.length() - 1],
    ]
    let mut idx = normalized.length() - 1
    while idx > 1 {
      idx = idx - 1
      products.insert(0, dup_mul(normalized[idx], products[0], domain))
    }
    let partial_s : Array[Array[FieldElem]] = Array::new()
    let partial_t : Array[Array[FieldElem]] = [[fe_from_int(1, Domain::ZZ)]]
    for i in 0..<products.length() {
      let pair = fact_int_dup_zz_diophantine_coeff(
        [products[i], normalized[i]],
        partial_t[partial_t.length() - 1],
        p,
        domain,
      )
      partial_t.push(pair[0])
      partial_s.push(pair[1])
    }
    let all_s = partial_s.copy()
    all_s.push(partial_t[partial_t.length() - 1])
    let result : Array[Array[FieldElem]] = Array::new()
    for i in 0..<normalized.length() {
      let s_int = gf_from_int_poly(fact_int_dup_to_ints(all_s[i]), p)
      let f_int = gf_from_int_poly(fact_int_dup_to_ints(normalized[i]), p)
      let rem = gf_rem(gf_lshift(s_int, m), f_int, p)
      result.push(fact_int_dup_from_ints(gf_to_int_poly(rem, p)))
    }
    result
  }
}

///|
/// Solve a dense Wang/EEZ Diophantine equation.
///
/// - Does: Ports SymPy's `dmp_zz_diophantine`, including the recursive
///   evaluation-chain branch used by Wang/EEZ lifting.
/// - Input: Dense factors, dense coefficient polynomial `c`, evaluation list
///   `A`, degree bound `d`, prime modulus `p`, level `u`, and `Domain::ZZ`.
/// - Returns: Dense solution polynomials.
/// - Limits: Supports exact integer dense inputs. Invalid factor/evaluation
///   shapes propagate dense arithmetic `PolyError`s.
pub fn dmp_zz_diophantine(
  factors : Array[DensePoly],
  c : DensePoly,
  eval_points : Array[FieldElem],
  d : Int,
  p : Int,
  u : Int,
  domain : Domain,
) -> Array[DensePoly] raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  if eval_points.is_empty() {
    let dup_factors = factors.map(f => {
      fact_int_dmp_to_coeffs_with_zeros(f, domain)
    })
    let solutions = fact_int_dup_zz_diophantine_coeff(
      dup_factors,
      fact_int_dmp_to_coeffs_with_zeros(c, domain),
      p,
      domain,
    )
    return solutions.map(s => dmp_from_coeffs(s))
  }
  let n = eval_points.length()
  let p_elem = fe_from_int(p, domain)
  let e = dmp_expand(factors, u, domain)
  let a = eval_points[n - 1]
  let rest = eval_points[:n - 1].to_owned()
  let quotients : Array[DensePoly] = Array::new()
  let evaluated_factors : Array[DensePoly] = Array::new()
  for factor in factors {
    quotients.push(dmp_quo(e, factor, u, domain))
    evaluated_factors.push(dmp_eval_in(factor, a, n, u, domain))
  }
  let evaluated_c = dmp_eval_in(c, a, n, u, domain)
  let v = u - 1
  let base_solutions = dmp_zz_diophantine(
    evaluated_factors, evaluated_c, rest, d, p, v, domain,
  )
  let solutions : Array[DensePoly] = Array::new()
  for solution in base_solutions {
    solutions.push(dmp_raise(solution, 1, v, domain))
  }
  let mut remainder = c
  for i in 0..<solutions.length() {
    remainder = dmp_sub_mul(remainder, solutions[i], quotients[i], u, domain)
  }
  remainder = dmp_ground_trunc(remainder, p_elem, u, domain)
  let one = fe_from_int(1, domain)
  let m = dmp_nest(dmp_from_coeffs([one, fe_neg(a)]), n, domain)
  let mut multiplier = dmp_one(n, domain)
  for k in 0..<d {
    if dmp_zero_p(remainder, u) {
      break
    }
    multiplier = dmp_mul(multiplier, m, u, domain)
    let mut coeff = dmp_diff_eval_in(remainder, k + 1, a, n, u, domain)
    if !dmp_zero_p(coeff, v) {
      coeff = fact_int_dmp_quo_ground_with_zeros(
        coeff,
        fe_from_int(fact_int_factorial(k + 1), domain),
        v,
        domain,
      )
      let correction_base = dmp_zz_diophantine(
        evaluated_factors, coeff, rest, d, p, v, domain,
      )
      let corrections : Array[DensePoly] = Array::new()
      for correction in correction_base {
        corrections.push(
          dmp_mul(dmp_raise(correction, 1, v, domain), multiplier, u, domain),
        )
      }
      for i in 0..<solutions.length() {
        solutions.set(i, dmp_add(solutions[i], corrections[i], u, domain))
      }
      for i in 0..<corrections.length() {
        remainder = dmp_sub_mul(
          remainder,
          corrections[i],
          quotients[i],
          u,
          domain,
        )
      }
      remainder = dmp_ground_trunc(remainder, p_elem, u, domain)
    }
  }
  solutions.map(solution => dmp_ground_trunc(solution, p_elem, u, domain))
}

///|
fn fact_int_dense_ground_value(
  f : DensePoly,
  domain : Domain,
) -> FieldElem raise PolyError {
  match f {
    DensePoly::Coef(c) => c
    DensePoly::Poly(items) =>
      if items.is_empty() {
        fe_from_int(0, domain)
      } else if items.length() == 1 {
        fact_int_dense_ground_value(items[0], domain)
      } else {
        raise PolyError::NotUnivariate
      }
  }
}

///|
fn fact_int_dense_equal(a : DensePoly, b : DensePoly) -> Bool {
  match (a, b) {
    (DensePoly::Coef(ca), DensePoly::Coef(cb)) => fact_int_fe_equal(ca, cb)
    (DensePoly::Poly(aa), DensePoly::Poly(bb)) => {
      if aa.length() != bb.length() {
        return false
      }
      for i in 0..<aa.length() {
        if !fact_int_dense_equal(aa[i], bb[i]) {
          return false
        }
      }
      true
    }
    _ => fact_int_dense_zero_equiv(a) && fact_int_dense_zero_equiv(b)
  }
}

///|
fn fact_int_dense_zero_equiv(f : DensePoly) -> Bool {
  match f {
    DensePoly::Coef(c) => fe_is_zero(c)
    DensePoly::Poly(items) =>
      items.is_empty() || items.all(fact_int_dense_zero_equiv)
  }
}

///|
fn fact_int_dmp_tail(f : DensePoly) -> DensePoly {
  match f {
    DensePoly::Coef(_) => DensePoly::Poly(Array::new())
    DensePoly::Poly(items) =>
      if items.length() <= 1 {
        DensePoly::Poly(Array::new())
      } else {
        DensePoly::Poly(items[1:].to_owned())
      }
  }
}

///|
fn fact_int_dmp_prepend(
  head : DensePoly,
  tail : DensePoly,
) -> DensePoly raise PolyError {
  match tail {
    DensePoly::Poly(items) => {
      let out : Array[DensePoly] = [head]
      for item in items {
        out.push(item)
      }
      dmp_strip(DensePoly::Poly(out))
    }
    DensePoly::Coef(c) => dmp_strip(DensePoly::Poly([head, DensePoly::Coef(c)]))
  }
}

///|
fn fact_int_exact_div(
  numer : Int,
  denom : Int,
  marker : String,
) -> Int raise PolyError {
  if denom == 0 || numer % denom != 0 {
    raise PolyError::BadGenerator(marker)
  }
  numer / denom
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
/// Test Wang/EEZ evaluation points for suitability.
///
/// - Does: Ports SymPy's `dmp_zz_wang_test_points` helper: evaluate tail
///   variables, require a square-free primitive univariate image, normalize its
///   sign, and check evaluated leading-coefficient factors with
///   `dmp_zz_wang_non_divisors`.
/// - Input: A recursive dense integer polynomial `f`, leading-coefficient
///   factors `T`, integer content `ct`, evaluation points `A`, level `u`, and
///   `Domain::ZZ`.
/// - Returns: `(content, primitive_image, evaluated_factor_values)`.
/// - Limits: Failed suitability checks raise `PolyError::BadGenerator` with an
///   evaluation marker rather than a separate Python exception subclass.
pub fn dmp_zz_wang_test_points(
  f : DensePoly,
  factors : Array[(DensePoly, Int)],
  ct : FieldElem,
  eval_points : Array[FieldElem],
  u : Int,
  domain : Domain,
) -> (FieldElem, Array[FieldElem], Array[FieldElem]) raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let lc_eval = dmp_eval_tail(dmp_LC(f), eval_points, u - 1, domain)
  if dmp_zero_p(lc_eval, 0) {
    raise PolyError::BadGenerator("wang-evaluation")
  }
  let g = dmp_to_coeffs(dmp_eval_tail(f, eval_points, u, domain))
  if !dup_sqf_p(g, domain) {
    raise PolyError::BadGenerator("wang-evaluation")
  }
  let primitive = dup_primitive(g, domain)
  let mut c = primitive.0
  let mut h = primitive.1
  if !h.is_empty() && fe_is_negative(dup_LC(h)) {
    c = fe_neg(c)
    h = dup_neg(h, domain)
  }
  let v = u - 1
  let values : Array[FieldElem] = Array::new()
  for item in factors {
    let evaluated = dmp_eval_tail(item.0, eval_points, v, domain)
    values.push(fact_int_dense_ground_value(evaluated, domain))
  }
  match dmp_zz_wang_non_divisors(values, c, ct, domain) {
    Some(_) => (c, h, values)
    None => raise PolyError::BadGenerator("wang-evaluation")
  }
}

///|
/// Compute corrected leading coefficients for Wang/EEZ lifting.
///
/// - Does: Ports SymPy's `dmp_zz_wang_lead_coeffs`, distributing evaluated
///   leading-coefficient factors across the univariate lifted factors and
///   scaling the factor list when the global content `cs` is not exhausted.
/// - Input: Recursive dense integer polynomial `f`, leading-coefficient
///   factors `T`, content `cs`, evaluated factor values `E`, univariate
///   factors `H`, evaluation points `A`, level `u`, and `Domain::ZZ`.
/// - Returns: `(scaled_f, scaled_univariate_factors, leading_coefficients)`.
/// - Limits: Inputs are expected to come from `dmp_zz_wang_test_points`; unit
///   or zero evaluated factors raise instead of entering SymPy's internal
///   non-terminating precondition violation.
pub fn dmp_zz_wang_lead_coeffs(
  f : DensePoly,
  factors : Array[(DensePoly, Int)],
  cs : FieldElem,
  values : Array[FieldElem],
  univar_factors : Array[Array[FieldElem]],
  eval_points : Array[FieldElem],
  u : Int,
  domain : Domain,
) -> (DensePoly, Array[Array[FieldElem]], Array[DensePoly]) raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  if values.length() != factors.length() {
    raise PolyError::BadGenerator("wang-leading-coefficients")
  }
  let v = u - 1
  let coeffs : Array[DensePoly] = Array::new()
  let seen : Array[Bool] = Array::make(values.length(), false)
  let cs_start = fact_int_fe_to_int(cs)
  for h in univar_factors {
    let mut c = dmp_one(v, domain)
    let mut d = fact_int_fe_to_int(dup_LC(h)) * cs_start
    let mut idx = values.length()
    while idx > 0 {
      idx = idx - 1
      let e = fact_int_fe_to_int(values[idx])
      if fact_int_abs(e) == 1 || e == 0 {
        raise PolyError::BadGenerator("wang-leading-coefficients")
      }
      let mut k = 0
      while d % e == 0 {
        d = d / e
        k = k + 1
      }
      if k != 0 {
        let power = dmp_pow(factors[idx].0, k, v, domain)
        c = dmp_mul(c, power, v, domain)
        seen.set(idx, true)
      }
    }
    coeffs.push(c)
  }
  for flag in seen {
    if !flag {
      raise PolyError::BadGenerator("wang-leading-coefficients")
    }
  }
  let corrected_coeffs : Array[DensePoly] = Array::new()
  let corrected_factors : Array[Array[FieldElem]] = Array::new()
  let mut cs_work = cs_start
  for i in 0..<coeffs.length() {
    let mut c = coeffs[i]
    let mut h = univar_factors[i]
    let d_eval = fact_int_fe_to_int(
      fact_int_dense_ground_value(
        dmp_eval_tail(c, eval_points, v, domain),
        domain,
      ),
    )
    let lc = fact_int_fe_to_int(dup_LC(h))
    let cc = if cs_work == 1 {
      fact_int_exact_div(lc, d_eval, "wang-leading-coefficients")
    } else {
      let g = fact_int_gcd(lc, d_eval)
      let d_reduced = fact_int_exact_div(d_eval, g, "wang-leading-coefficients")
      h = dup_mul_ground(h, fe_from_int(d_reduced, domain), domain)
      cs_work = fact_int_exact_div(
        cs_work, d_reduced, "wang-leading-coefficients",
      )
      fact_int_exact_div(lc, g, "wang-leading-coefficients")
    }
    c = dmp_mul_ground(c, fe_from_int(cc, domain), v, domain)
    corrected_coeffs.push(c)
    corrected_factors.push(h)
  }
  if cs_work == 1 {
    return (f, corrected_factors, corrected_coeffs)
  }
  let scaled_coeffs : Array[DensePoly] = Array::new()
  let scaled_factors : Array[Array[FieldElem]] = Array::new()
  let cs_elem = fe_from_int(cs_work, domain)
  for i in 0..<corrected_coeffs.length() {
    scaled_coeffs.push(dmp_mul_ground(corrected_coeffs[i], cs_elem, v, domain))
    scaled_factors.push(dup_mul_ground(corrected_factors[i], cs_elem, domain))
  }
  let scale = fe_from_int(
    fact_int_pow(cs_work, univar_factors.length() - 1),
    domain,
  )
  (dmp_mul_ground(f, scale, u, domain), scaled_factors, scaled_coeffs)
}

///|
/// Parallel Hensel lifting for Wang/EEZ factorization.
///
/// - Does: Ports SymPy's `dmp_zz_wang_hensel_lifting`, lifting corrected
///   univariate factors through the supplied evaluation point chain.
/// - Input: Scaled recursive dense polynomial `f`, univariate factors `H`,
///   leading coefficient polynomials, evaluation points `A`, prime modulus
///   `p`, level `u`, and `Domain::ZZ`.
/// - Returns: Lifted recursive dense factors whose product is `f`.
/// - Limits: Invalid/extraneous factor configurations raise
///   `PolyError::BadGenerator("wang-hensel")`.
pub fn dmp_zz_wang_hensel_lifting(
  f : DensePoly,
  factors : Array[Array[FieldElem]],
  lead_coeffs : Array[DensePoly],
  eval_points : Array[FieldElem],
  p : Int,
  u : Int,
  domain : Domain,
) -> Array[DensePoly] raise PolyError {
  match domain {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let p_elem = fe_from_int(p, domain)
  let partials : Array[DensePoly] = [f]
  let n = eval_points.length()
  let v = u - 1
  let factor_polys = factors.map(factor => dmp_from_coeffs(factor))
  if lead_coeffs.length() != factor_polys.length() {
    raise PolyError::BadGenerator("wang-hensel")
  }
  if n > 1 {
    let mut idx = 0
    while idx < n - 1 {
      let a = eval_points[n - 1 - idx]
      let s = dmp_eval_in(partials[0], a, n - idx, u - idx, domain)
      partials.insert(0, dmp_ground_trunc(s, p_elem, v - idx, domain))
      idx = idx + 1
    }
  }
  let degrees = dmp_degree_list(f, u)
  let mut d = 0
  for i in 1..<degrees.length() {
    if degrees[i] > d {
      d = degrees[i]
    }
  }
  for idx in 0..<n {
    let j = idx + 2
    let s = partials[idx]
    let a = eval_points[idx]
    let w = j - 1
    let fixed_factors = factor_polys.copy()
    let left_points = eval_points[:j - 2].to_owned()
    let right_points = if j - 1 < eval_points.length() {
      eval_points[j - 1:].to_owned()
    } else {
      []
    }
    for i in 0..<factor_polys.length() {
      let lc = dmp_ground_trunc(
        dmp_eval_tail(lead_coeffs[i], right_points, v, domain),
        p_elem,
        w - 1,
        domain,
      )
      let tail = dmp_raise(fact_int_dmp_tail(factor_polys[i]), 1, w - 1, domain)
      factor_polys.set(i, fact_int_dmp_prepend(lc, tail))
    }
    let m = dmp_nest(
      dmp_from_coeffs([fe_from_int(1, domain), fe_neg(a)]),
      w,
      domain,
    )
    let mut multiplier = dmp_one(w, domain)
    let mut remainder = dmp_sub(
      s,
      dmp_expand(factor_polys, w, domain),
      w,
      domain,
    )
    let dj = dmp_degree_in(s, w, w)
    for k in 0..<dj {
      if dmp_zero_p(remainder, w) {
        break
      }
      multiplier = dmp_mul(multiplier, m, w, domain)
      let mut coeff = dmp_diff_eval_in(remainder, k + 1, a, w, w, domain)
      if !dmp_zero_p(coeff, w - 1) {
        coeff = fact_int_dmp_quo_ground_with_zeros(
          coeff,
          fe_from_int(fact_int_factorial(k + 1), domain),
          w - 1,
          domain,
        )
        let corrections = dmp_zz_diophantine(
          fixed_factors,
          coeff,
          left_points,
          d,
          p,
          w - 1,
          domain,
        )
        for i in 0..<factor_polys.length() {
          let lifted = dmp_raise(corrections[i], 1, w - 1, domain)
          let updated = dmp_add_mul(
            factor_polys[i],
            lifted,
            multiplier,
            w,
            domain,
          )
          factor_polys.set(i, dmp_ground_trunc(updated, p_elem, w, domain))
        }
        remainder = dmp_ground_trunc(
          dmp_sub(s, dmp_expand(factor_polys, w, domain), w, domain),
          p_elem,
          w,
          domain,
        )
      }
    }
  }
  if !fact_int_dense_equal(dmp_expand(factor_polys, u, domain), f) {
    raise PolyError::BadGenerator("wang-hensel")
  }
  factor_polys
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
