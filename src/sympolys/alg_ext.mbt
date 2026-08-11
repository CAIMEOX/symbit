///|
/// Algebraic-extension specification front doors.
///
/// Current Limits:
/// - This layer only validates and normalizes extension specifications.
/// - Full algebraic extension arithmetic lives elsewhere in the package.

///|
/// Specification for one simple algebraic extension.
///
/// - Does: Stores the ground domain, generator name, and defining minimal
///   polynomial for a monogenic extension.
/// - Input: Structured fields managed through the public helpers below.
/// - Returns: An `AlgExtSpec`.
/// - Limits: The raw struct does not validate monicity or generator shape on
///   construction.
pub struct AlgExtSpec {
  base : Domain
  gen : String
  minpoly : Poly
}

///|
/// Construct an algebraic-extension specification tuple.
///
/// - Does: Packages extension metadata into `AlgExtSpec`.
/// - Input: One base `Domain`, one generator name, and one defining `Poly`.
/// - Returns: An `AlgExtSpec`.
/// - Limits: Validation is deferred to `normalize_alg_ext_spec`.
pub fn alg_ext_spec(base : Domain, gen : String, minpoly : Poly) -> AlgExtSpec {
  { base, gen, minpoly }
}

///|
/// Validate and normalize an extension specification.
///
/// - Does: Checks generator/domain compatibility and normalizes the defining
///   polynomial to a monic representative when the domain supports it.
/// - Input: One `AlgExtSpec`.
/// - Returns: An `AlgExtSpec`.
/// - Limits: Raises `PolyError` when the polynomial is malformed for the given
///   base domain or cannot be normalized.
pub fn normalize_alg_ext_spec(spec : AlgExtSpec) -> AlgExtSpec raise PolyError {
  validate_minpoly(spec)
}

///|
/// Build a domain-level algebraic extension.
///
/// - Does: Converts a normalized extension specification into
///   `Domain::AlgExt`.
/// - Input: One `AlgExtSpec`.
/// - Returns: A `Domain`.
/// - Limits: This front door validates again through
///   `normalize_alg_ext_spec` before constructing the result.
pub fn build_alg_extension(spec : AlgExtSpec) -> Domain raise PolyError {
  let normalized = normalize_alg_ext_spec(spec)
  AlgExt(normalized.base, [normalized.gen], [normalized.minpoly.to_expr()])
}

///|
fn validate_minpoly(spec : AlgExtSpec) -> AlgExtSpec raise PolyError {
  // Ensure univariate in the requested generator and over the base domain.
  if spec.minpoly.gens.length() != 1 || spec.minpoly.gens[0] != spec.gen {
    raise BadGenerator(spec.gen)
  }
  if Eq::not_equal(spec.minpoly.domain, spec.base) {
    raise DomainMismatch
  }
  if spec.minpoly.is_zero() || spec.minpoly.degree(0) == 0 {
    raise BadExponent
  }
  let monic = make_monic_if_field(spec.minpoly)
  { base: spec.base, gen: spec.gen, minpoly: monic }
}

///|
fn make_monic_if_field(poly : Poly) -> Poly raise PolyError {
  match poly.leading_term() {
    None => raise NonPolynomial
    Some((_, lc)) =>
      if fe_is_one(lc) {
        poly
      } else {
        match poly.domain {
          QQ | GF(_) | GFExt(_, _, _) => {
            let inv = fe_inv(lc)
            poly.scale_coeff(inv)
          }
          // For integer or algebraic bases we require an already monic polynomial.
          _ => raise DomainNotField
        }
      }
  }
}

///|
test "normalize algebraic extension spec to monic" {
  let builder = PolyBuilder::new(["x"], QQ)
  let x = Expr::Symbol("x")
  let raw = builder.from_expr(int(2) * (x ^ int(2)) + int(1))
  let spec = alg_ext_spec(QQ, "x", raw)
  let normalized = normalize_alg_ext_spec(spec)
  match build_alg_extension(normalized) {
    AlgExt(_, gens, rels) => {
      debug_inspect(gens, content="[\"x\"]")
      // Leading coefficient should be 1 after normalization.
      inspect(@symprint.pretty_string(rels[0]), content="x**2 + 1/2")
    }
    _ => fail("expected AlgExt domain")
  }
}
