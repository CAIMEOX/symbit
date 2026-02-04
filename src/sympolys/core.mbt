///|
pub struct Poly {
  coeffs : Map[Monomial, FieldElem]
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
pub fn Poly::zero(gens : Array[String], domain : Domain) -> Poly {
  Poly::{ coeffs: Map::new(), gens, domain, order: TermOrder::Lex }
}

///|
pub fn Poly::one(gens : Array[String], domain : Domain) -> Poly raise PolyError {
  let mono = monomial_one(gens.length())
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  coeffs.set(mono, fe_from_int(1, domain))
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
) -> FieldElem raise PolyError {
  match domain {
    Domain::ZZ =>
      if coeff.is_integral() {
        FieldElem::QQ(coeff)
      } else {
        raise PolyError::CoefficientNotInteger
      }
    Domain::QQ => FieldElem::QQ(coeff)
    Domain::CC => FieldElem::CC(coeff, @symnum.BigRational::zero())
    Domain::RR => FieldElem::QQ(coeff) // placeholder, treat as QQ for now
    Domain::Frac(inner) => ensure_coeff_domain(coeff, inner)
    Domain::GF(_) | Domain::GFExt(_, _, _) => {
      let norm = normalize_mod(coeff, domain)
      fe_from_int(norm.numerator().to_int(), domain)
    }
    Domain::AlgExt(base, gens, rels) =>
      fe_from_rational(coeff, Domain::AlgExt(base, gens, rels))
  }
}

///|
pub fn add_term(
  coeffs : Map[Monomial, FieldElem],
  mono : Monomial,
  coeff : FieldElem,
  _domain : Domain,
) -> Unit raise PolyError {
  if fe_is_zero(coeff) {
    return
  }
  let coeff_val = coeff
  match coeffs.get(mono) {
    Some(existing) => {
      let updated = fe_add(existing, coeff_val)
      if fe_is_zero(updated) {
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
  factor : FieldElem,
) -> Poly raise PolyError {
  let coeffs = Map::new()
  for m, c in self.coeffs {
    add_term(coeffs, m, fe_mul(c, factor), self.domain)
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
    coeffs.set(m, fe_neg(c))
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
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m1, c1 in self.coeffs {
    for m2, c2 in other.coeffs {
      let mono = monomial_mul(m1, m2)
      add_term(coeffs, mono, fe_mul(c1, c2), self.domain)
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
