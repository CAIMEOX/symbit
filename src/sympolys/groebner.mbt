///|
fn check_compat(polys : Array[Poly]) -> Unit raise PolyError {
  if polys.is_empty() {
    raise PolyError::NonPolynomial
  }
  let first = polys[0]
  for p in polys {
    if p.domain.not_equal(first.domain) || p.gens.not_equal(first.gens) {
      raise PolyError::DomainMismatch
    }
  }
}

///|
/// Structured Groebner basis result.
///
/// - Does: Stores the basis polynomials together with shared ring metadata.
/// - Input: Produced by `groebner_basis`.
/// - Returns: A typed basis object.
/// - Limits: SymPy's rich mutable `GroebnerBasis` methods are not all modeled;
///   use existing front doors for reduction and zero-dimensional checks.
pub struct GroebnerBasis {
  polys : Array[Poly]
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
/// F5 signature `(monomial, generator-index)`.
///
/// - Does: Identifies the origin and monomial multiplier carried by an F5
///   labeled polynomial.
/// - Input: A `Monomial` and an `Int` index.
/// - Returns: A tuple alias used by the Groebner F5 helper front doors.
/// - Limits: The index is not range-checked by the constructor helper.
pub type Signature = (Monomial, Int)

///|
/// F5 labeled polynomial `(signature, polynomial, insertion-number)`.
///
/// - Does: Stores the metadata used by F5-style Groebner reductions.
/// - Input: A `Signature`, a `Poly`, and an `Int` number.
/// - Returns: A tuple alias used by the Groebner F5 helper front doors.
/// - Limits: The polynomial must be compatible with the operations that
///   consume it; the tuple constructor does not validate that relation.
pub type LabeledPolynomial = (Signature, Poly, Int)

///|
/// F5 critical-pair tuple.
///
/// - Does: Stores `(sign1, term1, f, sign2, term2, g)` so `term1*f -
///   term2*g` can be formed without eagerly multiplying the labeled
///   polynomials.
/// - Input: Produced by `critical_pair`.
/// - Returns: A tuple alias used by F5 Groebner helper front doors.
/// - Limits: Terms and labeled polynomials are assumed to belong to compatible
///   polynomial rings.
pub type CriticalPair = (
  Signature,
  (Monomial, FieldElem),
  LabeledPolynomial,
  Signature,
  (Monomial, FieldElem),
  LabeledPolynomial,
)

///|
fn coeff_div(
  num : FieldElem,
  den : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  let inv = invert_in_domain(den, domain)
  fe_mul(num, inv)
}

///|
fn divmod_multivar(
  dividend : Poly,
  divisors : Array[Poly],
) -> (Array[Poly], Poly) raise PolyError {
  if divisors.is_empty() {
    raise PolyError::NonPolynomial
  }
  let all_polys = divisors.copy()
  all_polys.push(dividend)
  check_compat(all_polys)
  let n = divisors.length()
  let mk_zero = fn() {
    Poly::{
      coeffs: Map::new(),
      gens: dividend.gens,
      domain: dividend.domain,
      order: dividend.order,
    }
  }
  let quotients = Array::makei(n, _ => mk_zero())
  let mut p = dividend
  let mut remainder = mk_zero()
  while !p.is_zero() {
    let (m_p, c_p) = match p.leading_term() {
      Some(v) => v
      None => break
    }
    let mut reduced = false
    for i in 0..<n {
      let (m_d, c_d) = match divisors[i].leading_term() {
        Some(v) => v
        None => continue
      }
      match monomial_div(m_p, m_d) {
        None => continue
        Some(m_q) => {
          let coeff_q = coeff_div(c_p, c_d, dividend.domain)
          let term = poly_from_term(
            m_q,
            coeff_q,
            dividend.gens,
            dividend.domain,
            dividend.order,
          )
          quotients.set(i, quotients[i].add(term))
          p = p.sub(divisors[i].mul(term))
          reduced = true
          break
        }
      }
    }
    if !reduced {
      let term = poly_from_term(
        m_p,
        c_p,
        dividend.gens,
        dividend.domain,
        dividend.order,
      )
      remainder = remainder.add(term)
      p = p.sub(term)
    }
  }
  (quotients, remainder)
}

///|
/// Multivariate division by a divisor list; returns `(quotients, remainder)`.

///|
/// Public API `Poly.divmod_multivar`.
///
/// - Does: Provides the `Poly.divmod_multivar` operation for Groebner-basis computation.
/// - Input: parameters `self : Poly`, `divisors : Array[Poly]`, `) -> (Array[Poly]`,
/// `Poly`, using the package representation expected by the signature.
/// - Returns: a `(Array[Poly], Poly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Poly::divmod_multivar(
  self : Poly,
  divisors : Array[Poly],
) -> (Array[Poly], Poly) raise PolyError {
  divmod_multivar(self, divisors)
}

///|
fn reduce_poly(f : Poly, basis : Array[Poly]) -> Poly raise PolyError {
  let (_, r) = divmod_multivar(f, basis)
  r
}

///|
fn leading_monomial(poly : Poly) -> Monomial raise PolyError {
  match poly.leading_term() {
    Some((m, _)) => m
    None => raise PolyError::DivisionByZero
  }
}

///|
fn spoly_canceling(f : Poly, g : Poly) -> Poly raise PolyError {
  check_compat([f, g])
  let (m1, c1) = match f.leading_term() {
    Some(v) => v
    None => raise PolyError::DivisionByZero
  }
  let (m2, c2) = match g.leading_term() {
    Some(v) => v
    None => raise PolyError::DivisionByZero
  }
  let lcm = monomial_lcm(m1, m2)
  let q1 = match monomial_div(lcm, m1) {
    Some(m) => m
    None => raise PolyError::DivisionByZero
  }
  let q2 = match monomial_div(lcm, m2) {
    Some(m) => m
    None => raise PolyError::DivisionByZero
  }
  let t1 = poly_from_term(q1, c2, f.gens, f.domain, f.order)
  let t2 = poly_from_term(q2, c1, f.gens, f.domain, f.order)
  t1.mul(f).sub(t2.mul(g))
}

///|
/// Compute the S-polynomial of two monic polynomials.
///
/// - Does: Mirrors SymPy `groebnertools.spoly` by forming
///   `lcm(LM(f), LM(g))/LM(f)*f - lcm(LM(f), LM(g))/LM(g)*g`.
/// - Input: Two compatible `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: SymPy's helper assumes monic ring polynomials; this front door
///   keeps the same contract and does not divide by leading coefficients.
pub fn spoly(f : Poly, g : Poly) -> Poly raise PolyError {
  check_compat([f, g])
  let m1 = leading_monomial(f)
  let m2 = leading_monomial(g)
  let lcm = monomial_lcm(m1, m2)
  let q1 = match monomial_div(lcm, m1) {
    Some(m) => m
    None => raise PolyError::DivisionByZero
  }
  let q2 = match monomial_div(lcm, m2) {
    Some(m) => m
    None => raise PolyError::DivisionByZero
  }
  let one = fe_from_int(1, f.domain)
  let t1 = poly_from_term(q1, one, f.gens, f.domain, f.order)
  let t2 = poly_from_term(q2, one, f.gens, f.domain, f.order)
  t1.mul(f).sub(t2.mul(g))
}

///|
/// Compute the least common multiple through the Groebner-tools front door.
///
/// - Does: Returns the polynomial lcm through the Groebner-tools helper.
/// - Input: Two compatible `Poly` values.
/// - Returns: A normalized `Poly`.
/// - Limits: Uses the package's current `Poly` lcm path, so it inherits the
///   same univariate-centered exact-division limits.
pub fn groebner_lcm(f : Poly, g : Poly) -> Poly raise PolyError {
  check_compat([f, g])
  lcm(f, g)
}

///|
/// Compute the greatest common divisor through the Groebner-tools front door.
///
/// - Does: Returns the polynomial gcd through the Groebner-tools helper.
/// - Input: Two compatible `Poly` values.
/// - Returns: A normalized `Poly`.
/// - Limits: Uses the package's current `Poly` gcd path, so it inherits the
///   same domain and multivariate limits as `gcd`.
pub fn groebner_gcd(f : Poly, g : Poly) -> Poly raise PolyError {
  check_compat([f, g])
  gcd(f, g)
}

///|
/// Construct an F5 signature.
///
/// - Does: Mirrors the Groebner helper `sig` by pairing a monomial with a
///   generator index.
/// - Input: A `Monomial` and an `Int` index.
/// - Returns: A `Signature`.
/// - Limits: This is a structural constructor and performs no index
///   validation.
pub fn sig(monomial : Monomial, index : Int) -> Signature {
  (monomial, index)
}

///|
/// Construct an F5 labeled polynomial.
///
/// - Does: Mirrors the Groebner helper `lbp` by pairing a signature,
///   polynomial, and insertion number.
/// - Input: `Signature`, `Poly`, and `Int`.
/// - Returns: A `LabeledPolynomial`.
/// - Limits: This is a structural constructor; compatibility is checked by
///   consumers when needed.
pub fn lbp(
  signature : Signature,
  polynomial : Poly,
  number : Int,
) -> LabeledPolynomial {
  (signature, polynomial, number)
}

///|
/// Compare two F5 signatures.
///
/// - Does: Extends the selected monomial order to module signatures: higher
///   index sorts first, then lower monomial order sorts first for equal index.
/// - Input: Two `Signature` values and one `TermOrder`.
/// - Returns: `-1` when `u < v` in the F5 ordering, otherwise `1`.
/// - Limits: Like the source helper, equal signatures also return `1` rather
///   than a distinct equality result.
pub fn sig_cmp(u : Signature, v : Signature, order : TermOrder) -> Int {
  if u.1 > v.1 {
    return -1
  }
  if u.1 == v.1 && compare_monomial_order(u.0, v.0, order) < 0 {
    return -1
  }
  1
}

///|
/// Build a sorting key for an F5 signature.
///
/// - Does: Encodes the same order as `sig_cmp`.
/// - Input: One `Signature` and one `TermOrder`.
/// - Returns: `(-index, monomial)` as a tuple key.
/// - Limits: The monomial component still needs the matching term-order
///   comparator when used outside simple display tests.
pub fn sig_key(s : Signature, _order : TermOrder) -> (Int, Monomial) {
  (-s.1, s.0)
}

///|
/// Multiply an F5 signature by a monomial.
///
/// - Does: Adds the multiplier exponents to the signature monomial and keeps
///   the original index.
/// - Input: A `Signature` and a `Monomial`.
/// - Returns: A `Signature`.
/// - Limits: Raises `PolyError::DomainMismatch` if monomial arities differ.
pub fn sig_mult(s : Signature, m : Monomial) -> Signature raise PolyError {
  sig(monomial_mul(s.0, m), s.1)
}

///|
fn lbp_sign(f : LabeledPolynomial) -> Signature {
  f.0
}

///|
fn lbp_polyn(f : LabeledPolynomial) -> Poly {
  f.1
}

///|
fn lbp_num(f : LabeledPolynomial) -> Int {
  f.2
}

///|
/// Subtract one F5 labeled polynomial from another.
///
/// - Does: Subtracts polynomial parts and keeps the signature/number of the
///   larger input under `lbp_cmp`.
/// - Input: Two compatible `LabeledPolynomial` values.
/// - Returns: A `LabeledPolynomial`.
/// - Limits: Uses the first polynomial's order for signature comparison and
///   raises from polynomial subtraction on incompatible rings.
pub fn lbp_sub(
  f : LabeledPolynomial,
  g : LabeledPolynomial,
) -> LabeledPolynomial raise PolyError {
  let max_poly = if sig_cmp(lbp_sign(f), lbp_sign(g), lbp_polyn(f).order) < 0 {
    g
  } else {
    f
  }
  lbp(lbp_sign(max_poly), lbp_polyn(f).sub(lbp_polyn(g)), lbp_num(max_poly))
}

///|
/// Multiply an F5 labeled polynomial by a term.
///
/// - Does: Multiplies both the signature and polynomial by the term monomial,
///   preserving the insertion number.
/// - Input: A `LabeledPolynomial` and a term `(Monomial, FieldElem)`.
/// - Returns: A `LabeledPolynomial`.
/// - Limits: Raises if the monomial arity or coefficient domain is
///   incompatible with the polynomial.
pub fn lbp_mul_term(
  f : LabeledPolynomial,
  cx : (Monomial, FieldElem),
) -> LabeledPolynomial raise PolyError {
  let p = lbp_polyn(f)
  let term = poly_from_term(cx.0, cx.1, p.gens, p.domain, p.order)
  lbp(sig_mult(lbp_sign(f), cx.0), p.mul(term), lbp_num(f))
}

///|
/// Compare two F5 labeled polynomials.
///
/// - Does: Orders first by signature and then, for equal signatures, by
///   descending insertion number.
/// - Input: Two `LabeledPolynomial` values.
/// - Returns: `-1` when `f < g` in the F5 ordering, otherwise `1`.
/// - Limits: Like the source helper, equality is folded into the positive
///   branch rather than returned as `0`.
pub fn lbp_cmp(f : LabeledPolynomial, g : LabeledPolynomial) -> Int {
  if sig_cmp(lbp_sign(f), lbp_sign(g), lbp_polyn(f).order) == -1 {
    return -1
  }
  if lbp_sign(f) == lbp_sign(g) && lbp_num(f) > lbp_num(g) {
    return -1
  }
  1
}

///|
/// Build a sorting key for an F5 labeled polynomial.
///
/// - Does: Encodes the signature key and descending insertion number.
/// - Input: One `LabeledPolynomial`.
/// - Returns: A tuple key `((index-key, monomial), number-key)`.
/// - Limits: The monomial component still needs the polynomial term order for
///   fully ordered sorting outside direct compatibility checks.
pub fn lbp_key(f : LabeledPolynomial) -> ((Int, Monomial), Int) {
  (sig_key(lbp_sign(f), lbp_polyn(f).order), -lbp_num(f))
}

///|
fn zero_like_poly(p : Poly) -> Poly {
  Poly::{ coeffs: Map([]), gens: p.gens, domain: p.domain, order: p.order }
}

///|
fn leading_term_or_raise(p : Poly) -> (Monomial, FieldElem) raise PolyError {
  match p.leading_term() {
    Some(term) => term
    None => raise PolyError::DivisionByZero
  }
}

///|
fn leading_term_poly(p : Poly) -> Poly raise PolyError {
  let (m, c) = leading_term_or_raise(p)
  poly_from_term(m, c, p.gens, p.domain, p.order)
}

///|
fn term_div_or_raise(
  numer : (Monomial, FieldElem),
  denom : (Monomial, FieldElem),
  domain : Domain,
) -> (Monomial, FieldElem) raise PolyError {
  match term_div(numer, denom, domain) {
    Some(term) => term
    None => raise PolyError::ExactQuotientFailed
  }
}

///|
/// Compute the F5 critical pair for two labeled polynomials.
///
/// - Does: Forms the two multiplier terms needed for the S-polynomial and
///   returns them in the order used by `s_poly`.
/// - Input: Two compatible `LabeledPolynomial` values.
/// - Returns: A `CriticalPair`.
/// - Limits: Raises on zero polynomial parts or non-exact leading-term
///   division.
pub fn critical_pair(
  f : LabeledPolynomial,
  g : LabeledPolynomial,
) -> CriticalPair raise PolyError {
  let fp = lbp_polyn(f)
  let gp = lbp_polyn(g)
  check_compat([fp, gp])
  let ltf = leading_term_or_raise(fp)
  let ltg = leading_term_or_raise(gp)
  let lt = (monomial_lcm(ltf.0, ltg.0), fe_from_int(1, fp.domain))
  let um = term_div_or_raise(lt, ltf, fp.domain)
  let vm = term_div_or_raise(lt, ltg, fp.domain)
  let fr = lbp_mul_term(lbp(lbp_sign(f), leading_term_poly(fp), lbp_num(f)), um)
  let gr = lbp_mul_term(lbp(lbp_sign(g), leading_term_poly(gp), lbp_num(g)), vm)
  if lbp_cmp(fr, gr) == -1 {
    (lbp_sign(gr), vm, g, lbp_sign(fr), um, f)
  } else {
    (lbp_sign(fr), um, f, lbp_sign(gr), vm, g)
  }
}

///|
/// Compare two F5 critical pairs.
///
/// - Does: Orders critical pairs by the leading labeled multiple, matching the
///   F5 helper comparator.
/// - Input: Two `CriticalPair` values.
/// - Returns: `-1` when `c < d`, otherwise `1`.
/// - Limits: The equality branch is unreachable with the current `lbp_cmp`
///   semantics, matching the source helper's effective behavior.
pub fn cp_cmp(c : CriticalPair, d : CriticalPair) -> Int {
  let zero = zero_like_poly(lbp_polyn(c.2))
  let c0 = lbp(c.0, zero, lbp_num(c.2))
  let d0 = lbp(d.0, zero, lbp_num(d.2))
  let r = lbp_cmp(c0, d0)
  if r == -1 {
    return -1
  }
  if r == 0 {
    let c1 = lbp(c.3, zero, lbp_num(c.5))
    let d1 = lbp(d.3, zero, lbp_num(d.5))
    if lbp_cmp(c1, d1) == -1 {
      return -1
    }
  }
  1
}

///|
/// Build a sorting key for an F5 critical pair.
///
/// - Does: Encodes the two labeled-polynomial keys used by `cp_cmp`.
/// - Input: One `CriticalPair`.
/// - Returns: A nested tuple key for the leading and trailing pair sides.
/// - Limits: As with `lbp_key`, monomial components still need the active term
///   order for total sorting outside compatibility checks.
pub fn cp_key(
  c : CriticalPair,
) -> (((Int, Monomial), Int), ((Int, Monomial), Int)) {
  let zero = zero_like_poly(lbp_polyn(c.2))
  (lbp_key(lbp(c.0, zero, lbp_num(c.2))), lbp_key(lbp(c.3, zero, lbp_num(c.5))))
}

///|
/// Compute the labeled S-polynomial of a critical pair.
///
/// - Does: Forms `term1*f - term2*g` from the stored critical-pair tuple.
/// - Input: One `CriticalPair`.
/// - Returns: A `LabeledPolynomial`.
/// - Limits: Raises from term multiplication or polynomial subtraction when
///   the stored pair is incompatible.
pub fn s_poly(cp : CriticalPair) -> LabeledPolynomial raise PolyError {
  lbp_sub(lbp_mul_term(cp.2, cp.1), lbp_mul_term(cp.5, cp.4))
}

///|
/// Test F5 rewritability or comparability against a labeled basis.
///
/// - Does: Returns true when a signature/number is redundant by the F5
///   comparable or rewritable criteria.
/// - Input: A `Signature`, insertion number, and labeled-polynomial basis.
/// - Returns: `Bool`.
/// - Limits: Raises if a basis polynomial is zero where a leading monomial is
///   required.
pub fn is_rewritable_or_comparable(
  sign : Signature,
  num : Int,
  basis : Array[LabeledPolynomial],
) -> Bool raise PolyError {
  for h in basis {
    if sign.1 < lbp_sign(h).1 &&
      monomial_divides(leading_monomial(lbp_polyn(h)), sign.0) {
      return true
    }
    if sign.1 == lbp_sign(h).1 &&
      num < lbp_num(h) &&
      monomial_divides(lbp_sign(h).0, sign.0) {
      return true
    }
  }
  false
}

///|
/// F5-reduce one labeled polynomial by a labeled basis.
///
/// - Does: Repeatedly subtracts admissible labeled multiples whose leading
///   term divides the current leading term and whose multiplied signature is
///   smaller.
/// - Input: One `LabeledPolynomial` and an array of labeled basis elements.
/// - Returns: The F5-reduced `LabeledPolynomial`.
/// - Limits: Raises on incompatible rings, zero divisors, or non-exact
///   leading-term division.
pub fn f5_reduce(
  f : LabeledPolynomial,
  basis : Array[LabeledPolynomial],
) -> LabeledPolynomial raise PolyError {
  let mut current = f
  let order = lbp_polyn(current).order
  let domain = lbp_polyn(current).domain
  if lbp_polyn(current).is_zero() {
    return current
  }
  while true {
    let mut changed = false
    for h in basis {
      if lbp_polyn(h).is_zero() {
        continue
      }
      if monomial_divides(
          leading_monomial(lbp_polyn(h)),
          leading_monomial(lbp_polyn(current)),
        ) {
        let t = term_div_or_raise(
          leading_term_or_raise(lbp_polyn(current)),
          leading_term_or_raise(lbp_polyn(h)),
          domain,
        )
        if sig_cmp(sig_mult(lbp_sign(h), t.0), lbp_sign(current), order) < 0 {
          current = lbp_sub(current, lbp_mul_term(h, t))
          changed = true
          break
        }
      }
    }
    if !changed || lbp_polyn(current).is_zero() {
      return current
    }
  }
  current
}

///|
fn leading_monomial_divides(a : Poly, b : Poly) -> Bool raise PolyError {
  monomial_divides(leading_monomial(a), leading_monomial(b))
}

///|
fn groebner_reduction(polys : Array[Poly]) -> Array[Poly] raise PolyError {
  let out : Array[Poly] = []
  for i in 0..<polys.length() {
    let others : Array[Poly] = []
    for j in 0..<polys.length() {
      if i != j {
        others.push(polys[j])
      }
    }
    let h = if others.is_empty() {
      polys[i]
    } else {
      reduce_poly(polys[i], others)
    }
    if !h.is_zero() {
      out.push(make_monic(h))
    }
  }
  out
}

///|
/// Compute a reduced Groebner basis from a Groebner basis.
///
/// - Does: Mirrors SymPy `red_groebner` by discarding generators whose leading
///   monomial is divisible by another generator, then reducing each survivor by
///   the others and making it monic.
/// - Input: A compatible Groebner basis.
/// - Returns: A reduced basis as `Array[Poly]`.
/// - Limits: Requires exact coefficient division in the stored domain.
pub fn red_groebner(gbasis : Array[Poly]) -> Array[Poly] raise PolyError {
  check_compat(gbasis)
  let f = gbasis.copy()
  let h : Array[Poly] = []
  while !f.is_empty() {
    let f0 = match f.pop() {
      Some(v) => v
      None => break
    }
    let mut divisible = false
    for p in f {
      if leading_monomial_divides(p, f0) {
        divisible = true
        break
      }
    }
    if !divisible {
      for p in h {
        if leading_monomial_divides(p, f0) {
          divisible = true
          break
        }
      }
    }
    if !divisible {
      h.push(f0)
    }
  }
  groebner_reduction(h)
}

///|
/// Check whether a polynomial list is a Groebner basis.
///
/// - Does: Mirrors SymPy `is_groebner` by reducing every pair S-polynomial by
///   the candidate basis and checking that all remainders vanish.
/// - Input: A compatible polynomial list.
/// - Returns: `Bool`.
/// - Limits: Uses this package's multivariate division order.
pub fn is_groebner(gbasis : Array[Poly]) -> Bool raise PolyError {
  check_compat(gbasis)
  for i in 0..<gbasis.length() {
    for j in (i + 1)..<gbasis.length() {
      if !reduce_poly(spoly(gbasis[i], gbasis[j]), gbasis).is_zero() {
        return false
      }
    }
  }
  true
}

///|
/// Check whether a Groebner basis is minimal.
///
/// - Does: Mirrors SymPy `is_minimal`: all leading coefficients must be one,
///   and no leading monomial may divide another leading monomial.
/// - Input: A compatible polynomial list.
/// - Returns: `Bool`.
/// - Limits: Zero polynomials are rejected as non-minimal.
pub fn is_minimal(gbasis : Array[Poly]) -> Bool raise PolyError {
  check_compat(gbasis)
  for i in 0..<gbasis.length() {
    if gbasis[i].is_zero() || !fe_is_one(gbasis[i].lc()) {
      return false
    }
    for j in 0..<gbasis.length() {
      if i != j && leading_monomial_divides(gbasis[j], gbasis[i]) {
        return false
      }
    }
  }
  true
}

///|
/// Check whether a Groebner basis is reduced.
///
/// - Does: Mirrors SymPy `is_reduced`: each polynomial must be monic and no
///   term in one polynomial may be divisible by another leading monomial.
/// - Input: A compatible polynomial list.
/// - Returns: `Bool`.
/// - Limits: Zero polynomials are rejected as non-reduced.
pub fn is_reduced(gbasis : Array[Poly]) -> Bool raise PolyError {
  check_compat(gbasis)
  for i in 0..<gbasis.length() {
    if gbasis[i].is_zero() || !fe_is_one(gbasis[i].lc()) {
      return false
    }
    for term_monomial, _ in gbasis[i].coeffs {
      for j in 0..<gbasis.length() {
        if i != j &&
          monomial_divides(leading_monomial(gbasis[j]), term_monomial) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Compute a reduced Groebner basis for `polys` in the chosen order.

///|
/// Public API `Poly.groebner`.
///
/// - Does: Provides the `Poly.groebner` operation for Groebner-basis computation.
/// - Input: parameters `polys : Array[Poly]`, `order : TermOrder`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[Poly]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn Poly::groebner(
  polys : Array[Poly],
  order? : TermOrder,
) -> Array[Poly] raise PolyError {
  check_compat(polys)
  let ord = match order {
    Some(o) => o
    None => polys[0].order
  }
  let gset : Array[Poly] = polys.map(p => p.with_order(ord))
  let mut changed = true
  while changed {
    changed = false
    for i in 0..<gset.length() {
      for j in (i + 1)..<gset.length() {
        let s = spoly_canceling(gset[i], gset[j])
        let r = reduce_poly(s, gset)
        if !r.is_zero() {
          gset.push(make_monic(r))
          changed = true
        }
      }
    }
  }
  // Interreduce basis
  let reduced : Array[Poly] = Array::new()
  for i in 0..<gset.length() {
    let others = Array::new()
    for j in 0..<gset.length() {
      if i != j {
        others.push(gset[j])
      }
    }
    let r = if others.is_empty() {
      gset[i]
    } else {
      reduce_poly(gset[i], others)
    }
    if !r.is_zero() {
      reduced.push(make_monic(r))
    }
  }
  reduced.sort_by((a, b) => {
    let lt_a = a.leading_term()
    let lt_b = b.leading_term()
    match (lt_a, lt_b) {
      (Some((ma, _)), Some((mb, _))) => compare_monomial_order(mb, ma, ord)
      (Some(_), None) => 1
      (None, Some(_)) => -1
      _ => 0
    }
  })
  reduced
}

///|
/// Compute a structured Groebner basis result.
///
/// - Does: Runs the existing Groebner basis algorithm and packages the basis
///   with ring metadata.
/// - Input: A non-empty compatible polynomial list and optional monomial order.
/// - Returns: `GroebnerBasis`.
/// - Limits: Raises on empty input or incompatible polynomial rings.
pub fn groebner_basis(
  polys : Array[Poly],
  order? : TermOrder,
) -> GroebnerBasis raise PolyError {
  if polys.is_empty() {
    raise PolyError::NonPolynomial
  }
  let ord = match order {
    Some(o) => o
    None => polys[0].order
  }
  let basis = Poly::groebner(polys, order=ord)
  GroebnerBasis::{
    polys: basis,
    gens: polys[0].gens,
    domain: polys[0].domain,
    order: ord,
  }
}

///|
/// Convert a zero-dimensional Groebner basis to another monomial order.
///
/// - Does: Mirrors the public contract of SymPy `matrix_fglm`: returns a
///   Groebner basis for the same ideal in the requested target order.
/// - Input: A compatible Groebner basis and an optional target `TermOrder`.
/// - Returns: An array of `Poly` values in the target order.
/// - Limits: This front door currently reuses the package Groebner basis
///   computation instead of SymPy's matrix FGLM kernel, so it has the same
///   correctness envelope and performance profile as `Poly::groebner`.
pub fn matrix_fglm(
  basis : Array[Poly],
  order? : TermOrder = TermOrder::Lex,
) -> Array[Poly] raise PolyError {
  if basis.is_empty() {
    raise PolyError::NonPolynomial
  }
  Poly::groebner(basis, order~)
}

///|
/// Groebner wrapper that accepts expressions + optional domain/modulus/order/gens.

///|
/// Public API `groebner_expr`.
///
/// - Does: Provides the `groebner_expr` operation for Groebner-basis computation.
/// - Input: parameters `exprs : Array[Expr]`, `gens : Array[String]`, `domain :
/// Domain`, `modulus : Int`, `extension : Array[String]` and 2 more parameter(s), using
/// the package representation expected by the signature.
/// - Returns: a `Array[Poly]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn groebner_expr(
  exprs : Array[Expr],
  gens? : Array[String],
  domain? : Domain,
  modulus? : Int,
  extension? : Array[String],
  gf_degree? : Int,
  order? : TermOrder,
) -> Array[Poly] raise PolyError {
  if exprs.is_empty() {
    raise PolyError::NonPolynomial
  }
  let resolved_gens = match gens {
    Some(g) => g
    None => infer_gens_union(exprs)
  }
  let resolved_domain = resolve_domain(
    domain~,
    modulus~,
    extension~,
    gf_degree~,
    expr=None,
    gaussian=None,
  )
  let ord = match order {
    Some(o) => o
    None => TermOrder::Lex
  }
  let mod_opt = match resolved_domain {
    Domain::GF(p) => Some(p)
    _ => None
  }
  let polys : Array[Poly] = Array::new()
  for e in exprs {
    let poly = match mod_opt {
      Some(m) =>
        Poly::from_expr_defaults(
          e,
          gens=resolved_gens,
          domain=resolved_domain,
          modulus=m,
          order=ord,
        )
      None =>
        Poly::from_expr_defaults(
          e,
          gens=resolved_gens,
          domain=resolved_domain,
          order=ord,
        )
    }
    polys.push(poly)
  }
  Poly::groebner(polys, order=ord)
}

///|
fn infer_gens_union(exprs : Array[Expr]) -> Array[String] {
  let seen : Map[String, Bool] = Map::new()
  for e in exprs {
    collect_symbols_expr(e, seen)
  }
  let names : Array[String] = Array::new()
  for n, _ in seen {
    names.push(n)
  }
  names.sort()
  names
}

///|
fn collect_symbols_expr(expr : Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    Expr::Symbol(name) => seen.set(name, true)
    Expr::Add(args) | Expr::Mul(args) =>
      for child in args {
        collect_symbols_expr(child, seen)
      }
    Expr::Pow(base, exp) => {
      collect_symbols_expr(base, seen)
      collect_symbols_expr(exp, seen)
    }
    _ =>
      for child in @symcore.args(expr) {
        collect_symbols_expr(child, seen)
      }
  }
}
