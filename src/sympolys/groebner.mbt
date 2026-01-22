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
fn coeff_div(
  num : @symnum.BigRational,
  den : @symnum.BigRational,
  domain : Domain,
) -> @symnum.BigRational raise PolyError {
  let ratio = num.div_r(den) catch { _ => raise PolyError::DivisionByZero }
  if domain is Domain::ZZ && !ratio.is_integral() {
    raise PolyError::DomainNotField
  }
  ratio
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
  let quotients = Array::makei(n, _ => Poly::zero(
    dividend.gens,
    dividend.domain,
  ))
  let mut p = dividend
  let mut remainder = Poly::zero(dividend.gens, dividend.domain)
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
          )
          quotients.set(i, quotients[i].add(term))
          p = p.sub(divisors[i].mul(term))
          reduced = true
          break
        }
      }
    }
    if !reduced {
      let term = poly_from_term(m_p, c_p, dividend.gens, dividend.domain)
      remainder = remainder.add(term)
      p = p.sub(term)
    }
  }
  (quotients, remainder)
}

///|
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
fn spoly(f : Poly, g : Poly) -> Poly raise PolyError {
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
  let t1 = poly_from_term(q1, c2, f.gens, f.domain)
  let t2 = poly_from_term(q2, c1, f.gens, f.domain)
  t1.mul(f).sub(t2.mul(g))
}

///|
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
        let s = spoly(gset[i], gset[j])
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
