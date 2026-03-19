///|
fn md_trim(s : String) -> String {
  s.replace_all(old=" ", new="").replace_all(old="\n", new="")
}

///|
fn md_pack_lu(l : DDM, u : DDM) -> DDM raise PolyError {
  let (rows, cols) = u.shape()
  let dense = u.to_list()
  let lower = l.to_list()
  let limit = if rows < cols { rows } else { cols }
  for i in 1..<rows {
    let upto = if i < limit { i } else { limit }
    for j in 0..<upto {
      dense[i].set(j, lower[i][j])
    }
  }
  ddm_from_dense(dense, u.domain())
}

///|
fn md_column_coeffs_text(column : DDM) -> String raise PolyError {
  let rows = column.to_list()
  let parts : Array[String] = Array::new()
  for row in rows {
    if row.length() != 1 {
      raise PolyError::DomainMismatch
    }
    parts.push(fe_to_string(row[0]))
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
test "matrix dense wrappers: arithmetic helpers match DDM methods" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = ddm_from_ints([[5, 6], [7, 8]], Domain::QQ)
  let acc = ddm_from_ints([[1, 0], [0, 1]], Domain::QQ)
  let two = fe_from_int(2, Domain::QQ)
  assert_eq(md_trim(ddm_transpose(a).to_string()), md_trim(a.transpose().to_string()))
  assert_eq(md_trim(ddm_iadd(a, b).to_string()), md_trim(a.add(b).to_string()))
  assert_eq(md_trim(ddm_isub(a, b).to_string()), md_trim(a.sub(b).to_string()))
  assert_eq(md_trim(ddm_ineg(a).to_string()), md_trim(a.neg().to_string()))
  assert_eq(md_trim(ddm_imul(a, two).to_string()), md_trim(a.mul(two).to_string()))
  assert_eq(md_trim(ddm_irmul(a, two).to_string()), md_trim(a.rmul(two).to_string()))
  assert_eq(md_trim(ddm_imatmul(acc, a, b).to_string()), md_trim(acc.add(a.matmul(b)).to_string()))
}

///|
test "matrix dense wrappers: elimination and determinant helpers match methods and oracle" {
  let rref_source = ddm_from_ints([[1, 2, 3], [4, 5, 6]], Domain::QQ)
  let (rref_wrap, pivots_wrap) = ddm_irref(rref_source)
  let (rref_method, pivots_method) = rref_source.rref()
  assert_eq(pivots_wrap, pivots_method)
  assert_eq(md_trim(rref_wrap.to_string()), md_trim(rref_method.to_string()))
  let oracle_rref = @sympy_polys.domainmatrix_rref([[1, 2, 3], [4, 5, 6]], "QQ")
  assert_eq(md_trim(
          "\{rref_wrap.to_domain_matrix().to_matrix_string()}||\{pivots_wrap.to_string()}",
        ), md_trim(oracle_rref))

  let zz = ddm_from_ints([[2, 4], [6, 8]], Domain::ZZ)
  let (rref_den_wrap, den_wrap, den_pivots_wrap) = ddm_irref_den(zz)
  let (rref_den_method, den_method, den_pivots_method) = zz.rref_den()
  assert_true(
    den_pivots_wrap == den_pivots_method &&
        fe_to_string(den_wrap) == fe_to_string(den_method)
  )
  assert_eq(md_trim(rref_den_wrap.to_string()), md_trim(rref_den_method.to_string()))
  let oracle_rref_den = @sympy_polys.domainmatrix_rref_den(
    [[2, 4], [6, 8]],
    "ZZ",
  )
  assert_eq(md_trim(
          "\{rref_den_wrap.to_domain_matrix().to_matrix_string()}||\{fe_to_string(den_wrap)}||\{den_pivots_wrap.to_string()}",
        ), md_trim(oracle_rref_den))

  let det_source = ddm_from_ints([[1, 2, 3], [4, 5, 6], [7, 8, 9]], Domain::ZZ)
  let (bareiss, det) = ddm_idet(det_source)
  assert_eq(fe_to_string(det), fe_to_string(det_source.det()))
  let oracle_det = @sympy_polys.domainmatrix_det(
    [[1, 2, 3], [4, 5, 6], [7, 8, 9]],
    "ZZ",
  )
  assert_eq(fe_to_string(det), oracle_det)
  let bareiss_diag_text = bareiss.diagonal().map(fe_to_string).join(", ")
  let bareiss_diag = "[\{bareiss_diag_text}]"
  assert_eq(md_trim(bareiss_diag), md_trim("[1, -3, 0]"))
}

///|
test "matrix dense wrappers: LU, inverse, and berkowitz helpers line up" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let (packed, swaps) = ddm_ilu(a)
  let (l, u, split_swaps) = ddm_ilu_split(a)
  assert_eq(swaps, split_swaps)
  assert_eq(md_trim(packed.to_string()), md_trim(md_pack_lu(l, u).to_string()))
  let rhs = ddm_from_ints([[5], [6]], Domain::QQ)
  assert_eq(md_trim(ddm_ilu_solve(l, u, swaps, rhs).to_string()), md_trim(a.lu_solve(rhs).to_string()))
  assert_eq(md_trim(ddm_iinv(a).to_string()), md_trim(a.inv().to_string()))
  let oracle_inv = @sympy_polys.domainmatrix_inv([[1, 2], [3, 4]], "QQ")
  assert_eq(md_trim(ddm_iinv(a).to_domain_matrix().to_matrix_string()), md_trim(oracle_inv))

  let berk = ddm_berk(ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ))
  assert_eq(md_trim(md_column_coeffs_text(berk)), md_trim("[1, -5, -2]"))
  let oracle_charpoly = @sympy_polys.domainmatrix_charpoly(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  assert_eq(md_trim(md_column_coeffs_text(berk)), md_trim(oracle_charpoly))
}

///|
test "matrix dense wrappers: internal DDM helpers stay aligned" {
  let zz = ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let phase1 = zz._fflu()
  assert_eq(md_trim(phase1.0.to_string()), md_trim("[[1, 2], [3, -2]]"))
  assert_eq(phase1.1, [0, 1])

  let swapped = ddm_from_ints([[0, 1], [2, 3]], Domain::ZZ)._fflu()
  assert_eq(md_trim(swapped.0.to_string()), md_trim("[[2, 3], [0, 2]]"))
  assert_eq(swapped.1, [1, 0])

  let other_domain = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  assert_true(
    (try? zz._check("+", other_domain, zz.shape(), other_domain.shape()))
        is Err(PolyError::DomainMismatch)
  )

  let wrong_shape = ddm_from_ints([[1, 2]], Domain::ZZ)
  assert_true(
    (try? zz._check("+", wrong_shape, zz.shape(), wrong_shape.shape()))
        is Err(PolyError::DomainMismatch)
  )
}
