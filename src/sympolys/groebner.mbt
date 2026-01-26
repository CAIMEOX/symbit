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
fn coeff_div(num : FieldElem, den : FieldElem, domain : Domain) -> FieldElem raise PolyError {
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

///|
/// Groebner wrapper that accepts expressions + optional domain/modulus/order/gens.
pub fn groebner_expr(
  exprs : Array[@symcore.Expr],
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
  let resolved_domain = resolve_domain(domain, modulus, extension, gf_degree)
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
      Some(m) => Poly::from_expr_defaults(
        e,
        gens=resolved_gens,
        domain=resolved_domain,
        modulus=m,
        order=ord,
      )
      None => Poly::from_expr_defaults(
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
fn resolve_domain(
  domain : Domain?,
  modulus : Int?,
  extension_syms : Array[String]?,
  gf_degree : Int?,
) -> Domain raise PolyError {
  let base = match (domain, modulus, gf_degree) {
    (Some(Domain::GFExt(p, k, mod_poly)), Some(m), Some(k2)) =>
      if p == m && k == k2 {
        Domain::GFExt(p, k, mod_poly)
      } else {
        raise PolyError::BadModulus
      }
    (Some(Domain::GFExt(p, k, mod_poly)), Some(m), None) =>
      if p == m {
        Domain::GFExt(p, k, mod_poly)
      } else {
        raise PolyError::BadModulus
      }
    (Some(Domain::GFExt(p, k, mod_poly)), None, Some(k2)) =>
      if k == k2 {
        Domain::GFExt(p, k, mod_poly)
      } else {
        raise PolyError::BadModulus
      }
    (Some(Domain::GFExt(p, k, mod_poly)), None, None) =>
      Domain::GFExt(p, k, mod_poly)
    (Some(Domain::GF(p)), Some(m), Some(k)) =>
      if p == m {
        Domain::GFExt(p, k, gfext_default_poly(k))
      } else {
        raise PolyError::BadModulus
      }
    (Some(Domain::GF(p)), Some(m), None) =>
      if p == m {
        Domain::GF(p)
      } else {
        raise PolyError::BadModulus
      }
    (Some(Domain::GF(p)), None, Some(k)) => Domain::GFExt(p, k, gfext_default_poly(k))
    (Some(Domain::GF(p)), None, None) => Domain::GF(p)
    (None, Some(m), Some(k)) =>
      if m <= 1 {
        raise PolyError::BadModulus
      } else {
        Domain::GFExt(m, k, gfext_default_poly(k))
      }
    (None, Some(m), None) =>
      if m <= 1 {
        raise PolyError::BadModulus
      } else {
        Domain::GF(m)
      }
    (Some(d), _, Some(_)) => raise PolyError::NotImplemented("gf-degree-non-gf")
    (Some(d), _, None) => d
    (None, None, Some(_)) => raise PolyError::BadModulus
    (None, None, None) => Domain::QQ
  }
  match extension_syms {
    Some(ext) =>
      if ext.is_empty() {
        base
      } else {
        Domain::AlgExt(base, ext, Array::new())
      }
    None => base
  }
}

///|
fn gfext_default_poly(k : Int) -> Array[Int] {
  let coeffs : Array[Int] = Array::make(k + 1, 0)
  coeffs.set(0, 1)
  coeffs.set(k, 1)
  coeffs
}

///|
fn infer_gens_union(exprs : Array[@symcore.Expr]) -> Array[String] {
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
fn collect_symbols_expr(expr : @symcore.Expr, seen : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => seen.set(name, true)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      for child in args {
        collect_symbols_expr(child, seen)
      }
    @symcore.Expr::Pow(base, exp) => {
      collect_symbols_expr(base, seen)
      collect_symbols_expr(exp, seen)
    }
    @symcore.Expr::Function(_, args) =>
      for child in args {
        collect_symbols_expr(child, seen)
      }
    _ => ()
  }
}
