///|
/// Greatest common divisor over a list of univariate polys.
pub fn gcd_list(polys : Array[Poly]) -> Poly raise PolyError {
  if polys.is_empty() {
    raise PolyError::NonPolynomial
  }
  let mut g = polys[0]
  for i in 1..<polys.length() {
    g = g.gcd_univar(polys[i])
  }
  g
}

///|
/// Least common multiple over a list of univariate polys.
pub fn lcm_list(polys : Array[Poly]) -> Poly raise PolyError {
  if polys.is_empty() {
    raise PolyError::NonPolynomial
  }
  let mut l = polys[0]
  for i in 1..<polys.length() {
    let g = l.gcd_univar(polys[i])
    let prod = l.mul(polys[i])
    l = prod.div_exact_univar(g)
  }
  match l.leading_term() {
    None => l
    Some((_, lc)) => {
      let inv_res : Result[FieldElem, Error] = try? fe_inv(lc)
      match inv_res {
        Ok(inv) => {
          let scaled : Result[Poly, Error] = try? l.scale_coeff(inv)
          match scaled {
            Ok(poly) => poly
            Err(_) => l
          }
        }
        Err(_) => l
      }
    }
  }
}

///|
/// Monomial+content gcd of all terms: coefficient content times
/// min exponent vector.
pub fn terms_gcd(poly : Poly) -> Poly raise PolyError {
  if poly.is_zero() {
    return poly
  }
  let mut min_exps : Option[Array[Int]] = None
  for m, _ in poly.coeffs {
    let exps = m.exps
    min_exps = match min_exps {
      None => Some(exps.copy())
      Some(curr) => {
        let next = curr.copy()
        for i in 0..<next.length() {
          if exps[i] < next[i] {
            next.set(i, exps[i])
          }
        }
        Some(next)
      }
    }
  }
  let content = poly.content()
  let mono = monomial_one(poly.gens.length())
  match min_exps {
    Some(exps) =>
      for i in 0..<exps.length() {
        mono.exps.set(i, exps[i])
      }
    None => ()
  }
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  let coeff_fe = ensure_coeff_domain(content, poly.domain)
  add_term(coeffs, mono, coeff_fe, poly.domain)
  Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
/// Cancel common univariate factors between numerator and denominator.
pub fn cancel(
  num : Poly,
  den : Poly,
) -> (Poly, Poly) raise PolyError {
  if num.gens.length() != 1 || den.gens.length() != 1 {
    let g = gcd_multivar_simple(num, den)
    if g.is_zero() {
      return (num, den)
    }
    let (q_num, r_num) = num.divmod_multivar([g])
    let (q_den, r_den) = den.divmod_multivar([g])
    if !r_num.is_zero() || !r_den.is_zero() {
      return (num, den)
    }
    return (q_num[0], q_den[0])
  }
  let g = num.gcd_univar(den)
  let num_s = num.div_exact_univar(g)
  let den_s = den.div_exact_univar(g)
  (num_s, den_s)
}

///|
/// Minimal multivariate gcd: detect exact divisibility and fall back to 1.
fn gcd_multivar_simple(a : Poly, b : Poly) -> Poly raise PolyError {
  if a.domain.not_equal(b.domain) || a.gens.not_equal(b.gens) {
    raise PolyError::DomainMismatch
  }
  if a.is_zero() {
    return b
  }
  if b.is_zero() {
    return a
  }
  let (_, r1) = a.divmod_multivar([b])
  if r1.is_zero() {
    return make_monic(b)
  }
  let (_, r2) = b.divmod_multivar([a])
  if r2.is_zero() {
    return make_monic(a)
  }
  Poly::one(a.gens, a.domain)
}

///|
/// Reduce a polynomial by a list via multivariate division.
pub fn reduced(
  poly : Poly,
  divisors : Array[Poly],
) -> (Array[Poly], Poly) raise PolyError {
  match poly.domain {
    Domain::ZZ => {
      let poly_q = lift_to_qq(poly)
      let divs_q = divisors.map(d => lift_to_qq(d))
      poly_q.divmod_multivar(divs_q)
    }
    _ => poly.divmod_multivar(divisors)
  }
}

///|
/// Univariate composition f(g(x)).
pub fn compose(f : Poly, g : Poly) -> Poly raise PolyError {
  if f.gens.not_equal(g.gens) || f.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let mut result = Poly::zero(f.gens, f.domain)
  let deg_f = f.degree(0)
  let pow_cache : Array[Poly] = Array::new()
  pow_cache.push(Poly::one(g.gens, g.domain))
  for k in 1..=deg_f {
    let next = pow_cache[k - 1].mul(g)
    pow_cache.push(next)
  }
  for m, c in f.coeffs {
    let k = m.exps[0]
    let term_poly = pow_cache[k].scale_coeff(c)
    result = result.add(term_poly)
  }
  result
}

///|
/// Simple functional decomposition: if all exponents share a gcd>1,
/// return h(x) and g(x)=x^k such that f(x)=h(g(x)); otherwise [f].
pub fn decompose(f : Poly) -> Array[Poly] raise PolyError {
  if f.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let mut exp_gcd = 0
  for m, _ in f.coeffs {
    let e = m.exps[0]
    if e == 0 {
      continue
    }
    exp_gcd = if exp_gcd == 0 { e } else { gcd_int(exp_gcd, e) }
  }
  if exp_gcd <= 1 {
    return [f]
  }
  let p = smallest_prime_factor(exp_gcd)
  if p <= 1 || f.degree(0) / p <= 1 {
    return [f]
  }
  let g = Poly::zero(f.gens, f.domain)
  let mono_g = monomial_one(1)
  mono_g.exps.set(0, p)
  add_term(g.coeffs, mono_g, fe_from_int(1, f.domain), f.domain)
  let coeffs_h : Map[Monomial, FieldElem] = Map::new()
  for m, c in f.coeffs {
    let e = m.exps[0] / p
    let mono_h = monomial_one(1)
    mono_h.exps.set(0, e)
    add_term(coeffs_h, mono_h, c, f.domain)
  }
  let h = Poly::{ coeffs: coeffs_h, gens: f.gens, domain: f.domain, order: f.order }
  let parts = decompose(h)
  parts.push(g)
  parts
}

///|
fn smallest_prime_factor(n : Int) -> Int {
  if n <= 1 {
    return 1
  }
  let mut d = 2
  while d * d <= n {
    if n % d == 0 {
      return d
    }
    d += 1
  }
  n
}

///|
fn gcd_int(a : Int, b : Int) -> Int {
  let mut x = if a < 0 { -a } else { a }
  let mut y = if b < 0 { -b } else { b }
  while y != 0 {
    let t = x % y
    x = y
    y = t
  }
  x
}

///|
fn deriv_univar_polytools(poly : Poly) -> Poly raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in poly.coeffs {
    let exp = m.exps[0]
    if exp == 0 {
      continue
    }
    let mono = monomial_one(1)
    mono.exps.set(0, exp - 1)
    let scale = fe_from_int(exp, poly.domain)
    let new_coeff = fe_mul(c, scale)
    add_term(coeffs, mono, new_coeff, poly.domain)
  }
  Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
/// Sturm sequence for real-root counting (univariate).
pub fn sturm_sequence(poly : Poly) -> Array[Poly] raise PolyError {
  let seq : Array[Poly] = Array::new()
  let use_rat = poly.domain is Domain::ZZ
  let p0 = if use_rat { lift_to_qq(poly) } else { poly }
  let p1 = if use_rat {
    lift_to_qq(deriv_univar_polytools(poly))
  } else {
    deriv_univar_polytools(poly)
  }
  seq.push(p0)
  seq.push(p1)
  let mut a = p0
  let mut b = p1
  while !b.is_zero() {
    let (_, r) = if use_rat {
      divmod_univar_rat(a, b)
    } else {
      a.divmod_univar(b)
    }
    if r.is_zero() {
      break
    }
    let neg_r = r.scale_coeff(fe_from_int(-1, r.domain))
    seq.push(neg_r)
    a = b
    b = neg_r
  }
  seq
}

///|
pub fn discriminant(poly : Poly) -> FieldElem raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let n = poly.degree(0)
  if n <= 1 {
    return fe_from_int(0, poly.domain)
  }
  let deriv = deriv_univar_polytools(poly)
  let res = poly.resultant(deriv, 0)
  let lc = match poly.leading_term() {
    None => fe_from_int(0, poly.domain)
    Some((_, c)) => c
  }
  let sign = if (n * (n - 1) / 2) % 2 == 0 { 1 } else { -1 }
  let res_fe = ensure_coeff_domain(res, poly.domain)
  let inv_lc = fe_inv(lc)
  fe_mul(fe_from_int(sign, poly.domain), fe_mul(res_fe, inv_lc))
}

///|
/// Subresultant pseudo-remainder sequence (returns all remainders).
pub fn subresultants(poly : Poly, other : Poly) -> Array[Poly] raise PolyError {
  check_univar_compat(poly, other)
  let seq : Array[Poly] = Array::new()
  seq.push(poly)
  seq.push(other)
  let mut a = poly
  let mut b = other
  while !b.is_zero() {
    let (_, r) = a.divmod_univar(b)
    if r.is_zero() {
      break
    }
    seq.push(r)
    a = b
    b = r
  }
  seq
}
