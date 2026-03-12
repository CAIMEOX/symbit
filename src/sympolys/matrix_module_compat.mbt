///|
fn default_lll_delta() -> @symnum.BigRational raise @symnum.RationalError {
  @symnum.BigRational::new(BigInt::from_int(3), BigInt::from_int(4))
}

///|
pub type SympyEigenvects = Array[(@symcore.Expr, Int, MatrixExpr)]

///|
/// Functional wrapper matching SymPy `polys.matrices.lll.ddm_lll`.
pub fn ddm_lll(
  x : DDM,
  delta? : @symnum.BigRational = try! default_lll_delta(),
) -> DDM raise PolyError {
  x.lll(delta~)
}

///|
/// Functional wrapper matching SymPy `polys.matrices.lll.ddm_lll_transform`.
pub fn ddm_lll_transform(
  x : DDM,
  delta? : @symnum.BigRational = try! default_lll_delta(),
) -> (DDM, DDM) raise PolyError {
  x.lll_transform(delta~)
}

///|
/// Wrapper for SymPy `polys.matrices.eigen.dom_eigenvects`.
pub fn dom_eigenvects(
  a : DomainMatrix,
  l? : String = "lambda",
) -> (DomainMatrixRationalEigenvects, DomainMatrixAlgebraicEigenvects) raise PolyError {
  a.dom_eigenvects(gen=l)
}

///|
/// Convert domain-matrix eigenvector data into expression matrices.
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
    result.push((@symcore.symbol(gen), item.2, item.3.to_Matrix()))
  }
  result
}

///|
/// Dense univariate factorization helper used by SymPy's matrix eigen routines.
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
/// Wrapper for SymPy `polys.matrices.normalforms.hermite_normal_form`.
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
/// Wrapper for SymPy `polys.matrices.normalforms.invariant_factors`.
pub fn invariant_factors(a : DomainMatrix) -> Array[FieldElem] raise PolyError {
  a.invariant_factors()
}

///|
/// Wrapper for SymPy `polys.matrices.normalforms.smith_normal_form`.
pub fn smith_normal_form(a : DomainMatrix) -> DomainMatrix raise PolyError {
  a.smith_normal_form()
}

///|
/// Wrapper for SymPy `polys.matrices.normalforms.is_smith_normal_form`.
pub fn is_smith_normal_form(a : DomainMatrix) -> Bool raise PolyError {
  a.is_smith_normal_form()
}

///|
/// Wrapper for SymPy `polys.matrices.normalforms.smith_normal_decomp`.
pub fn smith_normal_decomp(
  a : DomainMatrix,
) -> (DomainMatrix, DomainMatrix, DomainMatrix) raise PolyError {
  a.smith_normal_decomp()
}

///|
/// Pure wrapper for the column operation helper used by SymPy normal forms.
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
/// Re-export the balanced modular representative helper used by SymPy HNF code.
pub fn symmetric_residue(a : BigInt, m : BigInt) -> BigInt {
  let reduced = a.mod(m)
  let half = m.div(BigInt::from_int(2))
  if reduced.op_gt(half) {
    reduced.sub(m)
  } else {
    reduced
  }
}
