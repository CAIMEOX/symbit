///|
/// Subresultant and resultant helpers over `QQ` and `ZZ`.
///
/// Current Limits:
/// - These helpers are restricted to univariate inputs.
/// - Domains outside `QQ` and `ZZ` are rejected at the front door.

///|
/// Compute a scalar resultant.
///
/// - Does: Returns the scalar resultant of two compatible univariate
///   polynomials.
/// - Input: Two univariate `Poly` values over `QQ` or `ZZ`.
/// - Returns: An exact `@symnum.BigRational`.
/// - Limits: Raises `PolyError` for non-univariate or incompatible input.
fn ensure_univar_pair(a : Poly, b : Poly) -> Unit raise PolyError {
  if a.gens.length() != 1 || b.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
fn lift_pair_to_qq(p : Poly, q : Poly) -> (Poly, Poly) raise PolyError {
  ensure_univar_pair(p, q)
  if p.domain.not_equal(q.domain) || p.gens.not_equal(q.gens) {
    raise PolyError::DomainMismatch
  }
  match p.domain {
    Domain::QQ => (p, q)
    Domain::ZZ => (lift_to_qq(p), lift_to_qq(q))
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Compute a scalar resultant over `QQ` or `ZZ`.
///
/// - Does: Delegates to `Poly::resultant` after validating the input pair.
/// - Input: Two univariate `Poly` values.
/// - Returns: An exact `@symnum.BigRational`.
/// - Limits: Raises `PolyError` outside the supported univariate `QQ/ZZ` path.
pub fn res(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  ensure_univar_pair(p, q)
  p.resultant(q, 0)
}

///|
/// Compute a scalar resultant specialized for `QQ`.
///
/// - Does: Provides a `QQ`-named wrapper around `res`.
/// - Input: Two univariate `Poly` values.
/// - Returns: An exact `@symnum.BigRational`.
/// - Limits: Inherits the same front-door errors as `res`.
pub fn res_q(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  res(p, q)
}

///|
/// Compute a scalar resultant specialized for `ZZ`.
///
/// - Does: Provides a `ZZ`-named wrapper around `res`.
/// - Input: Two univariate `Poly` values.
/// - Returns: An exact `@symnum.BigRational`.
/// - Limits: Inherits the same front-door errors as `res`.
pub fn res_z(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  res(p, q)
}

///|
/// Return the subresultant remainder sequence.
///
/// - Does: Returns the polynomial remainder sequence used by the subresultant
///   path.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Inherits the same compatibility limits as `res`.
pub fn subresultants_rem(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants(p, q)
}

///|
/// Build the Euclidean PRS over `QQ`.
///
/// - Does: Returns the Euclidean polynomial remainder sequence after lifting
///   `ZZ` input to `QQ`.
/// - Input: Two univariate `Poly` values over `QQ` or `ZZ`.
/// - Returns: `Array[Poly]`.
/// - Limits: Raises `PolyError` outside the supported univariate `QQ/ZZ` path.
pub fn euclid_q(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  let (a0, b0) = lift_pair_to_qq(p, q)
  let seq : Array[Poly] = Array::new()
  seq.push(a0)
  seq.push(b0)
  let mut a = a0
  let mut b = b0
  while !b.is_zero() {
    let (_, r) = divmod_univar_rat(a, b)
    if r.is_zero() {
      break
    }
    seq.push(r)
    a = b
    b = r
  }
  seq
}

///|
/// Build the Sturmian PRS over `QQ`.
///
/// - Does: Returns the signed polynomial remainder sequence used for Sturm
///   methods.
/// - Input: Two univariate `Poly` values over `QQ` or `ZZ`.
/// - Returns: `Array[Poly]`.
/// - Limits: Raises `PolyError` outside the supported univariate `QQ/ZZ` path.
pub fn sturm_q(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  let (a0, b0) = lift_pair_to_qq(p, q)
  let seq : Array[Poly] = Array::new()
  seq.push(a0)
  seq.push(b0)
  let mut a = a0
  let mut b = b0
  while !b.is_zero() {
    let (_, r) = divmod_univar_rat(a, b)
    if r.is_zero() {
      break
    }
    let neg_r = r.scale_coeff(fe_from_int(-1, Domain::QQ))
    seq.push(neg_r)
    a = b
    b = neg_r
  }
  seq
}

///|
/// Return the remainder in `ZZ[x]`.
///
/// - Does: Computes the univariate polynomial remainder.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: Inherits the same front-door errors as `Poly::divmod_univar`.
pub fn rem_z(p : Poly, q : Poly) -> Poly raise PolyError {
  ensure_univar_pair(p, q)
  let (_, r) = p.divmod_univar(q)
  r
}

///|
/// Return the quotient in `ZZ[x]`.
///
/// - Does: Computes the univariate polynomial quotient.
/// - Input: Two compatible univariate `Poly` values.
/// - Returns: A `Poly`.
/// - Limits: Inherits the same front-door errors as `Poly::divmod_univar`.
pub fn quo_z(p : Poly, q : Poly) -> Poly raise PolyError {
  ensure_univar_pair(p, q)
  let (quo, _) = p.divmod_univar(q)
  quo
}

///|
/// Pell-Gordon compatibility alias for the Euclidean PRS.
///
/// - Does: Exposes `euclid_q` under the compatibility name expected by older
///   callers.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Inherits the same front-door errors as `euclid_q`.
pub fn subresultants_pg(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  euclid_q(p, q)
}

///|
/// Pell-Gordon compatibility alias for the Sturmian PRS.
///
/// - Does: Exposes `sturm_q` under the compatibility name expected by older
///   callers.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Inherits the same front-door errors as `sturm_q`.
pub fn modified_subresultants_pg(
  p : Poly,
  q : Poly,
) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}
