///|
/// Low-degree Galois group front door.
///
/// Current Limits:
/// - Covers irreducible univariate polynomials over `ZZ/QQ` through degree 3.
/// - Higher-degree transitive subgroup classification is not implemented here.

///|
pub struct GaloisGroupResult {
  name : String
  is_alt : Bool
}

///|
fn galois_is_irreducible(poly : Poly) -> Bool {
  let factors_result : Result[
    (@symnum.BigRational, Array[(Poly, Int)]),
    PolyError,
  ] = try? poly.factor_list()
  match factors_result {
    Err(_) => false
    Ok((_, factors)) =>
      factors.length() == 1 &&
      factors[0].1 == 1 &&
      factors[0].0.degree(0) == poly.degree(0)
  }
}

///|
fn galois_rational_is_square(value : @symnum.BigRational) -> Bool {
  if value.compare(@symnum.BigRational::zero()) < 0 {
    return false
  }
  sqrt_bigint_if_square(value.numerator()) is Some(_) &&
  sqrt_bigint_if_square(value.denominator()) is Some(_)
}

///|
fn galois_discriminant_is_square(poly : Poly) -> Bool raise PolyError {
  match discriminant(poly) {
    FieldElem::QQ(value) => galois_rational_is_square(value)
    _ => false
  }
}

///|
/// Compute the low-degree Galois group name.
///
/// - Does: Classifies irreducible degree `1`, `2`, and `3` polynomials over
///   rational domains using SymPy's low-degree rules.
/// - Input: One univariate `Poly`.
/// - Returns: `GaloisGroupResult` with a transitive subgroup name and the
///   alternating-group flag.
/// - Limits: Reducible inputs and degree `> 3` raise `PolyError`.
pub fn galois_group(poly : Poly) -> GaloisGroupResult raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  match poly.domain {
    Domain::ZZ | Domain::QQ => ()
    _ => raise PolyError::DomainMismatch
  }
  if !galois_is_irreducible(poly) {
    raise PolyError::NonPolynomial
  }
  match poly.degree(0) {
    1 => GaloisGroupResult::{ name: "S1", is_alt: true }
    2 => GaloisGroupResult::{ name: "S2", is_alt: false }
    3 =>
      if galois_discriminant_is_square(poly) {
        GaloisGroupResult::{ name: "A3", is_alt: true }
      } else {
        GaloisGroupResult::{ name: "S3", is_alt: false }
      }
    _ => raise PolyError::BadExponent
  }
}
