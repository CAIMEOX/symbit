///|
pub(all) enum Domain {
  ZZ
  QQ
  GF(Int) // prime modulus
  GFExt(Int, Int, Array[Int]) // GF(p^k) with modulus polynomial coefficients (lowest degree first)
  AlgExt(Domain, Array[String], Array[@symcore.Expr]) // algebraic extension over base with generators/relations
}

///|
pub(all) enum TermOrder {
  Lex
  Grlex
  Grevlex
}

///|
pub(all) suberror PolyError {
  NonPolynomial
  BadGenerator(String)
  BadExponent
  DomainMismatch
  CoefficientNotInteger
  DomainNotField
  DivisionByZero
  NotUnivariate
  NotImplemented(String)
  BadModulus
}

///|
impl Eq for Domain with equal(self, other : Domain) -> Bool {
  match (self, other) {
    (Domain::ZZ, Domain::ZZ) | (Domain::QQ, Domain::QQ) => true
    (Domain::GF(p1), Domain::GF(p2)) => p1 == p2
    (Domain::GFExt(p1, k1, m1), Domain::GFExt(p2, k2, m2)) =>
      p1 == p2 && k1 == k2 && m1.equal(m2)
    (Domain::AlgExt(base1, syms1, rels1), Domain::AlgExt(base2, syms2, rels2)) =>
      base1.equal(base2) && syms1.equal(syms2) && rels1.length() == rels2.length()
    _ => false
  }
}

///|
impl Eq for Domain with not_equal(self, other : Domain) -> Bool {
  !self.equal(other)
}

///|
impl Eq for TermOrder with equal(self, other : TermOrder) -> Bool {
  match (self, other) {
    (TermOrder::Lex, TermOrder::Lex)
    | (TermOrder::Grlex, TermOrder::Grlex)
    | (TermOrder::Grevlex, TermOrder::Grevlex) => true
    _ => false
  }
}

///|
impl Eq for TermOrder with not_equal(self, other : TermOrder) -> Bool {
  !self.equal(other)
}

///|
pub impl Show for PolyError with output(self, logger : &Logger) -> Unit {
  match self {
    PolyError::NonPolynomial => logger.write_string("NonPolynomial")
    PolyError::BadGenerator(name) =>
      logger.write_string("BadGenerator(\{name})")
    PolyError::BadExponent => logger.write_string("BadExponent")
    PolyError::DomainMismatch => logger.write_string("DomainMismatch")
    PolyError::CoefficientNotInteger =>
      logger.write_string("CoefficientNotInteger")
    PolyError::DomainNotField => logger.write_string("DomainNotField")
    PolyError::DivisionByZero => logger.write_string("DivisionByZero")
    PolyError::NotUnivariate => logger.write_string("NotUnivariate")
    PolyError::NotImplemented(name) =>
      logger.write_string("NotImplemented(\{name})")
    PolyError::BadModulus => logger.write_string("BadModulus")
  }
}
