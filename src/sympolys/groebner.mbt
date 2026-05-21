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
