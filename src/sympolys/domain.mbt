///|
/// Public domain and error descriptors shared by the polynomial package.
///
/// Current Limits:
/// - these descriptors capture the package-level compatibility model, not every
///   property of a full computer algebra domain hierarchy.
/// - composite-domain behavior is defined by the public helpers in
///   `domains_compat.mbt`.

///|
/// Coefficient domain descriptor used throughout `sympolys`.
///
/// - Does: Names the coefficient family attached to a polynomial, matrix, or
///   series object.
/// - Input: Constructed from one of the tagged variants such as `ZZ`, `QQ`,
///   `GF(p)`, or composite domains.
/// - Returns: A `Domain` value.
/// - Limits: This is a structural descriptor. Operations such as coercion or
///   field/ring conversion live in the domain helper front doors.
pub(all) enum Domain {
  ZZ
  QQ
  CC // Gaussian rationals a + b*i
  RR // real-coefficient domain (stored as CC elements with zero imaginary part)
  ZZ_I // Gaussian integers
  QQ_I // Gaussian rationals as a named domain
  EX // expression domain
  EXRAW // raw expression domain
  Frac(Domain) // fraction field over an integral domain
  PolyRing(Domain, Array[String]) // K[x1, ..., xn]
  RationalFunctionField(Domain, Array[String]) // K(x1, ..., xn)
  QuotientRing(Domain, Array[String], Array[Expr]) // K[x]/I
  PowerSeries(Domain, Array[String], Int) // K[[x1, ..., xn]] with optional precision hint
  GF(Int) // prime modulus
  GFExt(Int, Int, Array[Int]) // GF(p^k) with modulus polynomial coefficients (lowest degree first)
  AlgExt(Domain, Array[String], Array[Expr]) // algebraic extension over base with generators/relations
}

///|
/// Monomial order descriptor for polynomial front doors.
///
/// - Does: Selects how exponent tuples are compared in order-sensitive
///   algorithms.
/// - Input: One of the supported order tags.
/// - Returns: A `TermOrder`.
/// - Limits: Only the orders listed here are available through the stable
///   public API.
pub(all) enum TermOrder {
  Lex
  Grlex
  Grevlex
  Ilex
  Igrlex
  Igrevlex
} derive(Eq)

///|
/// Public error family raised by `sympolys`.
///
/// - Does: Classifies front-door failures such as malformed generators,
///   incompatible domains, or unsupported exact-division requests.
/// - Input: Constructed by the package when a public polynomial operation
///   cannot proceed.
/// - Returns: A `PolyError`.
/// - Limits: Error values describe the failure class, not every internal cause.
pub(all) suberror PolyError {
  NonPolynomial
  BadGenerator(String)
  BadExponent
  DomainMismatch
  CoefficientNotInteger
  DomainNotField
  DivisionByZero
  ExactQuotientFailed
  PolynomialDivisionFailed
  NotUnivariate
  BadModulus
}

///|
impl Eq for Domain with fn equal(self, other : Domain) -> Bool {
  match (self, other) {
    (ZZ, ZZ)
    | (QQ, QQ)
    | (CC, CC)
    | (RR, RR)
    | (ZZ_I, ZZ_I)
    | (QQ_I, QQ_I)
    | (EX, EX)
    | (EXRAW, EXRAW) => true
    (GF(p1), GF(p2)) => p1 == p2
    (GFExt(p1, k1, m1), GFExt(p2, k2, m2)) =>
      p1 == p2 && k1 == k2 && m1.equal(m2)
    (Frac(d1), Frac(d2)) => Eq::equal(d1, d2)
    (PolyRing(base1, gens1), PolyRing(base2, gens2)) =>
      Eq::equal(base1, base2) && gens1.equal(gens2)
    (RationalFunctionField(base1, gens1), RationalFunctionField(base2, gens2)) =>
      Eq::equal(base1, base2) && gens1.equal(gens2)
    (QuotientRing(base1, gens1, rels1), QuotientRing(base2, gens2, rels2)) =>
      Eq::equal(base1, base2) && gens1.equal(gens2) && rels1.equal(rels2)
    (PowerSeries(base1, gens1, prec1), PowerSeries(base2, gens2, prec2)) =>
      Eq::equal(base1, base2) && gens1.equal(gens2) && prec1 == prec2
    (AlgExt(base1, syms1, rels1), AlgExt(base2, syms2, rels2)) =>
      Eq::equal(base1, base2) && syms1.equal(syms2) && rels1.equal(rels2)
    _ => false
  }
}

///|
impl Eq for Domain with fn not_equal(self, other : Domain) -> Bool {
  !Eq::equal(self, other)
}

///|
/// Keep the equality dot-style API explicit now that trait implementations
/// are no longer promoted to methods implicitly.
#deprecated
pub extend Domain with Eq::{equal, not_equal}

///|
/// Render a `PolyError` into its stable textual form.
///
/// - Does: Writes the public error spelling used by tests and user-facing
///   diagnostics.
/// - Input: A `PolyError`.
/// - Returns: `Unit`.
/// - Limits: The output is intended for diagnostics, not for structured
///   recovery.
pub impl Show for PolyError with fn output(self, logger : &Logger) -> Unit {
  match self {
    NonPolynomial => logger.write_string("NonPolynomial")
    BadGenerator(name) => logger.write_string("BadGenerator(\{name})")
    BadExponent => logger.write_string("BadExponent")
    DomainMismatch => logger.write_string("DomainMismatch")
    CoefficientNotInteger => logger.write_string("CoefficientNotInteger")
    DomainNotField => logger.write_string("DomainNotField")
    DivisionByZero => logger.write_string("DivisionByZero")
    ExactQuotientFailed => logger.write_string("ExactQuotientFailed")
    PolynomialDivisionFailed => logger.write_string("PolynomialDivisionFailed")
    NotUnivariate => logger.write_string("NotUnivariate")
    BadModulus => logger.write_string("BadModulus")
  }
}
