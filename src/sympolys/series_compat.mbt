///|
/// Truncated power-series ring `K[[x]]/(x^prec)`.
pub struct SeriesRing {
  domain : Domain
  sym : String
  precision : Int
} derive(Eq)

///|
/// Element in a truncated univariate power-series ring.
/// Coefficients are stored in ascending degree order.
pub struct SeriesElem {
  ring : SeriesRing
  coeffs : Array[FieldElem]
}

///|
pub fn power_series_ring(
  domain : Domain,
  sym : String,
  precision : Int,
) -> SeriesRing raise PolyError {
  if precision <= 0 {
    raise PolyError::BadExponent
  }
  SeriesRing::{ domain, sym, precision }
}

///|
fn normalize_series_coeffs(
  ring : SeriesRing,
  coeffs : Array[FieldElem],
) -> Array[FieldElem] {
  let mut end = coeffs.length()
  if end > ring.precision {
    end = ring.precision
  }
  while end > 0 && fe_is_zero(coeffs[end - 1]) {
    end = end - 1
  }
  let out : Array[FieldElem] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
pub fn SeriesRing::zero(self : SeriesRing) -> SeriesElem {
  SeriesElem::{ ring: self, coeffs: [] }
}

///|
pub fn SeriesRing::one(self : SeriesRing) -> SeriesElem raise PolyError {
  SeriesElem::{ ring: self, coeffs: [fe_from_int(1, self.domain)] }
}

///|
pub fn SeriesRing::from_coeffs(self : SeriesRing, coeffs : Array[FieldElem]) -> SeriesElem {
  SeriesElem::{ ring: self, coeffs: normalize_series_coeffs(self, coeffs) }
}

///|
pub fn SeriesRing::from_int_coeffs(self : SeriesRing, coeffs : Array[Int]) -> SeriesElem raise PolyError {
  let lifted : Array[FieldElem] = Array::new()
  for c in coeffs {
    lifted.push(fe_from_int(c, self.domain))
  }
  self.from_coeffs(lifted)
}

///|
pub fn SeriesRing::from_poly(self : SeriesRing, poly : Poly) -> SeriesElem raise PolyError {
  if poly.gens.length() != 1 || poly.gens[0] != self.sym || poly.domain.not_equal(self.domain) {
    raise PolyError::DomainMismatch
  }
  let degree = poly.degree(0)
  let coeffs = to_dense(poly, degree~)
  self.from_coeffs(coeffs)
}

///|
pub fn SeriesElem::coeff(self : SeriesElem, n : Int) -> FieldElem raise PolyError {
  if n < 0 || n >= self.ring.precision {
    raise PolyError::BadExponent
  }
  if n < self.coeffs.length() {
    self.coeffs[n]
  } else {
    fe_from_int(0, self.ring.domain)
  }
}

///|
pub fn SeriesElem::add(self : SeriesElem, other : SeriesElem) -> SeriesElem raise PolyError {
  if self.ring != other.ring {
    raise PolyError::DomainMismatch
  }
  let n = if self.coeffs.length() > other.coeffs.length() {
    self.coeffs.length()
  } else {
    other.coeffs.length()
  }
  let coeffs : Array[FieldElem] = Array::new()
  for i in 0..<n {
    let a = if i < self.coeffs.length() {
      self.coeffs[i]
    } else {
      fe_from_int(0, self.ring.domain)
    }
    let b = if i < other.coeffs.length() {
      other.coeffs[i]
    } else {
      fe_from_int(0, self.ring.domain)
    }
    coeffs.push(fe_add(a, b))
  }
  SeriesElem::{ ring: self.ring, coeffs: normalize_series_coeffs(self.ring, coeffs) }
}

///|
pub fn SeriesElem::neg(self : SeriesElem) -> SeriesElem {
  SeriesElem::{ ring: self.ring, coeffs: self.coeffs.map(c => fe_neg(c)) }
}

///|
pub fn SeriesElem::sub(self : SeriesElem, other : SeriesElem) -> SeriesElem raise PolyError {
  self.add(other.neg())
}

///|
pub fn SeriesElem::mul(self : SeriesElem, other : SeriesElem) -> SeriesElem raise PolyError {
  if self.ring != other.ring {
    raise PolyError::DomainMismatch
  }
  let n = self.ring.precision
  let zero = fe_from_int(0, self.ring.domain)
  let coeffs : Array[FieldElem] = Array::make(n, zero)
  for i in 0..<self.coeffs.length() {
    for j in 0..<other.coeffs.length() {
      let k = i + j
      if k >= n {
        continue
      }
      let term = fe_mul(self.coeffs[i], other.coeffs[j])
      coeffs.set(k, fe_add(coeffs[k], term))
    }
  }
  SeriesElem::{ ring: self.ring, coeffs: normalize_series_coeffs(self.ring, coeffs) }
}

///|
pub fn SeriesElem::truncate(self : SeriesElem, n : Int) -> SeriesElem {
  let ring = if n < self.ring.precision {
    SeriesRing::{ domain: self.ring.domain, sym: self.ring.sym, precision: n }
  } else {
    self.ring
  }
  SeriesElem::{ ring, coeffs: normalize_series_coeffs(ring, self.coeffs) }
}

///|
pub fn SeriesElem::diff(self : SeriesElem) -> SeriesElem raise PolyError {
  if self.coeffs.length() <= 1 {
    return self.ring.zero()
  }
  let coeffs : Array[FieldElem] = Array::new()
  for i in 1..<self.coeffs.length() {
    coeffs.push(fe_mul(fe_from_int(i, self.ring.domain), self.coeffs[i]))
  }
  SeriesElem::{ ring: self.ring, coeffs: normalize_series_coeffs(self.ring, coeffs) }
}

///|
pub fn SeriesElem::integrate(self : SeriesElem) -> SeriesElem raise PolyError {
  let coeffs : Array[FieldElem] = [fe_from_int(0, self.ring.domain)]
  for i in 0..<self.coeffs.length() {
    let den = fe_from_int(i + 1, self.ring.domain)
    coeffs.push(fe_mul(self.coeffs[i], fe_inv(den)))
  }
  SeriesElem::{ ring: self.ring, coeffs: normalize_series_coeffs(self.ring, coeffs) }
}

///|
pub fn SeriesElem::to_expr(self : SeriesElem) -> @symcore.Expr {
  let x = @symcore.symbol(self.ring.sym)
  let terms : Array[@symcore.Expr] = Array::new()
  for i in 0..<self.coeffs.length() {
    let c = self.coeffs[i]
    if fe_is_zero(c) {
      continue
    }
    let coeff_expr = fe_to_expr_const(c)
    let term = if i == 0 {
      coeff_expr
    } else if i == 1 {
      coeff_expr * x
    } else {
      coeff_expr * (x ^ @symcore.int(i))
    }
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(terms)
  }
}
