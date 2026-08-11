///|
/// High-level matrix compatibility wrappers used by `sympolys`.
///
/// Current Limits:
/// - these functions are thin wrappers over the current matrix/domain-matrix
///   surface.
/// - they preserve compatibility spelling, not a separate matrix subsystem.

///|
/// Public expression-level eigenvector tuple shape.
///
/// - Does: Represents one eigenvalue, its multiplicity, and the corresponding
///   expression-level eigenvector matrix.
/// - Input: Built by `dom_eigenvects_to_sympy`.
/// - Returns: A `SympyEigenvects` item.
/// - Limits: This is a compatibility result shape only.
pub type SympyEigenvects = Array[(Expr, Int, MatrixExpr)]

///|
/// Functional wrapper for dense LLL reduction.
///
/// - Does: Runs LLL on a dense domain matrix with the standard default `delta`.
/// - Input: A `DDM` and optional Lovasz parameter.
/// - Returns: A reduced `DDM`.
/// - Limits: Raises `PolyError` when the matrix domain is unsupported.
pub fn ddm_lll(x : DDM, delta? : @symnum.BigRational) -> DDM raise PolyError {
  x.lll(
    delta=match delta {
      Some(value) => value
      None => poly_rational_from_ints(3, 4)
    },
  )
}

///|
/// Functional wrapper for dense LLL reduction with transform.
///
/// - Does: Runs LLL and returns both the reduced basis and transform matrix.
/// - Input: A `DDM` and optional Lovasz parameter.
/// - Returns: `(DDM, DDM)`.
/// - Limits: Raises `PolyError` when the matrix domain is unsupported.
pub fn ddm_lll_transform(
  x : DDM,
  delta? : @symnum.BigRational,
) -> (DDM, DDM) raise PolyError {
  x.lll_transform(
    delta=match delta {
      Some(value) => value
      None => poly_rational_from_ints(3, 4)
    },
  )
}

///|
/// Compute domain-matrix eigenvectors.
///
/// - Does: Returns rational and algebraic eigenvector data in the domain-matrix
///   compatibility format.
/// - Input: A `DomainMatrix` and optional eigenvalue generator name.
/// - Returns: `(DomainMatrixRationalEigenvects, DomainMatrixAlgebraicEigenvects)`.
/// - Limits: Raises `PolyError` when the eigenvector path cannot proceed.
pub fn dom_eigenvects(
  a : DomainMatrix,
  l? : String = "lambda",
) -> (DomainMatrixRationalEigenvects, DomainMatrixAlgebraicEigenvects) raise PolyError {
  a.dom_eigenvects(gen=l)
}

///|
/// Convert domain-matrix eigenvector data into expression matrices.
///
/// - Does: Rebuilds public expression-level eigenvector tuples from the domain
///   matrix representation.
/// - Input: Rational and algebraic eigenvector batches.
/// - Returns: `SympyEigenvects`.
/// - Limits: Raises `PolyError` when one entry cannot be converted back to the
///   expression layer.
pub fn dom_eigenvects_to_sympy(
  rational_eigenvects : DomainMatrixRationalEigenvects,
  algebraic_eigenvects : DomainMatrixAlgebraicEigenvects,
) -> SympyEigenvects raise PolyError {
  let result : SympyEigenvects = Array::new()
  for item in rational_eigenvects {
    result.push((fe_to_expr_const(item.1), item.2, item.3.to_Matrix()))
  }
  for item in algebraic_eigenvects {
    let gen = if item.1.gens.is_empty() { "lambda" } else { item.1.gens[0] }
    result.push((Expr::Symbol(gen), item.2, item.3.to_Matrix()))
  }
  result
}

///|
/// Factor a dense univariate polynomial coefficient vector.
///
/// - Does: Converts the dense coefficient vector into a `Poly`, factors it, and
///   converts the result back to dense factors.
/// - Input: Dense coefficients and a `Domain`.
/// - Returns: `(content, factors)`.
/// - Limits: Raises `PolyError` when the dense vector cannot be interpreted as
///   the expected univariate polynomial.
pub fn dup_factor_list(
  f : Array[FieldElem],
  domain : Domain,
) -> (FieldElem, Array[(Array[FieldElem], Int)]) raise PolyError {
  let poly = poly_from_dense_desc(f, "x", domain)
  let (content_q, factors) = poly.factor_list()
  let dense_factors : Array[(Array[FieldElem], Int)] = Array::new()
  for factor in factors {
    dense_factors.push((poly_to_dense_desc(factor.0), factor.1))
  }
  (fe_from_rational(content_q, domain), dense_factors)
}

///|
/// Compute Hermite normal form through the matrix-module wrapper.
///
/// - Does: Returns the Hermite normal form while preserving the outer
///   `DomainMatrix` representation.
/// - Input: A `DomainMatrix` and optional compatibility-only flags.
/// - Returns: A `DomainMatrix`.
/// - Limits: Raises `PolyError` when the underlying normal-form path fails.
pub fn hermite_normal_form(
  a : DomainMatrix,
  d? : FieldElem? = None,
  check_rank? : Bool = false,
) -> DomainMatrix raise PolyError {
  let _ = d
  let _ = check_rank
  restore_rep_like(a.to_ddm().hermite_normal_form().to_domain_matrix(), a)
}

///|
/// Return invariant factors through the matrix-module wrapper.
///
/// - Does: Forwards to the invariant-factor front door on `DomainMatrix`.
/// - Input: A `DomainMatrix`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: Raises `PolyError` when the underlying normal-form path fails.
pub fn invariant_factors(a : DomainMatrix) -> Array[FieldElem] raise PolyError {
  a.invariant_factors()
}

///|
/// Compute Smith normal form through the matrix-module wrapper.
///
/// - Does: Forwards to the Smith normal-form front door on `DomainMatrix`.
/// - Input: A `DomainMatrix`.
/// - Returns: A `DomainMatrix`.
/// - Limits: Raises `PolyError` when the underlying normal-form path fails.
pub fn smith_normal_form(a : DomainMatrix) -> DomainMatrix raise PolyError {
  a.smith_normal_form()
}

///|
/// Check Smith normal form through the matrix-module wrapper.
///
/// - Does: Forwards to the Smith-normal-form predicate on `DomainMatrix`.
/// - Input: A `DomainMatrix`.
/// - Returns: A `Bool`.
/// - Limits: Raises `PolyError` when the underlying predicate path fails.
pub fn is_smith_normal_form(a : DomainMatrix) -> Bool raise PolyError {
  a.is_smith_normal_form()
}

///|
/// Compute Smith normal form and transforms through the wrapper.
///
/// - Does: Forwards to the Smith-normal decomposition front door on
///   `DomainMatrix`.
/// - Input: A `DomainMatrix`.
/// - Returns: `(DomainMatrix, DomainMatrix, DomainMatrix)`.
/// - Limits: Raises `PolyError` when the underlying decomposition path fails.
pub fn smith_normal_decomp(
  a : DomainMatrix,
) -> (DomainMatrix, DomainMatrix, DomainMatrix) raise PolyError {
  a.smith_normal_decomp()
}

///|
/// Apply one column operation used by the normal-form algorithms.
///
/// - Does: Replaces columns `i` and `j` by the linear combinations encoded by
///   `(a, b, c, d)`.
/// - Input: A `DDM`, two column indices, and four scalar coefficients.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the indices are invalid or coefficients do
///   not belong to the matrix domain.
pub fn add_columns(
  m : DDM,
  i : Int,
  j : Int,
  a : FieldElem,
  b : FieldElem,
  c : FieldElem,
  d : FieldElem,
) -> DDM raise PolyError {
  let rows = m.to_list()
  if rows.is_empty() {
    return m.copy()
  }
  let cols = rows[0].length()
  let left = normalize_matrix_index(i, cols)
  let right = normalize_matrix_index(j, cols)
  let out = clone_dense_rows(rows)
  for k in 0..<out.length() {
    let value = out[k][left]
    let other = out[k][right]
    out[k].set(left, fe_add(fe_mul(a, value), fe_mul(b, other)))
    out[k].set(right, fe_add(fe_mul(c, value), fe_mul(d, other)))
  }
  ddm_from_dense(out, m.domain())
}

///|
/// Return the balanced modular representative.
///
/// - Does: Maps `a mod m` into the symmetric residue interval around zero.
/// - Input: Two `BigInt` values.
/// - Returns: A `BigInt`.
/// - Limits: This assumes the usual nonzero-modulus HNF calling convention.
pub fn symmetric_residue(a : BigInt, m : BigInt) -> BigInt {
  let reduced = a.mod(m)
  let half = m.div(BigInt::from_int(2))
  if reduced > half {
    reduced.sub(m)
  } else {
    reduced
  }
}
