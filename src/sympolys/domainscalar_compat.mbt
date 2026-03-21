///|
/// Domain-tagged scalar used by matrix compatibility APIs.
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
pub fn domain_scalar_new(
  element : FieldElem,
  domain : Domain,
) -> DomainScalar raise PolyError {
  // Validation: element must support arithmetic with domain zero.
  let _ = fe_add(element, fe_from_int(0, domain))
  DomainScalar::{ element, domain }
}

///|
pub fn DomainScalar::new(
  element : FieldElem,
  domain : Domain,
) -> DomainScalar raise PolyError {
  domain_scalar_new(element, domain)
}

///|
pub fn domain_scalar_from_int(
  n : Int,
  domain : Domain,
) -> DomainScalar raise PolyError {
  domain_scalar_new(fe_from_int(n, domain), domain)
}

///|
pub fn DomainScalar::from_sympy(expr : Expr) -> DomainScalar raise PolyError {
  let domain = infer_expr_items_domain([expr])
  let element = field_elem_from_scalar_expr(expr, domain)
  domain_scalar_new(element, domain)
}

///|
pub fn DomainScalar::to_domain(
  self : DomainScalar,
  domain : Domain,
) -> DomainScalar raise PolyError {
  domain_scalar_new(coerce_scalar(self.element, domain), domain)
}

///|
pub fn DomainScalar::convert_to(
  self : DomainScalar,
  domain : Domain,
) -> DomainScalar raise PolyError {
  self.to_domain(domain)
}

///|
pub fn DomainScalar::unify(
  self : DomainScalar,
  other : DomainScalar,
) -> (DomainScalar, DomainScalar) raise PolyError {
  let domain = domain_unify_pair(self.domain, other.domain)
  (self.to_domain(domain), other.to_domain(domain))
}

///|
pub fn DomainScalar::add(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(fe_add(a.element, b.element), a.domain)
}

///|
pub fn DomainScalar::sub(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(fe_sub(a.element, b.element), a.domain)
}

///|
pub fn DomainScalar::mul(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(fe_mul(a.element, b.element), a.domain)
}

///|
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
pub fn DomainScalar::floordiv(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(scalar_quo(a.element, b.element, a.domain), a.domain)
}

///|
pub fn DomainScalar::mod(
  self : DomainScalar,
  other : DomainScalar,
) -> DomainScalar raise PolyError {
  let (a, b) = self.unify(other)
  domain_scalar_new(scalar_rem(a.element, b.element, a.domain), a.domain)
}

///|
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
pub fn DomainScalar::pos(self : DomainScalar) -> DomainScalar raise PolyError {
  domain_scalar_new(self.element, self.domain)
}

///|
pub fn DomainScalar::neg(self : DomainScalar) -> DomainScalar raise PolyError {
  domain_scalar_new(fe_neg(self.element), self.domain)
}

///|
pub fn DomainScalar::is_zero(self : DomainScalar) -> Bool {
  fe_is_zero(self.element)
}

///|
pub fn DomainScalar::is_one(self : DomainScalar) -> Bool {
  fe_is_one(self.element)
}

///|
pub impl Show for DomainScalar with to_string(self) -> String {
  self.element.to_string()
}

///|
pub impl Show for DomainScalar with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn DomainScalar::to_sympy(self : DomainScalar) -> Expr {
  fe_to_expr_const(self.element)
}
