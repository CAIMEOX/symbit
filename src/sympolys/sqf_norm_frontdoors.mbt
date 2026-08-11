///|
/// Square-free norm front door for algebraic extensions.
///
/// Current Limits:
/// - Implements the univariate Trager/SymPy path over `Domain::AlgExt`.
/// - Multivariate shift vectors are not implemented yet.

///|
fn sqf_norm_is_squarefree(poly : Poly) -> Bool {
  let parts = poly.sqf_list() catch { _ => return false }
  for item in parts.1 {
    if item.1 != 1 {
      return false
    }
  }
  true
}

///|
fn sqf_norm_shift(
  poly : Poly,
  shift : Int,
  alpha : String,
) -> Poly raise PolyError {
  if poly.gens.length() != 1 {
    raise NotUnivariate
  }
  let (base, gens, rels) = match poly.domain {
    AlgExt(base, gens, rels) => (base, gens, rels)
    _ => raise DomainMismatch
  }
  let (minpoly, loaded_alpha) = load_algext_minpoly(base, gens, rels)
  if loaded_alpha != alpha {
    raise BadGenerator(alpha)
  }
  let shift_elem = FieldElem::AlgExt(
    base,
    [fe_from_int(0, base), fe_from_int(-shift, base)],
    minpoly,
    alpha,
  )
  let coeffs : Map[Monomial, FieldElem] = Map([])
  for mono, coeff0 in poly.coeffs {
    let exp = mono.exps[0]
    let coeff = sqf_norm_lift_coeff(coeff0, poly.domain)
    for j in 0..<=exp {
      let binom = fe_from_int(int_binomial(exp, j), poly.domain)
      let shift_pow = fe_pow(shift_elem, exp - j)
      let term_coeff = fe_mul(fe_mul(coeff, binom), shift_pow)
      let term_mono = monomial_one(1)
      term_mono.exps.set(0, j)
      add_term(coeffs, term_mono, term_coeff, poly.domain)
    }
  }
  { coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
fn sqf_norm_lift_coeff(
  coeff : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  match (domain, coeff) {
    (AlgExt(_, _, _), AlgExt(_, _, _, _)) => coeff
    (AlgExt(_, _, _), QQ(value)) => fe_from_rational(value, domain)
    _ => coeff
  }
}

///|
/// Compute a square-free norm over a simple algebraic extension.
///
/// - Does: Finds an integer shift `s` so that `norm(f(x - s*a))` is
///   square-free over the base domain.
/// - Input: A univariate `Poly` over `Domain::AlgExt`.
/// - Returns: `([s], shifted_poly, norm_poly)`.
/// - Limits: Searches shifts from `0` through `max_shift`; raises
///   `PolyError::BadExponent` if no square-free norm is found in that range.
pub fn sqf_norm(
  poly : Poly,
  max_shift? : Int = 16,
) -> (Array[Int], Poly, Poly) raise PolyError {
  if poly.gens.length() != 1 {
    raise NotUnivariate
  }
  let (base, gens, rels) = match poly.domain {
    AlgExt(base, gens, rels) => (base, gens, rels)
    _ => raise DomainMismatch
  }
  if gens.length() != 1 {
    raise DomainMismatch
  }
  let (minpoly, _) = load_algext_minpoly(base, gens, rels)
  for shift in 0..<=max_shift {
    let shifted = sqf_norm_shift(poly, shift, gens[0])
    let norm = algext_norm(shifted, base, minpoly)
    if sqf_norm_is_squarefree(norm) {
      return ([shift], shifted, norm)
    }
  }
  raise BadExponent
}
