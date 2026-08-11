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
  if p.domain.not_equal(q.domain) || p.gens != q.gens {
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

///|
/// Euclidean PRS variant from the Pell-Gordon family.
///
/// - Does: Exposes SymPy's `euclid_pg` public front door through the current
///   Euclidean PRS implementation.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: The specialized Pell-Gordon coefficient path is not separated
///   from the package PRS path.
pub fn euclid_pg(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  euclid_q(p, q)
}

///|
/// Euclidean PRS variant from the Akritas-Malaz-Amiraslani family.
///
/// - Does: Exposes SymPy's `euclid_amv` public front door through the current
///   Euclidean PRS implementation.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: The AMV-specific matrix variant is not separated from the package
///   PRS path.
pub fn euclid_amv(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  euclid_q(p, q)
}

///|
/// Sturmian PRS variant from the Pell-Gordon family.
///
/// - Does: Exposes SymPy's `sturm_pg` public front door through the current
///   Sturmian PRS implementation.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: The specialized Pell-Gordon coefficient path is not separated
///   from the package PRS path.
pub fn sturm_pg(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}

///|
/// Sturmian PRS variant from the Akritas-Malaz-Amiraslani family.
///
/// - Does: Exposes SymPy's `sturm_amv` public front door through the current
///   Sturmian PRS implementation.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: The AMV-specific matrix variant is not separated from the package
///   PRS path.
pub fn sturm_amv(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}

///|
/// Sylvester-matrix subresultant sequence front door.
///
/// - Does: Returns the package subresultant PRS under SymPy's
///   `subresultants_sylv` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Matrix construction details are shared with the existing PRS
///   implementation.
pub fn subresultants_sylv(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants_rem(p, q)
}

///|
/// Bezout-matrix subresultant sequence front door.
///
/// - Does: Returns the package subresultant PRS under SymPy's
///   `subresultants_bezout` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Matrix construction details are shared with the existing PRS
///   implementation.
pub fn subresultants_bezout(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants_rem(p, q)
}

///|
/// AMV subresultant sequence front door.
///
/// - Does: Returns the package subresultant PRS under SymPy's
///   `subresultants_amv` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: AMV matrix internals are not separately modeled.
pub fn subresultants_amv(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants_rem(p, q)
}

///|
/// AMV subresultant sequence front door over `QQ`.
///
/// - Does: Returns the package subresultant PRS under SymPy's
///   `subresultants_amv_q` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: The current implementation shares the same `QQ/ZZ` normalization
///   path as `subresultants_amv`.
pub fn subresultants_amv_q(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants_rem(p, q)
}

///|
/// Van Vleck subresultant sequence front door.
///
/// - Does: Returns the package subresultant PRS under SymPy's
///   `subresultants_vv` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Van Vleck matrix internals are not separately modeled.
pub fn subresultants_vv(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants_rem(p, q)
}

///|
/// Second Van Vleck subresultant sequence front door.
///
/// - Does: Returns the package subresultant PRS under SymPy's
///   `subresultants_vv_2` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Van Vleck matrix internals are not separately modeled.
pub fn subresultants_vv_2(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants_rem(p, q)
}

///|
/// Modified Sylvester-matrix subresultant sequence front door.
///
/// - Does: Returns the Sturmian PRS under SymPy's
///   `modified_subresultants_sylv` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Matrix construction details are shared with the existing
///   Sturmian PRS path.
pub fn modified_subresultants_sylv(
  p : Poly,
  q : Poly,
) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}

///|
/// Modified Bezout-matrix subresultant sequence front door.
///
/// - Does: Returns the Sturmian PRS under SymPy's
///   `modified_subresultants_bezout` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: Matrix construction details are shared with the existing
///   Sturmian PRS path.
pub fn modified_subresultants_bezout(
  p : Poly,
  q : Poly,
) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}

///|
/// Modified AMV subresultant sequence front door.
///
/// - Does: Returns the Sturmian PRS under SymPy's
///   `modified_subresultants_amv` name.
/// - Input: Two univariate `Poly` values.
/// - Returns: `Array[Poly]`.
/// - Limits: AMV matrix internals are not separately modeled.
pub fn modified_subresultants_amv(
  p : Poly,
  q : Poly,
) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}

///|
/// Rotate a coefficient row to the right.
///
/// - Does: Mirrors SymPy `rotate_r` by moving the last entry to the front
///   `k` times.
/// - Input: A coefficient row and a non-negative rotation count.
/// - Returns: A new rotated row.
/// - Limits: Negative counts leave the row unchanged, matching Python
///   `range(k)` behavior in SymPy's helper.
pub fn rotate_r(row : Array[FieldElem], k : Int) -> Array[FieldElem] {
  let out = row.copy()
  if out.is_empty() || k <= 0 {
    return out
  }
  for _ in 0..<k {
    match out.pop() {
      Some(last) => out.insert(0, last)
      None => ()
    }
  }
  out
}

///|
/// Rotate a coefficient row to the left using SymPy's helper semantics.
///
/// - Does: Mirrors SymPy `rotate_l` by removing the first entry and inserting
///   it just before the last current entry, repeated `k` times.
/// - Input: A coefficient row and a non-negative rotation count.
/// - Returns: A new rotated row.
/// - Limits: This intentionally follows SymPy's historical helper, which is
///   not a standard cyclic left rotation.
pub fn rotate_l(row : Array[FieldElem], k : Int) -> Array[FieldElem] {
  let out = row.copy()
  if out.is_empty() || k <= 0 {
    return out
  }
  for _ in 0..<k {
    let first = out[0]
    ignore(out.remove(0))
    let insert_at = if out.is_empty() { 0 } else { out.length() - 1 }
    out.insert(insert_at, first)
  }
  out
}

///|
/// Triangularize entries below a pivot in a subresultant helper matrix.
///
/// - Does: Mirrors SymPy `pivot(M, i, j)` by clearing column `j` below row
///   `i` and updating the trailing entries with cross products.
/// - Input: A `DomainMatrix` and a valid pivot position.
/// - Returns: A new `DomainMatrix`.
/// - Limits: Invalid indices raise `PolyError::DomainMismatch`.
pub fn pivot(
  matrix : DomainMatrix,
  i : Int,
  j : Int,
) -> DomainMatrix raise PolyError {
  if i < 0 || j < 0 || i >= matrix.rows || j >= matrix.cols {
    raise PolyError::DomainMismatch
  }
  let ma = clone_dense_rows(matrix.to_list())
  let pivot_val = ma[i][j]
  let zero = subres_matrix_zero(matrix.domain)
  for r in (i + 1)..<matrix.rows {
    let row_val = ma[r][j]
    if fe_is_zero(row_val) {
      continue
    }
    for c in (j + 1)..<matrix.cols {
      let left = fe_mul(pivot_val, ma[r][c])
      let right = fe_mul(ma[i][c], row_val)
      ma[r].set(c, fe_sub(left, right))
    }
    ma[r].set(j, zero)
  }
  DomainMatrix::from_list(ma, matrix.domain)
}

///|
/// Convert a matrix row slice into a univariate polynomial.
///
/// - Does: Mirrors SymPy `row2poly` by dropping leading zero entries and
///   reading the next `deg + 1` coefficients as descending powers.
/// - Input: A coefficient row, target degree, generator name, and coefficient
///   domain.
/// - Returns: A univariate `Poly`.
/// - Limits: Negative degrees raise `PolyError::BadExponent`; all-zero rows
///   raise `PolyError::NonPolynomial`.
pub fn row2poly(
  row : Array[FieldElem],
  deg : Int,
  gen? : String = "x",
  domain? : Domain = Domain::ZZ,
) -> Poly raise PolyError {
  if deg < 0 {
    raise PolyError::BadExponent
  }
  let mut start = 0
  while start < row.length() && fe_is_zero(row[start]) {
    start = start + 1
  }
  if start >= row.length() {
    raise PolyError::NonPolynomial
  }
  let coeffs : Array[FieldElem] = []
  let zero = subres_matrix_zero(domain)
  for offset in 0..<=deg {
    let idx = start + offset
    if idx < row.length() {
      coeffs.push(row[idx])
    } else {
      coeffs.push(zero)
    }
  }
  poly_from_dense_desc(coeffs, gen, domain)
}

///|
/// Find the degree represented by the last row of a small matrix.
///
/// - Does: Mirrors SymPy `find_degree` by scanning the last row from left to
///   right and decrementing from `deg_f` for every leading zero.
/// - Input: A `DomainMatrix` and the dividend degree.
/// - Returns: `Some(degree)` or `None` for an all-zero/empty last row.
/// - Limits: Matrix decoding errors propagate as `PolyError`.
pub fn find_degree(matrix : DomainMatrix, deg_f : Int) -> Int? raise PolyError {
  if matrix.rows == 0 {
    return None
  }
  let dense = matrix.to_list()
  let last = dense[matrix.rows - 1]
  let mut degree = deg_f
  for c in 0..<matrix.cols {
    if fe_is_zero(last[c]) {
      degree = degree - 1
    } else if degree < 0 {
      return Some(0)
    } else {
      return Some(degree)
    }
  }
  None
}

///|
/// Fill the trailing rotated rows after a Van Vleck gcd insertion.
///
/// - Does: Mirrors SymPy `final_touches` by copying row `r - 1` into following
///   rows, rotated right by increasing offsets until the last term is aligned.
/// - Input: A `DomainMatrix`, row pointer `r`, and degree of the last inserted
///   polynomial.
/// - Returns: A new `DomainMatrix`.
/// - Limits: Invalid row pointers raise `PolyError::DomainMismatch`; an all-zero
///   source row is returned unchanged.
pub fn final_touches(
  matrix : DomainMatrix,
  r : Int,
  deg_g : Int,
) -> DomainMatrix raise PolyError {
  if r <= 0 || r > matrix.rows {
    raise PolyError::DomainMismatch
  }
  let rows = clone_dense_rows(matrix.to_list())
  let source = rows[r - 1]
  let mut first_nonzero = -1
  for c in 0..<matrix.cols {
    if !fe_is_zero(source[c]) {
      first_nonzero = c
      break
    }
  }
  if first_nonzero < 0 {
    return DomainMatrix::from_list(rows, matrix.domain)
  }
  let mut missing_rows = matrix.cols - (first_nonzero + deg_g + 1)
  let mut offset = 0
  while missing_rows != 0 && r + offset < matrix.rows {
    rows.set(r + offset, rotate_r(source, offset + 1))
    offset = offset + 1
    missing_rows = missing_rows - 1
  }
  DomainMatrix::from_list(rows, matrix.domain)
}
