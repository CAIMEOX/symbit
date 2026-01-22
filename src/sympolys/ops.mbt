///|
/// Resultant placeholder; keeps API visible while algorithms are built.
pub fn Poly::resultant(
  self : Poly,
  other : Poly,
  gen_index : Int,
) -> @symnum.BigRational raise PolyError {
  if self.domain.not_equal(other.domain) || self.gens.not_equal(other.gens) {
    raise PolyError::DomainMismatch
  }
  if gen_index < 0 || gen_index >= self.gens.length() {
    raise PolyError::BadGenerator("\{gen_index}".to_string())
  }
  if gen_index != 0 {
    return resultant_elim(self, other, gen_index)
  }
  resultant_univar(self, other)
}

///|
fn pow_big_rational(
  base : @symnum.BigRational,
  exp : Int,
) -> @symnum.BigRational raise PolyError {
  if exp < 0 {
    raise PolyError::BadExponent
  }
  let mut acc = @symnum.BigRational::one()
  let mut e = exp
  let mut b = base
  while e > 0 {
    if e % 2 == 1 {
      acc = acc.mul_r(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul_r(b)
    }
  }
  acc
}

///|
fn resultant_univar(a : Poly, b : Poly) -> @symnum.BigRational raise PolyError {
  check_univar_compat(a, b)
  if a.is_zero() || b.is_zero() {
    return @symnum.BigRational::zero()
  }
  let mut p = if a.domain is Domain::QQ { a } else { lift_to_qq(a) }
  let mut q = if b.domain is Domain::QQ { b } else { lift_to_qq(b) }
  let mut res = @symnum.BigRational::one()
  while true {
    let (deg_p, _) = match leading_data_univar(p) {
      Some(v) => v
      None => raise PolyError::DivisionByZero
    }
    let (deg_q, lc_q) = match leading_data_univar(q) {
      Some(v) => v
      None => raise PolyError::DivisionByZero
    }
    if deg_q == 0 {
      return res.mul_r(pow_big_rational(lc_q, deg_p))
    }
    let (_, r) = divmod_univar_rat(p, q)
    if r.is_zero() {
      return res.mul_r(pow_big_rational(lc_q, deg_p))
    }
    let (deg_r, _) = match leading_data_univar(r) {
      Some(v) => v
      None => raise PolyError::DivisionByZero
    }
    res = res.mul_r(pow_big_rational(lc_q, deg_p - deg_r))
    if deg_p * deg_q % 2 == 1 {
      res = res.neg_r()
    }
    p = q
    q = r
  }
  raise PolyError::DivisionByZero
}

///|
fn resultant_elim(
  a : Poly,
  b : Poly,
  gen_index : Int,
) -> @symnum.BigRational raise PolyError {
  if a.gens.length() <= gen_index || b.gens.length() <= gen_index {
    raise PolyError::BadGenerator("\{gen_index}".to_string())
  }
  let basis = Poly::groebner([a, b], order=TermOrder::Lex)
  for p in basis {
    let mut depends = false
    for m, _ in p.coeffs {
      if m.exps[gen_index] != 0 {
        depends = true
        break
      }
    }
    if !depends {
      // If elimination yields a constant, return it; otherwise not a pure resultant.
      if p.gens.length() == 1 ||
        (p.coeffs.length() == 1 && p.degree(gen_index) == 0) {
        match p.leading_term() {
          Some((_, c)) => return c
          None => continue
        }
      }
    }
  }
  raise PolyError::NotImplemented("resultant-elimination")
}
