///|
fn ddm_pivot_measure(value : FieldElem) -> @symnum.BigRational raise PolyError {
  match value {
    QQ(q) =>
      if q.compare(@symnum.BigRational::zero()) < 0 {
        q.neg_r()
      } else {
        q
      }
    CC(real, imag) => real.mul_r(real).add_r(imag.mul_r(imag))
    _ => fe_abs_rational(value)
  }
}

///|
fn ddm_irref_partial_pivot(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> (Array[Array[FieldElem]], Array[Int]) raise PolyError {
  let m = rows.length()
  if m == 0 {
    return (rows, [])
  }
  let n = rows[0].length()
  let pivots : Array[Int] = Array::new()
  let data = clone_dense_rows(rows)
  let mut i = 0
  for j in 0..<n {
    if i >= m {
      break
    }
    let mut pivot_row = -1
    let mut pivot_measure = @symnum.BigRational::zero()
    for ip in i..<m {
      let value = data[ip][j]
      if fe_is_zero(value) {
        continue
      }
      let measure = ddm_pivot_measure(value)
      if pivot_row == -1 || measure.compare(pivot_measure) > 0 {
        pivot_row = ip
        pivot_measure = measure
      }
    }
    if pivot_row == -1 {
      continue
    }
    if pivot_row != i {
      swap_rows_in_place(data, i, pivot_row)
    }
    let pivot = data[i][j]
    let inv = fe_inv(pivot)
    for k in j..<n {
      data[i].set(k, fe_mul(data[i][k], inv))
    }
    for ip in 0..<m {
      if ip == i || fe_is_zero(data[ip][j]) {
        continue
      }
      let factor = data[ip][j]
      data[ip].set(j, fe_from_int(0, domain))
      for k in (j + 1)..<n {
        data[ip].set(k, fe_sub(data[ip][k], fe_mul(factor, data[i][k])))
      }
    }
    pivots.push(j)
    i += 1
  }
  (data, pivots)
}

///|
fn ddm_bareiss_det_in_place(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> FieldElem raise PolyError {
  let n = rows.length()
  if n == 0 {
    return fe_from_int(1, domain)
  }
  let mut sign = 1
  let mut denom = fe_from_int(1, domain)
  for k in 0..<(n - 1) {
    let mut pivot = k
    while pivot < n && fe_is_zero(rows[pivot][k]) {
      pivot += 1
    }
    if pivot == n {
      return fe_from_int(0, domain)
    }
    if pivot != k {
      swap_rows_in_place(rows, pivot, k)
      sign = -sign
    }
    let akk = rows[k][k]
    for i in (k + 1)..<n {
      for j in (k + 1)..<n {
        let num = fe_sub(
          fe_mul(rows[i][j], akk),
          fe_mul(rows[i][k], rows[k][j]),
        )
        let value = if k == 0 {
          num
        } else {
          fe_exact_div_in_domain(num, denom, domain)
        }
        rows[i].set(j, value)
      }
      rows[i].set(k, fe_from_int(0, domain))
    }
    denom = akk
  }
  let det = rows[n - 1][n - 1]
  if sign < 0 {
    fe_neg(det)
  } else {
    det
  }
}

///|
/// Functional wrapper for SymPy `polys.matrices.dense.ddm_transpose`.

///|
/// Public API `ddm_transpose`.
///
/// - Does: Provides the `ddm_transpose` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_transpose(a : DDM) -> DDM raise PolyError {
  a.transpose()
}

///|
/// Return the updated dense matrix corresponding to SymPy `ddm_iadd`.

///|
/// Public API `ddm_iadd`.
///
/// - Does: Provides the `ddm_iadd` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `b : DDM`, using the package representation expected
/// by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_iadd(a : DDM, b : DDM) -> DDM raise PolyError {
  a.add(b)
}

///|
/// Return the updated dense matrix corresponding to SymPy `ddm_isub`.

///|
/// Public API `ddm_isub`.
///
/// - Does: Provides the `ddm_isub` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `b : DDM`, using the package representation expected
/// by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_isub(a : DDM, b : DDM) -> DDM raise PolyError {
  a.sub(b)
}

///|
/// Return the updated dense matrix corresponding to SymPy `ddm_ineg`.

///|
/// Public API `ddm_ineg`.
///
/// - Does: Provides the `ddm_ineg` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_ineg(a : DDM) -> DDM raise PolyError {
  a.neg()
}

///|
/// Return the updated dense matrix corresponding to SymPy `ddm_imul`.

///|
/// Public API `ddm_imul`.
///
/// - Does: Provides the `ddm_imul` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `b : FieldElem`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_imul(a : DDM, b : FieldElem) -> DDM raise PolyError {
  a.mul(b)
}

///|
/// Return the updated dense matrix corresponding to SymPy `ddm_irmul`.

///|
/// Public API `ddm_irmul`.
///
/// - Does: Provides the `ddm_irmul` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `b : FieldElem`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_irmul(a : DDM, b : FieldElem) -> DDM raise PolyError {
  a.rmul(b)
}

///|
/// Return the updated dense matrix corresponding to SymPy `ddm_imatmul`.

///|
/// Public API `ddm_imatmul`.
///
/// - Does: Provides the `ddm_imatmul` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `b : DDM`, `c : DDM`, using the package
/// representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_imatmul(a : DDM, b : DDM, c : DDM) -> DDM raise PolyError {
  a.add(b.matmul(c))
}

///|
/// Functional wrapper for SymPy `polys.matrices.dense.ddm_irref`.

///|
/// Public API `ddm_irref`.
///
/// - Does: Provides the `ddm_irref` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `partial_pivot : Bool = false`, `) -> (DDM`,
/// `Array[Int]`, using the package representation expected by the signature.
/// - Returns: a `(DDM, Array[Int])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_irref(
  a : DDM,
  partial_pivot? : Bool = false,
) -> (DDM, Array[Int]) raise PolyError {
  if !partial_pivot {
    return a.rref()
  }
  if !domain_is_field_pred(a.domain()) {
    raise DomainNotField
  }
  let (rows, pivots) = ddm_irref_partial_pivot(a.to_list(), a.domain())
  (ddm_from_dense(rows, a.domain()), pivots)
}

///|
/// Functional wrapper for SymPy `polys.matrices.dense.ddm_irref_den`.

///|
/// Public API `ddm_irref_den`.
///
/// - Does: Provides the `ddm_irref_den` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, `keep_domain : Bool = true`, `) -> (DDM`,
/// `FieldElem`, `Array[Int]`, using the package representation expected by the
/// signature.
/// - Returns: a `(DDM, FieldElem, Array[Int])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_irref_den(
  a : DDM,
  keep_domain? : Bool = true,
) -> (DDM, FieldElem, Array[Int]) raise PolyError {
  a.rref_den(keep_domain~)
}

///|
/// Return the packed LU matrix and row swaps corresponding to SymPy `ddm_ilu`.

///|
/// Public API `ddm_ilu`.
///
/// - Does: Provides the `ddm_ilu` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM) -> (DDM`, `Array[(Int, Int)]`, using the package
/// representation expected by the signature.
/// - Returns: a `(DDM, Array[(Int, Int)])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_ilu(a : DDM) -> (DDM, Array[(Int, Int)]) raise PolyError {
  let rows = clone_dense_rows(a.to_list())
  let swaps = dense_lu_in_place(rows, a.domain())
  (ddm_from_dense(rows, a.domain()), swaps)
}

///|
/// Return split `L`, `U`, and row swaps corresponding to SymPy `ddm_ilu_split`.

///|
/// Public API `ddm_ilu_split`.
///
/// - Does: Provides the `ddm_ilu_split` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM) -> (DDM`, `DDM`, `Array[(Int, Int)]`, using the
/// package representation expected by the signature.
/// - Returns: a `(DDM, DDM, Array[(Int, Int)])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_ilu_split(a : DDM) -> (DDM, DDM, Array[(Int, Int)]) raise PolyError {
  let (l, u, swaps) = dense_lu_split(a.to_list(), a.domain())
  (ddm_from_dense(l, a.domain()), ddm_from_dense(u, a.domain()), swaps)
}

///|
/// Solve `L * U * x = P * b` from an LU factorization as in SymPy `ddm_ilu_solve`.

///|
/// Public API `ddm_ilu_solve`.
///
/// - Does: Provides the `ddm_ilu_solve` operation for dense domain-matrix algorithms.
/// - Input: parameters `l : DDM`, `u : DDM`, `swaps : Array[(Int, Int)]`, `b : DDM`,
/// using the package representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_ilu_solve(
  l : DDM,
  u : DDM,
  swaps : Array[(Int, Int)],
  b : DDM,
) -> DDM raise PolyError {
  let rows = dense_lu_solve(
    l.to_list(),
    u.to_list(),
    swaps,
    b.to_list(),
    u.domain(),
  )
  ddm_from_dense(rows, u.domain())
}

///|
/// Return the inverse corresponding to SymPy `ddm_iinv`.

///|
/// Public API `ddm_iinv`.
///
/// - Does: Provides the `ddm_iinv` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_iinv(a : DDM) -> DDM raise PolyError {
  a.inv()
}

///|
/// Return the Bareiss-reduced matrix and determinant corresponding to SymPy `ddm_idet`.

///|
/// Public API `ddm_idet`.
///
/// - Does: Provides the `ddm_idet` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM) -> (DDM`, `FieldElem`, using the package
/// representation expected by the signature.
/// - Returns: a `(DDM, FieldElem)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_idet(a : DDM) -> (DDM, FieldElem) raise PolyError {
  let (rows, cols) = a.shape()
  if rows != cols {
    raise DomainMismatch
  }
  let out = clone_dense_rows(a.to_list())
  let det = ddm_bareiss_det_in_place(out, a.domain())
  (ddm_from_dense(out, a.domain()), det)
}

///|
/// Return the Berkowitz characteristic polynomial column matrix.

///|
/// Public API `ddm_berk`.
///
/// - Does: Provides the `ddm_berk` operation for dense domain-matrix algorithms.
/// - Input: parameters `a : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn ddm_berk(a : DDM) -> DDM raise PolyError {
  let coeffs = dense_berk(a.to_list(), a.domain())
  let column : Array[Array[FieldElem]] = Array::new()
  for coeff in coeffs {
    column.push([coeff])
  }
  ddm_from_dense(column, a.domain())
}
