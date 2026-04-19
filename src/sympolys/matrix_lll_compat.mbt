///|
/// Convert integer-matrix `DDM` values into the existing LLL kernel.
fn ddm_to_bigint_rows(ddm : DDM) -> Array[Array[BigInt]] raise PolyError {
  let rows = ddm.to_list()
  let out : Array[Array[BigInt]] = Array::new()
  for row in rows {
    let out_row : Array[BigInt] = Array::new()
    for v in row {
      let q = fe_expect_rational(v)
      if !q.denominator().equal_int(1) {
        raise PolyError::DomainMismatch
      }
      out_row.push(q.numerator())
    }
    out.push(out_row)
  }
  out
}

///|
fn bigint_rows_to_ddm(rows : Array[Array[BigInt]]) -> DDM raise PolyError {
  let out : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    let out_row : Array[FieldElem] = Array::new()
    for v in row {
      out_row.push(
        fe_from_rational(@symnum.BigRational::from_bigint(v), Domain::ZZ),
      )
    }
    out.push(out_row)
  }
  ddm_from_dense(out, Domain::ZZ)
}

///|
fn require_zz(ddm : DDM) -> Unit raise PolyError {
  match ddm.domain() {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// SymPy-style LLL reduction on integer domain matrices.

///|
/// Public API `DDM.lll`.
///
/// - Does: Provides the `DDM.lll` operation for matrix LLL compatibility.
/// - Input: parameters `self : DDM`, `delta : @symnum.BigRational`, using the package
/// representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::lll(
  self : DDM,
  delta? : @symnum.BigRational,
) -> DDM raise PolyError {
  require_zz(self)
  let basis = ddm_to_bigint_rows(self)
  let (reduced, _) = match delta {
    Some(d) => lll_reduce(basis, delta=d)
    None => lll_reduce(basis)
  }
  bigint_rows_to_ddm(reduced)
}

///|
/// Return both the reduced basis and transform matrix (`B = T * A`) for LLL.

///|
/// Public API `DDM.lll_transform`.
///
/// - Does: Provides the `DDM.lll_transform` operation for matrix LLL compatibility.
/// - Input: parameters `self : DDM`, `delta : @symnum.BigRational`, `) -> (DDM`, `DDM`,
/// using the package representation expected by the signature.
/// - Returns: a `(DDM, DDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::lll_transform(
  self : DDM,
  delta? : @symnum.BigRational,
) -> (DDM, DDM) raise PolyError {
  require_zz(self)
  let basis = ddm_to_bigint_rows(self)
  let (reduced, transform) = match delta {
    Some(d) => lll_reduce(basis, delta=d)
    None => lll_reduce(basis)
  }
  (bigint_rows_to_ddm(reduced), bigint_rows_to_ddm(transform))
}
