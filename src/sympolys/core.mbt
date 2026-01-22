///|
pub struct Poly {
  coeffs : Map[Monomial, @symnum.BigRational]
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
pub fn Poly::zero(gens : Array[String], domain : Domain) -> Poly {
  Poly::{ coeffs: Map::new(), gens, domain, order: TermOrder::Lex }
}

///|
pub fn Poly::one(gens : Array[String], domain : Domain) -> Poly {
  let mono = monomial_one(gens.length())
  let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
  coeffs.set(mono, @symnum.BigRational::one())
  Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
}

///|
pub fn Poly::is_zero(self : Poly) -> Bool {
  self.coeffs.is_empty()
}

///|
pub fn Poly::with_order(self : Poly, order : TermOrder) -> Poly {
  Poly::{ coeffs: self.coeffs, gens: self.gens, domain: self.domain, order }
}

///|
pub fn ensure_coeff_domain(
  coeff : @symnum.BigRational,
  domain : Domain,
) -> @symnum.BigRational raise PolyError {
  match domain {
    Domain::ZZ =>
      if coeff.is_integral() {
        coeff
      } else {
        raise PolyError::CoefficientNotInteger
      }
    Domain::QQ => coeff
    Domain::GF(_) => normalize_mod(coeff, domain)
  }
}

///|
pub fn add_term(
  coeffs : Map[Monomial, @symnum.BigRational],
  mono : Monomial,
  coeff : @symnum.BigRational,
  domain : Domain,
) -> Unit raise PolyError {
  if coeff.is_zero() {
    return
  }
  let coeff_val = ensure_coeff_domain(coeff, domain)
  match coeffs.get(mono) {
    Some(existing) => {
      let updated = ensure_coeff_domain(existing.add_r(coeff_val), domain)
      if updated.is_zero() {
        coeffs.remove(mono)
      } else {
        coeffs.set(mono, updated)
      }
    }
    None => coeffs.set(mono, coeff_val)
  }
}

///|
pub fn Poly::scale_coeff(
  self : Poly,
  factor : @symnum.BigRational,
) -> Poly raise PolyError {
  let coeffs = Map::new()
  for m, c in self.coeffs {
    add_term(coeffs, m, c.mul_r(factor), self.domain)
  }
  Poly::{ coeffs, gens: self.gens, domain: self.domain, order: self.order }
}

///|
fn same_gens(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
pub fn Poly::add(self : Poly, other : Poly) -> Poly raise PolyError {
  if self.domain.not_equal(other.domain) || !same_gens(self.gens, other.gens) {
    raise PolyError::DomainMismatch
  }
  let coeffs = self.coeffs.copy()
  for m, c in other.coeffs {
    add_term(coeffs, m, c, self.domain)
  }
  Poly::{ coeffs, gens: self.gens, domain: self.domain, order: self.order }
}

///|
pub fn Poly::neg(self : Poly) -> Poly {
  let coeffs = Map::new()
  for m, c in self.coeffs {
    coeffs.set(m, c.neg_r())
  }
  Poly::{ coeffs, gens: self.gens, domain: self.domain, order: self.order }
}

///|
pub fn Poly::sub(self : Poly, other : Poly) -> Poly raise PolyError {
  self.add(other.neg())
}

///|
pub fn Poly::mul(self : Poly, other : Poly) -> Poly raise PolyError {
  if self.domain.not_equal(other.domain) || !same_gens(self.gens, other.gens) {
    raise PolyError::DomainMismatch
  }
  let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
  for m1, c1 in self.coeffs {
    for m2, c2 in other.coeffs {
      let mono = monomial_mul(m1, m2)
      add_term(coeffs, mono, c1.mul_r(c2), self.domain)
    }
  }
  Poly::{ coeffs, gens: self.gens, domain: self.domain, order: self.order }
}

///|
pub fn Poly::pow(self : Poly, k : Int) -> Poly raise PolyError {
  if k < 0 {
    raise PolyError::BadExponent
  }
  let mut result = Poly::one(self.gens, self.domain)
  let mut base = self
  let mut exp = k
  while exp > 0 {
    if exp % 2 == 1 {
      result = result.mul(base)
    }
    exp = exp / 2
    if exp > 0 {
      base = base.mul(base)
    }
  }
  result
}
