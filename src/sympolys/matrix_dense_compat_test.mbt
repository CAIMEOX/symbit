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
  guard md_trim(ddm_transpose(a).to_string()) ==
    md_trim(a.transpose().to_string()) else {
    fail("ddm_transpose mismatch")
  }
  guard md_trim(ddm_iadd(a, b).to_string()) == md_trim(a.add(b).to_string()) else {
    fail("ddm_iadd mismatch")
  }
  guard md_trim(ddm_isub(a, b).to_string()) == md_trim(a.sub(b).to_string()) else {
    fail("ddm_isub mismatch")
  }
  guard md_trim(ddm_ineg(a).to_string()) == md_trim(a.neg().to_string()) else {
    fail("ddm_ineg mismatch")
  }
  guard md_trim(ddm_imul(a, two).to_string()) == md_trim(a.mul(two).to_string()) else {
    fail("ddm_imul mismatch")
  }
  guard md_trim(ddm_irmul(a, two).to_string()) ==
    md_trim(a.rmul(two).to_string()) else {
    fail("ddm_irmul mismatch")
  }
  guard md_trim(ddm_imatmul(acc, a, b).to_string()) ==
    md_trim(acc.add(a.matmul(b)).to_string()) else {
    fail("ddm_imatmul mismatch")
  }
}

///|
test "matrix dense wrappers: elimination and determinant helpers match methods and oracle" {
  let rref_source = ddm_from_ints([[1, 2, 3], [4, 5, 6]], Domain::QQ)
  let (rref_wrap, pivots_wrap) = ddm_irref(rref_source)
  let (rref_method, pivots_method) = rref_source.rref()
  guard pivots_wrap == pivots_method else { fail("ddm_irref pivot mismatch") }
  guard md_trim(rref_wrap.to_string()) == md_trim(rref_method.to_string()) else {
    fail("ddm_irref matrix mismatch")
  }
  let oracle_rref = @sympy_polys.domainmatrix_rref([[1, 2, 3], [4, 5, 6]], "QQ")
  guard md_trim(
      "\{rref_wrap.to_domain_matrix().to_matrix_string()}||\{pivots_wrap.to_string()}",
    ) ==
    md_trim(oracle_rref) else {
    fail("ddm_irref oracle mismatch")
  }

  let zz = ddm_from_ints([[2, 4], [6, 8]], Domain::ZZ)
  let (rref_den_wrap, den_wrap, den_pivots_wrap) = ddm_irref_den(zz)
  let (rref_den_method, den_method, den_pivots_method) = zz.rref_den()
  guard den_pivots_wrap == den_pivots_method &&
    fe_to_string(den_wrap) == fe_to_string(den_method) else {
    fail("ddm_irref_den pivot/den mismatch")
  }
  guard md_trim(rref_den_wrap.to_string()) ==
    md_trim(rref_den_method.to_string()) else {
    fail("ddm_irref_den matrix mismatch")
  }
  let oracle_rref_den = @sympy_polys.domainmatrix_rref_den(
    [[2, 4], [6, 8]],
    "ZZ",
  )
  guard md_trim(
      "\{rref_den_wrap.to_domain_matrix().to_matrix_string()}||\{fe_to_string(den_wrap)}||\{den_pivots_wrap.to_string()}",
    ) ==
    md_trim(oracle_rref_den) else {
    fail("ddm_irref_den oracle mismatch")
  }

  let det_source = ddm_from_ints([[1, 2, 3], [4, 5, 6], [7, 8, 9]], Domain::ZZ)
  let (bareiss, det) = ddm_idet(det_source)
  guard fe_to_string(det) == fe_to_string(det_source.det()) else {
    fail("ddm_idet determinant mismatch")
  }
  let oracle_det = @sympy_polys.domainmatrix_det(
    [[1, 2, 3], [4, 5, 6], [7, 8, 9]],
    "ZZ",
  )
  guard fe_to_string(det) == oracle_det else {
    fail("ddm_idet oracle mismatch")
  }
  let bareiss_diag_text = bareiss.diagonal().map(fe_to_string).join(", ")
  let bareiss_diag = "[\{bareiss_diag_text}]"
  guard md_trim(bareiss_diag) == md_trim("[1, -3, 0]") else {
    fail("ddm_idet Bareiss diagonal mismatch")
  }
}

///|
test "matrix dense wrappers: LU, inverse, and berkowitz helpers line up" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let (packed, swaps) = ddm_ilu(a)
  let (l, u, split_swaps) = ddm_ilu_split(a)
  guard swaps == split_swaps else { fail("ddm_ilu swap mismatch") }
  guard md_trim(packed.to_string()) == md_trim(md_pack_lu(l, u).to_string()) else {
    fail("ddm_ilu packed LU mismatch")
  }
  let rhs = ddm_from_ints([[5], [6]], Domain::QQ)
  guard md_trim(ddm_ilu_solve(l, u, swaps, rhs).to_string()) ==
    md_trim(a.lu_solve(rhs).to_string()) else {
    fail("ddm_ilu_solve mismatch")
  }
  guard md_trim(ddm_iinv(a).to_string()) == md_trim(a.inv().to_string()) else {
    fail("ddm_iinv mismatch")
  }
  let oracle_inv = @sympy_polys.domainmatrix_inv([[1, 2], [3, 4]], "QQ")
  guard md_trim(ddm_iinv(a).to_domain_matrix().to_matrix_string()) ==
    md_trim(oracle_inv) else {
    fail("ddm_iinv oracle mismatch")
  }

  let berk = ddm_berk(ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ))
  guard md_trim(md_column_coeffs_text(berk)) == md_trim("[1, -5, -2]") else {
    fail("ddm_berk coefficient mismatch")
  }
  let oracle_charpoly = @sympy_polys.domainmatrix_charpoly(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  guard md_trim(md_column_coeffs_text(berk)) == md_trim(oracle_charpoly) else {
    fail("ddm_berk oracle mismatch")
  }
}

///|
test "matrix dense wrappers: internal DDM helpers stay aligned" {
  let zz = ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let phase1 = zz._fflu()
  guard md_trim(phase1.0.to_string()) == md_trim("[[1, 2], [3, -2]]") else {
    fail("ddm _fflu LU mismatch: \{phase1.0.to_string()}")
  }
  guard phase1.1 == [0, 1] else {
    fail("ddm _fflu permutation mismatch: \{phase1.1.to_string()}")
  }

  let swapped = ddm_from_ints([[0, 1], [2, 3]], Domain::ZZ)._fflu()
  guard md_trim(swapped.0.to_string()) == md_trim("[[2, 3], [0, 2]]") else {
    fail("ddm _fflu swapped LU mismatch: \{swapped.0.to_string()}")
  }
  guard swapped.1 == [1, 0] else {
    fail("ddm _fflu swapped permutation mismatch: \{swapped.1.to_string()}")
  }

  let other_domain = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  guard (try? zz._check("+", other_domain, zz.shape(), other_domain.shape()))
    is Err(PolyError::DomainMismatch) else {
    fail("ddm _check should reject domain mismatch")
  }

  let wrong_shape = ddm_from_ints([[1, 2]], Domain::ZZ)
  guard (try? zz._check("+", wrong_shape, zz.shape(), wrong_shape.shape()))
    is Err(PolyError::DomainMismatch) else {
    fail("ddm _check should reject shape mismatch")
  }
}
