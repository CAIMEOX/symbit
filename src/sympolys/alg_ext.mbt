///|
/// Algebraic extension scaffolding: normalize minimal polynomials and
/// produce Domain::AlgExt descriptors. Arithmetic is not wired yet; this
/// stage only checks shape/monicity so later content/primitive logic can
/// rely on a stable spec.
pub struct AlgExtSpec {
  base : Domain
  gen : String
  minpoly : Poly
}

///|
pub fn alg_ext_spec(base : Domain, gen : String, minpoly : Poly) -> AlgExtSpec {
  AlgExtSpec::{ base, gen, minpoly }
}

///|
pub fn normalize_alg_ext_spec(spec : AlgExtSpec) -> AlgExtSpec raise PolyError {
  validate_minpoly(spec)
}

///|
pub fn build_alg_extension(spec : AlgExtSpec) -> Domain raise PolyError {
  let normalized = normalize_alg_ext_spec(spec)
  Domain::AlgExt(normalized.base, [normalized.gen], [
    normalized.minpoly.to_expr(),
  ])
}

///|
fn validate_minpoly(spec : AlgExtSpec) -> AlgExtSpec raise PolyError {
  // Ensure univariate in the requested generator and over the base domain.
  if spec.minpoly.gens.length() != 1 || spec.minpoly.gens[0] != spec.gen {
    raise PolyError::BadGenerator(spec.gen)
  }
  if spec.minpoly.domain.not_equal(spec.base) {
    raise PolyError::DomainMismatch
  }
  if spec.minpoly.is_zero() || spec.minpoly.degree(0) == 0 {
    raise PolyError::BadExponent
  }
  let monic = make_monic_if_field(spec.minpoly)
  AlgExtSpec::{ base: spec.base, gen: spec.gen, minpoly: monic }
}

///|
fn make_monic_if_field(poly : Poly) -> Poly raise PolyError {
  match poly.leading_term() {
    None => raise PolyError::NonPolynomial
    Some((_, lc)) =>
      if fe_is_one(lc) {
        poly
      } else {
        match poly.domain {
          Domain::QQ | Domain::GF(_) | Domain::GFExt(_, _, _) => {
            let inv = fe_inv(lc)
            poly.scale_coeff(inv)
          }
          // For integer or algebraic bases we require an already monic polynomial.
          _ => raise PolyError::DomainNotField
        }
      }
  }
}

///|
test "normalize algebraic extension spec to monic" {
  let builder = PolyBuilder::new(["x"], Domain::QQ)
  let raw = builder.from_expr(
    @symcore.add([
      @symcore.mul([
        @symcore.int(2),
        @symcore.pow(@symcore.symbol("x"), @symcore.int(2)),
      ]),
      @symcore.int(1),
    ]),
  ) catch {
    e => fail("unexpected: \{e.to_string()}")
  }
  let spec = alg_ext_spec(Domain::QQ, "x", raw)
  let normalized = normalize_alg_ext_spec(spec) catch {
    e => fail("unexpected: \{e.to_string()}")
  }
  match build_alg_extension(normalized) {
    Domain::AlgExt(_, gens, rels) => {
      inspect(gens.to_string(), content="[\"x\"]")
      // Leading coefficient should be 1 after normalization.
      inspect(@symprint.to_string(rels[0]), content="1/2 + x**2")
    }
    _ => fail("expected AlgExt domain")
  }
}
