///|
/// Sparse polynomial value type.
///
/// - Does: Stores a polynomial as a sparse monomial-to-coefficient map together
///   with generators, coefficient domain, and term order.
/// - Input: Internal polynomial data produced by the public constructors in this
///   package.
/// - Returns: A `Poly` value that can be used with arithmetic, factorization,
///   conversion, and elimination front doors.
/// - Limits: This type does not validate raw fields on construction; callers
///   should prefer `PolyBuilder` or `Poly::from_expr*` front doors.
pub struct Poly {
  coeffs : Map[Monomial, FieldElem]
  gens : Array[String]
  domain : Domain
  order : TermOrder
}

///|
/// Alias for a polynomial with explicit generators.
///
/// - Does: Mirrors SymPy's `PurePoly` public name.
/// - Input: Same representation as `Poly`.
/// - Returns: A `Poly` value.
/// - Limits: Symbit does not split `Poly` and `PurePoly` into separate runtime
///   classes.
pub type PurePoly = Poly

///|
/// Build the zero polynomial over a generator list and coefficient domain.
///
/// - Does: Creates the additive identity polynomial.
/// - Input: An ordered generator array and a coefficient `Domain`.
/// - Returns: A `Poly` with no non-zero terms.
/// - Limits: The returned polynomial always starts with `Lex` term order.
pub fn Poly::zero(gens : Array[String], domain : Domain) -> Poly {
  Poly::{ coeffs: Map([]), gens, domain, order: TermOrder::Lex }
}

///|
/// Build the unit polynomial over a generator list and coefficient domain.
///
/// - Does: Creates the multiplicative identity polynomial.
/// - Input: An ordered generator array and a coefficient `Domain`.
/// - Returns: A constant `Poly` equal to `1`.
/// - Limits: Raises `PolyError` when the target domain cannot represent `1`.
pub fn Poly::one(gens : Array[String], domain : Domain) -> Poly raise PolyError {
  let mono = monomial_one(gens.length())
  let coeffs : Map[Monomial, FieldElem] = Map([])
  coeffs.set(mono, fe_from_int(1, domain))
  Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
}

///|
/// Check whether a polynomial is identically zero.
///
/// - Does: Tests whether sparse storage contains any non-zero term.
/// - Input: One `Poly`.
/// - Returns: A `Bool`.
/// - Limits: This only checks normalized storage; raw malformed values are out
///   of scope for this front door.
pub fn Poly::is_zero(self : Poly) -> Bool {
  self.coeffs.is_empty()
}

///|
/// Rebind a polynomial to a different monomial order.
///
/// - Does: Keeps coefficients, generators, and domain unchanged while swapping
///   the stored term order.
/// - Input: One `Poly` and one `TermOrder`.
/// - Returns: A `Poly`.
/// - Limits: This does not reorder or recompute coefficients; it only changes
///   how later ordered operations view the same data.
pub fn Poly::with_order(self : Poly, order : TermOrder) -> Poly {
  Poly::{ coeffs: self.coeffs, gens: self.gens, domain: self.domain, order }
}

///|
/// Coerce/validate coefficients against a target polynomial domain.
fn ensure_coeff_domain(
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
    // Keep RR distinct from QQ by using real-valued complex elements (imag=0).
    Domain::RR => FieldElem::CC(coeff, @symnum.BigRational::zero())
    Domain::ZZ_I | Domain::QQ_I =>
      FieldElem::CC(coeff, @symnum.BigRational::zero())
    Domain::EX | Domain::EXRAW => FieldElem::QQ(coeff)
    Domain::Frac(inner) => ensure_coeff_domain(coeff, inner)
    Domain::PolyRing(base, _) => ensure_coeff_domain(coeff, base)
    Domain::RationalFunctionField(base, _) => ensure_coeff_domain(coeff, base)
    Domain::QuotientRing(base, _, _) => ensure_coeff_domain(coeff, base)
    Domain::PowerSeries(base, _, _) => ensure_coeff_domain(coeff, base)
    Domain::GF(_) | Domain::GFExt(_, _, _) => {
      let norm = normalize_mod(coeff, domain)
      fe_from_int(norm.numerator().to_int(), domain)
    }
    Domain::AlgExt(base, gens, rels) =>
      fe_from_rational(coeff, Domain::AlgExt(base, gens, rels))
  }
}

///|
/// Insert a term into sparse polynomial storage with term merging.
fn add_term(
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
fn poly_rational_from_ints(
  num : Int,
  den : Int,
) -> @symnum.BigRational raise PolyError {
  @symnum.BigRational::from_ints(num, den) catch {
    _ => raise PolyError::DivisionByZero
  }
}

///|
fn poly_rational_from_bigints(
  num : BigInt,
  den : BigInt,
) -> @symnum.BigRational raise PolyError {
  @symnum.BigRational::new(num, den) catch {
    _ => raise PolyError::DivisionByZero
  }
}

///|
fn poly_rational_div(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  lhs.div_r(rhs) catch {
    _ => raise PolyError::DivisionByZero
  }
}

///|
/// Scale every coefficient by one field element.
///
/// - Does: Multiplies all stored coefficients by `factor`.
/// - Input: One `Poly` and one `FieldElem`.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError` when coefficient arithmetic fails in the target
///   domain.
pub fn Poly::scale_coeff(
  self : Poly,
  factor : FieldElem,
) -> Poly raise PolyError {
  let coeffs = Map([])
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
/// Add two compatible polynomials.
///
/// - Does: Computes polynomial addition term by term.
/// - Input: Two `Poly` values over the same generators and domain.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError::DomainMismatch` when generators or domains do
///   not match.
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
/// Negate a polynomial.
///
/// - Does: Multiplies every coefficient by `-1`.
/// - Input: One `Poly`.
/// - Returns: A `Poly`.
/// - Limits: This front door assumes coefficients are already normalized in the
///   polynomial domain.
pub fn Poly::neg(self : Poly) -> Poly {
  let coeffs = Map([])
  for m, c in self.coeffs {
    coeffs.set(m, fe_neg(c))
  }
  Poly::{ coeffs, gens: self.gens, domain: self.domain, order: self.order }
}

///|
/// Subtract one compatible polynomial from another.
///
/// - Does: Computes `self - other`.
/// - Input: Two `Poly` values over the same generators and domain.
/// - Returns: A `Poly`.
/// - Limits: Raises the same front-door errors as `Poly::add`.
pub fn Poly::sub(self : Poly, other : Poly) -> Poly raise PolyError {
  self.add(other.neg())
}

///|
/// Multiply two compatible polynomials.
///
/// - Does: Expands the distributive product term by term.
/// - Input: Two `Poly` values over the same generators and domain.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError::DomainMismatch` when generators or domains do
///   not match.
pub fn Poly::mul(self : Poly, other : Poly) -> Poly raise PolyError {
  if self.domain.not_equal(other.domain) || !same_gens(self.gens, other.gens) {
    raise PolyError::DomainMismatch
  }
  let coeffs : Map[Monomial, FieldElem] = Map([])
  for m1, c1 in self.coeffs {
    for m2, c2 in other.coeffs {
      let mono = monomial_mul(m1, m2)
      add_term(coeffs, mono, fe_mul(c1, c2), self.domain)
    }
  }
  Poly::{ coeffs, gens: self.gens, domain: self.domain, order: self.order }
}

///|
/// Raise a polynomial to a non-negative integer power.
///
/// - Does: Computes repeated squaring over polynomial multiplication.
/// - Input: One `Poly` and one non-negative `Int`.
/// - Returns: A `Poly`.
/// - Limits: Raises `PolyError::BadExponent` for negative exponents.
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
