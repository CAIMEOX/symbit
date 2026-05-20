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
fn field_elem_sign(c : FieldElem) -> Int {
  if fe_is_positive(c) {
    1
  } else if fe_is_negative(c) {
    -1
  } else {
    0
  }
}

///|
fn normalized_q_prs_inputs(
  p : Poly,
  q : Poly,
) -> (Poly, Poly, Bool) raise PolyError {
  let (a0, b0) = lift_pair_to_qq(p, q)
  let mut a = a0
  let mut b = b0
  if degree(b) > degree(a) {
    let tmp = a
    a = b
    b = tmp
  }
  let mut flipped = false
  if field_elem_sign(a.lc()) < 0 {
    a = a.neg()
    b = b.neg()
    flipped = true
  }
  (a, b, flipped)
}

///|
fn maybe_flip_prs(seq : Array[Poly], flipped : Bool) -> Array[Poly] {
  if !flipped {
    return seq
  }
  seq.map(p => p.neg())
}

///|
/// Return signs of leading coefficients in a polynomial sequence.
///
/// - Does: Mirrors SymPy `sign_seq` by applying `sign(LC(poly))` to every
///   polynomial in the sequence.
/// - Input: An array of univariate `Poly` values.
/// - Returns: `Array[Int]` containing `-1`, `0`, or `1`.
/// - Limits: Raises `PolyError` when a leading coefficient cannot be formed in
///   the stored domain.
pub fn sign_seq(poly_seq : Array[Poly]) -> Array[Int] raise PolyError {
  poly_seq.map(poly => field_elem_sign(poly.lc()))
}

///|
/// Filter a matrix-derived polynomial remainder sequence.
///
/// - Does: Removes zero polynomials and later entries whose degree repeats the
///   previous retained degree, matching SymPy's `process_matrix_output` helper.
/// - Input: A polynomial remainder sequence with at least the input pair.
/// - Returns: A filtered `Array[Poly]`.
/// - Limits: Empty and singleton inputs are returned unchanged.
pub fn process_matrix_output(poly_seq : Array[Poly]) -> Array[Poly] {
  if poly_seq.length() < 2 {
    return poly_seq.copy()
  }
  let out : Array[Poly] = [poly_seq[0], poly_seq[1]]
  let mut previous_degree = degree(poly_seq[1])
  for i in 2..<poly_seq.length() {
    let current_degree = degree(poly_seq[i])
    if current_degree < 0 || current_degree == previous_degree {
      continue
    }
    out.push(poly_seq[i])
    previous_degree = current_degree
  }
  out
}

///|
/// Compute the sign of an integer power without evaluating the power.
///
/// - Does: Returns `sign(base ** expo)` using only signs and parity.
/// - Input: Integer `base` and non-negative integer `expo`.
/// - Returns: `-1`, `0`, or `1`.
/// - Limits: Negative exponents are outside the SymPy helper contract and raise
///   `PolyError::BadExponent`.
pub fn compute_sign(base : Int, expo : Int) -> Int raise PolyError {
  if expo < 0 {
    raise PolyError::BadExponent
  }
  if base > 0 {
    1
  } else if base == 0 {
    0
  } else if expo % 2 == 0 {
    1
  } else {
    -1
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
  let (a0, b0, flipped) = normalized_q_prs_inputs(p, q)
  let seq : Array[Poly] = Array::new()
  seq.push(a0)
  seq.push(b0)
  if a0.is_zero() ||
    b0.is_zero() ||
    (degree(a0) == 0 && degree(b0) == 0) ||
    (degree(a0) > 0 && degree(b0) == 0) {
    return maybe_flip_prs(seq, flipped)
  }
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
  maybe_flip_prs(seq, flipped)
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
  let (a0, b0, flipped) = normalized_q_prs_inputs(p, q)
  let seq : Array[Poly] = Array::new()
  seq.push(a0)
  seq.push(b0)
  if a0.is_zero() ||
    b0.is_zero() ||
    (degree(a0) == 0 && degree(b0) == 0) ||
    (degree(a0) > 0 && degree(b0) == 0) {
    return maybe_flip_prs(seq, flipped)
  }
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
  maybe_flip_prs(seq, flipped)
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
