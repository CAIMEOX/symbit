///|
/// Domain-tagged scalar compatibility front doors.
///
/// Current Limits:
/// - this layer models scalar coercion and arithmetic for matrix/polynomial
///   compatibility code, not every scalar operation in the package.
/// - division-like operations stay conservative outside the exact domains
///   supported here.

///|
/// Domain-tagged scalar used by matrix compatibility APIs.
///
/// - Does: Pairs one scalar element with the domain that should interpret it.
/// - Input: Built from a `FieldElem` and `Domain`.
/// - Returns: A `DomainScalar`.
/// - Limits: The element must already be valid for the attached domain.
pub struct DomainScalar {
  element : FieldElem
  domain : Domain
}

///|
fn coerce_scalar(
  elem : FieldElem,
  to_domain : Domain,
) -> FieldElem raise PolyError {
  let q = fe_expect_rational(elem)
  fe_from_rational(q, to_domain)
}

///|
fn scalar_quo(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(b) {
    raise PolyError::DivisionByZero
  }
  match domain {
    Domain::ZZ => {
      let aq = fe_expect_rational(a)
      let bq = fe_expect_rational(b)
      let q = aq.numerator().div(bq.numerator())
      fe_from_rational(@symnum.BigRational::from_bigint(q), Domain::ZZ)
    }
    _ => fe_mul(a, fe_inv(b))
  }
}

///|
fn scalar_rem(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(b) {
    raise PolyError::DivisionByZero
  }
  match domain {
    Domain::ZZ => {
      let aq = fe_expect_rational(a)
      let bq = fe_expect_rational(b)
      let r = aq.numerator().mod(bq.numerator())
      fe_from_rational(@symnum.BigRational::from_bigint(r), Domain::ZZ)
    }
    _ => fe_from_int(0, domain)
  }
}

///|
/// Build a domain-tagged scalar.
///
/// - Does: Validates that `element` can participate in arithmetic over
///   `domain`.
/// - Input: A `FieldElem` and `Domain`.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the element is incompatible with the
///   domain.
pub fn domain_scalar_new(
  element : FieldElem,
  domain : Domain,
) -> DomainScalar raise PolyError {
  // Validation: element must support arithmetic with domain zero.
  let _ = fe_add(element, fe_from_int(0, domain))
  DomainScalar::{ element, domain }
}

///|
/// Build a domain-tagged scalar.
///
/// - Does: Method alias for the public scalar constructor.
/// - Input: A `FieldElem` and `Domain`.
/// - Returns: A `DomainScalar`.
/// - Limits: Shares the same validation rules as `domain_scalar_new`.
pub fn DomainScalar::new(
  element : FieldElem,
  domain : Domain,
) -> DomainScalar raise PolyError {
  domain_scalar_new(element, domain)
}

///|
/// Build a domain-tagged scalar from an integer literal.
///
/// - Does: Lifts `n` into `domain` and tags it with that domain.
/// - Input: An `Int` and `Domain`.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the domain cannot represent the integer.
pub fn domain_scalar_from_int(
  n : Int,
  domain : Domain,
) -> DomainScalar raise PolyError {
  domain_scalar_new(fe_from_int(n, domain), domain)
}

///|
/// Convert an expression into a domain-tagged scalar.
///
/// - Does: Infers a domain from the expression and converts the expression into
///   one scalar element of that domain.
/// - Input: An `Expr`.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the expression cannot be represented as
///   one scalar coefficient.
pub fn DomainScalar::from_sympy(expr : Expr) -> DomainScalar raise PolyError {
  let domain = infer_expr_items_domain([expr])
  let element = field_elem_from_scalar_expr(expr, domain)
  domain_scalar_new(element, domain)
}

///|
/// Convert a scalar into another domain.
///
/// - Does: Coerces the stored element into `domain`.
/// - Input: A `DomainScalar` and target `Domain`.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the scalar cannot be converted.
pub fn DomainScalar::to_domain(
  self : DomainScalar,
  domain : Domain,
) -> DomainScalar raise PolyError {
  domain_scalar_new(coerce_scalar(self.element, domain), domain)
}

///|
/// Alias for `to_domain`.
///
/// - Does: Preserves the compatibility spelling for scalar conversion.
/// - Input: A `DomainScalar` and target `Domain`.
/// - Returns: A `DomainScalar`.
/// - Limits: Shares the same conversion restrictions as `to_domain`.
pub fn DomainScalar::convert_to(
  self : DomainScalar,
  domain : Domain,
) -> DomainScalar raise PolyError {
  self.to_domain(domain)
}

///|
/// Unify two domain-tagged scalars to a common domain.
///
/// - Does: Converts both scalars into a shared super-domain.
/// - Input: Two `DomainScalar` values.
/// - Returns: `(DomainScalar, DomainScalar)`.
/// - Limits: Raises `PolyError` when no common domain is available.
pub fn DomainScalar::unify(
  self : DomainScalar,
  other : DomainScalar,
) -> (DomainScalar, DomainScalar) raise PolyError {
  let domain = domain_unify_pair(self.domain, other.domain)
  (self.to_domain(domain), other.to_domain(domain))
}

///|
/// Add two domain-tagged scalars.
///
/// - Does: Unifies domains first, then adds the scalar elements.
/// - Input: Two `DomainScalar` values.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the domains cannot be unified.
pub fn DomainScalar::add(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(fe_add(a.element, b.element), a.domain)
}

///|
/// Subtract two domain-tagged scalars.
///
/// - Does: Unifies domains first, then computes `self - other`.
/// - Input: Two `DomainScalar` values.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the domains cannot be unified.
pub fn DomainScalar::sub(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(fe_sub(a.element, b.element), a.domain)
}

///|
/// Multiply two domain-tagged scalars.
///
/// - Does: Unifies domains first, then multiplies the scalar elements.
/// - Input: Two `DomainScalar` values.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` when the domains cannot be unified.
pub fn DomainScalar::mul(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(fe_mul(a.element, b.element), a.domain)
}

///|
/// Raise a domain-tagged scalar to a non-negative integer power.
///
/// - Does: Computes repeated multiplication in the scalar domain.
/// - Input: A `DomainScalar` and non-negative exponent `Int`.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError::BadExponent` for negative exponents.
pub fn DomainScalar::pow(
  self : DomainScalar,
  n : Int,
) -> DomainScalar raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  let mut acc = fe_from_int(1, self.domain)
  let mut base = self.element
  let mut exp = n
  while exp > 0 {
    if exp % 2 == 1 {
      acc = fe_mul(acc, base)
    }
    exp = exp / 2
    if exp > 0 {
      base = fe_mul(base, base)
    }
  }
  domain_scalar_new(acc, self.domain)
}

///|
/// Compute floor-style scalar quotient.
///
/// - Does: Divides `self` by `other` using the current domain's quotient
///   semantics.
/// - Input: Two `DomainScalar` values.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` for zero divisors or unsupported quotient
///   semantics.
pub fn DomainScalar::floordiv(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(scalar_quo(a.element, b.element, a.domain), a.domain)
}

///|
/// Compute scalar remainder.
///
/// - Does: Returns the remainder of `self` modulo `other` using the current
///   domain semantics.
/// - Input: Two `DomainScalar` values.
/// - Returns: A `DomainScalar`.
/// - Limits: Raises `PolyError` for zero divisors or unsupported remainder
///   semantics.
pub fn DomainScalar::mod(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(scalar_rem(a.element, b.element, a.domain), a.domain)
}

///|
/// Compute scalar quotient and remainder together.
///
/// - Does: Returns `(self // other, self % other)` after domain unification.
/// - Input: Two `DomainScalar` values.
/// - Returns: `(DomainScalar, DomainScalar)`.
/// - Limits: Raises `PolyError` for zero divisors or unsupported quotient
///   semantics.
pub fn DomainScalar::divmod(
  self : DomainScalar,
  other : DomainScalar,
) -> (DomainScalar, DomainScalar) raise PolyError {
  let (a, b) = self.unify(other)
  (
    domain_scalar_new(scalar_quo(a.element, b.element, a.domain), a.domain),
    domain_scalar_new(scalar_rem(a.element, b.element, a.domain), a.domain),
  )
}

///|
/// Apply unary plus.
///
/// - Does: Returns the same scalar with validated domain tagging.
/// - Input: A `DomainScalar`.
/// - Returns: A `DomainScalar`.
/// - Limits: This does not change the scalar domain.
pub fn DomainScalar::pos(self : DomainScalar) -> DomainScalar raise PolyError {
  domain_scalar_new(self.element, self.domain)
}

///|
/// Apply unary minus.
///
/// - Does: Negates the scalar element.
/// - Input: A `DomainScalar`.
/// - Returns: A `DomainScalar`.
/// - Limits: This does not change the scalar domain.
pub fn DomainScalar::neg(self : DomainScalar) -> DomainScalar raise PolyError {
  domain_scalar_new(fe_neg(self.element), self.domain)
}

///|
/// Test whether the scalar is zero.
///
/// - Does: Checks the stored element against zero.
/// - Input: A `DomainScalar`.
/// - Returns: A `Bool`.
/// - Limits: This does not inspect alternative representations of the same
///   value.
pub fn DomainScalar::is_zero(self : DomainScalar) -> Bool {
  fe_is_zero(self.element)
}

///|
/// Test whether the scalar is one.
///
/// - Does: Checks the stored element against one.
/// - Input: A `DomainScalar`.
/// - Returns: A `Bool`.
/// - Limits: This does not inspect alternative representations of the same
///   value.
pub fn DomainScalar::is_one(self : DomainScalar) -> Bool {
  fe_is_one(self.element)
}

///|

///|
/// Display implementation for `DomainScalar.to_string`.
///
/// - Does: Formats `DomainScalar` values for display.
/// - Input: the receiver value and MoonBit logger/display protocol arguments.
/// - Returns: the formatted display output required by the `Show` implementation.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub impl Show for DomainScalar with to_string(self) -> String {
  self.element.to_string()
}

///|

///|
/// Display implementation for `DomainScalar.output`.
///
/// - Does: Formats `DomainScalar` values for display.
/// - Input: the receiver value and MoonBit logger/display protocol arguments.
/// - Returns: the formatted display output required by the `Show` implementation.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub impl Show for DomainScalar with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// Convert the scalar back into an expression.
///
/// - Does: Rebuilds an `Expr` from the stored scalar element and domain tag.
/// - Input: A `DomainScalar`.
/// - Returns: An `Expr`.
/// - Limits: The result follows the package's current domain-to-expression
///   conventions.
pub fn DomainScalar::to_sympy(self : DomainScalar) -> Expr {
  fe_to_expr_const(self.element)
}
