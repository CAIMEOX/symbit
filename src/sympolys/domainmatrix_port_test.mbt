///|
fn dm_trim(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
fn dm_clear_denoms_repr(
  den : DomainScalar,
  num : DomainMatrix,
) -> String raise PolyError {
  "\{den.to_string()}@\{domain_to_sympy_string(den.domain)}||\{num.to_matrix_string()}@\{domain_to_sympy_string(num.domain)}"
}

///|
fn dm_clear_denoms_rowwise_repr(
  den : DomainMatrix,
  num : DomainMatrix,
) -> String raise PolyError {
  "\{den.to_matrix_string()}@\{domain_to_sympy_string(den.domain)}||\{num.to_matrix_string()}@\{domain_to_sympy_string(num.domain)}"
}

///|
fn dm_swaps_text(swaps : Array[(Int, Int)]) -> String {
  let parts : Array[String] = Array::new()
  for swap in swaps {
    parts.push("(\{swap.0}, \{swap.1})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn dm_coeffs_text(coeffs : Array[FieldElem]) -> String {
  let parts = coeffs.map(fe_to_string).join(", ")
  "[\{parts}]"
}

///|
fn dm_field_tuple_text(values : Array[FieldElem]) -> String {
  if values.is_empty() {
    return "()"
  }
  if values.length() == 1 {
    return "(\{fe_to_string(values[0])},)"
  }
  let joined = values.map(fe_to_string).join(", ")
  "(\{joined})"
}

///|
fn dm_dod_text(dod : DomainMatrixDOD) -> String {
  let row_keys : Array[Int] = Array::new()
  for r, _ in dod {
    row_keys.push(r)
  }
  row_keys.sort()
  let rows : Array[String] = Array::new()
  for r in row_keys {
    let row = match dod.get(r) {
      Some(v) => v
      None => {}
    }
    let col_keys : Array[Int] = Array::new()
    for c, _ in row {
      col_keys.push(c)
    }
    col_keys.sort()
    let cols : Array[String] = Array::new()
    for c in col_keys {
      cols.push("\{c}: \{fe_to_string(row[c])}")
    }
    let joined_cols = cols.join(", ")
    rows.push("\{r}: {\{joined_cols}}")
  }
  let joined_rows = rows.join(", ")
  "{\{joined_rows}}"
}

///|
fn dm_dok_text(dok : DomainMatrixDOK) -> String {
  let items : Array[(Int, Int, String)] = Array::new()
  for key, value in dok {
    items.push((key.0, key.1, fe_to_string(value)))
  }
  items.sort_by(fn(lhs, rhs) {
    if lhs.0 == rhs.0 {
      lhs.1.compare(rhs.1)
    } else {
      lhs.0.compare(rhs.0)
    }
  })
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push("(\{item.0}, \{item.1}): \{item.2}")
  }
  let joined = parts.join(", ")
  "{\{joined}}"
}

///|
fn dm_factor_list_text(factors : Array[(Array[FieldElem], Int)]) -> String {
  let parts : Array[String] = Array::new()
  for factor in factors {
    parts.push("(\{dm_coeffs_text(factor.0)}, \{factor.1})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn dm_is_diagonal(dm : DomainMatrix) -> Bool raise PolyError {
  let rows = dm.to_dense()
  for i in 0..<dm.rows {
    for j in 0..<dm.cols {
      if i != j && !fe_is_zero(rows[i][j]) {
        return false
      }
    }
  }
  true
}

///|
fn dm_is_upper(dm : DomainMatrix) -> Bool raise PolyError {
  let rows = dm.to_dense()
  for i in 0..<dm.rows {
    for j in 0..<dm.cols {
      if i > j && !fe_is_zero(rows[i][j]) {
        return false
      }
    }
  }
  true
}

///|
fn dm_rat(num : Int, den : Int) -> FieldElem raise PolyError {
  fe_from_rational(
    try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den)),
    Domain::QQ,
  )
}

///|
fn dm_to_int_rows(dm : DomainMatrix) -> Array[Array[Int]] raise PolyError {
  let rows = dm.to_dense()
  let out : Array[Array[Int]] = Array::new()
  for row in rows {
    let out_row : Array[Int] = Array::new()
    for value in row {
      let q = fe_expect_rational(value)
      if !q.denominator().equal_int(1) {
        raise PolyError::DomainMismatch
      }
      out_row.push(q.numerator().to_int())
    }
    out.push(out_row)
  }
  out
}

///|
test "domainmatrix: add/matmul/scalarmul parity over QQ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = domain_matrix_from_ints([[5, 6], [7, 8]], Domain::QQ)
  let two = try! fe_from_int(2, Domain::QQ)

  let ours_add = a.add(b).to_matrix_string()
  let ours_matmul = a.matmul(b).to_matrix_string()
  let ours_mul = a.mul(two).to_matrix_string()

  let oracle_add = @sympy_polys.domainmatrix_add(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_matmul = @sympy_polys.domainmatrix_matmul(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_mul = @sympy_polys.domainmatrix_mul([[1, 2], [3, 4]], 2, "QQ")

  guard dm_trim(ours_add) == dm_trim(oracle_add) else {
    fail("domainmatrix add mismatch: ours=\{ours_add}, oracle=\{oracle_add}")
  }
  guard dm_trim(ours_matmul) == dm_trim(oracle_matmul) else {
    fail("domainmatrix matmul mismatch: ours=\{ours_matmul}, oracle=\{oracle_matmul}")
  }
  guard dm_trim(ours_mul) == dm_trim(oracle_mul) else {
    fail("domainmatrix scalarmul mismatch: ours=\{ours_mul}, oracle=\{oracle_mul}")
  }
}

///|
test "domainmatrix: determinant parity over ZZ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let ours = fe_to_string(a.det())
  let oracle = @sympy_polys.domainmatrix_det([[1, 2], [3, 4]], "ZZ")
  guard dm_trim(ours) == dm_trim(oracle) else {
    fail("domainmatrix det mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "domainmatrix: rref parity over QQ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let (rref, pivots) = a.rref()
  let pivot_str = pivots.map(i => i.to_string()).join(",")
  let ours = "\{rref.to_matrix_string()}||[\{pivot_str}]"
  let oracle = @sympy_polys.domainmatrix_rref([[1, 2], [3, 4]], "QQ")
  guard dm_trim(ours) == dm_trim(oracle) else {
    fail("domainmatrix rref mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "domainmatrix: rref_den parity over ZZ" {
  let rows = [[1, 2, 3], [4, 5, 6]]
  let a = domain_matrix_from_ints(rows, Domain::ZZ)

  let ff = a.rref_den(rref_method="FF")
  let ff_pivots = ff.2.map(i => i.to_string()).join(",")
  let ours_ff = "\{ff.0.to_matrix_string()}||\{fe_to_string(ff.1)}||[\{ff_pivots}]"
  let oracle_ff = @sympy_polys.domainmatrix_rref_den(rows, "ZZ", rref_method="FF")

  let gj = a.rref_den(rref_method="GJ")
  let gj_pivots = gj.2.map(i => i.to_string()).join(",")
  let ours_gj = "\{gj.0.to_matrix_string()}||\{fe_to_string(gj.1)}||[\{gj_pivots}]"
  let oracle_gj = @sympy_polys.domainmatrix_rref_den(rows, "ZZ", rref_method="GJ")

  guard dm_trim(ours_ff) == dm_trim(oracle_ff) else {
    fail("domainmatrix rref_den FF mismatch: ours=\{ours_ff}, oracle=\{oracle_ff}")
  }
  guard dm_trim(ours_gj) == dm_trim(oracle_gj) else {
    fail("domainmatrix rref_den GJ mismatch: ours=\{ours_gj}, oracle=\{oracle_gj}")
  }
}

///|
test "domainmatrix: convert_to and to_field parity" {
  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)

  let ours_convert = a.convert_to(Domain::QQ).to_matrix_string()
  let ours_field = a.to_field().to_matrix_string()

  let oracle_convert = @sympy_polys.domainmatrix_convert_to(
    [[1, 2], [3, 4]],
    "ZZ",
    "QQ",
  )
  let oracle_field = @sympy_polys.domainmatrix_to_field([[1, 2], [3, 4]], "ZZ")

  guard dm_trim(ours_convert) == dm_trim(oracle_convert) else {
    fail("domainmatrix convert_to mismatch: ours=\{ours_convert}, oracle=\{oracle_convert}")
  }
  guard dm_trim(ours_field) == dm_trim(oracle_field) else {
    fail("domainmatrix to_field mismatch: ours=\{ours_field}, oracle=\{oracle_field}")
  }
}

///|
test "domainmatrix: clear_denoms parity over QQ" {
  let a = domain_matrix_from_dense(
    [
      [dm_rat(1, 2), dm_rat(1, 3), dm_rat(1, 4)],
      [dm_rat(1, 5), dm_rat(1, 6), dm_rat(1, 7)],
    ],
    Domain::QQ,
  )
  let keep = a.clear_denoms()
  let convert = a.clear_denoms(convert=true)

  let ours_keep = dm_clear_denoms_repr(keep.0, keep.1)
  let ours_convert = dm_clear_denoms_repr(convert.0, convert.1)

  let rows = [["1/2", "1/3", "1/4"], ["1/5", "1/6", "1/7"]]
  let oracle_keep = @sympy_polys.domainmatrix_clear_denoms_expr(rows, "QQ")
  let oracle_convert = @sympy_polys.domainmatrix_clear_denoms_expr(
    rows,
    "QQ",
    convert=true,
  )

  guard dm_trim(ours_keep) == dm_trim(oracle_keep) else {
    fail("domainmatrix clear_denoms mismatch: ours=\{ours_keep}, oracle=\{oracle_keep}")
  }
  guard dm_trim(ours_convert) == dm_trim(oracle_convert) else {
    fail(
      "domainmatrix clear_denoms(convert=True) mismatch: ours=\{ours_convert}, oracle=\{oracle_convert}",
    )
  }
}

///|
test "domainmatrix: clear_denoms_rowwise parity over QQ" {
  let a = domain_matrix_from_dense(
    [
      [dm_rat(1, 2), dm_rat(1, 3), dm_rat(1, 4)],
      [dm_rat(1, 5), dm_rat(1, 6), dm_rat(1, 7)],
    ],
    Domain::QQ,
  )
  let keep = a.clear_denoms_rowwise()
  let convert = a.clear_denoms_rowwise(convert=true)

  let ours_keep = dm_clear_denoms_rowwise_repr(keep.0, keep.1)
  let ours_convert = dm_clear_denoms_rowwise_repr(convert.0, convert.1)

  let rows = [["1/2", "1/3", "1/4"], ["1/5", "1/6", "1/7"]]
  let oracle_keep = @sympy_polys.domainmatrix_clear_denoms_rowwise_expr(rows, "QQ")
  let oracle_convert = @sympy_polys.domainmatrix_clear_denoms_rowwise_expr(
    rows,
    "QQ",
    convert=true,
  )

  guard dm_trim(ours_keep) == dm_trim(oracle_keep) else {
    fail("domainmatrix clear_denoms_rowwise mismatch: ours=\{ours_keep}, oracle=\{oracle_keep}")
  }
  guard dm_trim(ours_convert) == dm_trim(oracle_convert) else {
    fail(
      "domainmatrix clear_denoms_rowwise(convert=True) mismatch: ours=\{ours_convert}, oracle=\{oracle_convert}",
    )
  }
}

///|
test "domainmatrix: inverse parity over QQ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let ours = a.inv().to_matrix_string()
  let oracle = @sympy_polys.domainmatrix_inv([[1, 2], [3, 5]], "QQ")
  guard dm_trim(ours) == dm_trim(oracle) else {
    fail("domainmatrix inv mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "domainmatrix: lu and lu_solve parity over QQ" {
  let lu_rows = [[0, 1], [1, 1]]
  let a = domain_matrix_from_ints(lu_rows, Domain::QQ)
  let lu = a.lu()
  let ours_lu =
    "\{lu.0.to_matrix_string()}||\{lu.1.to_matrix_string()}||\{dm_swaps_text(lu.2)}"
  let oracle_lu = @sympy_polys.domainmatrix_lu(lu_rows, "QQ")
  guard dm_trim(ours_lu) == dm_trim(oracle_lu) else {
    fail("domainmatrix lu mismatch: ours=\{ours_lu}, oracle=\{oracle_lu}")
  }

  let rhs = domain_matrix_from_ints([[1], [0]], Domain::QQ)
  let ours_lu_solve = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  .lu_solve(rhs)
  .to_matrix_string()
  let oracle_lu_solve = @sympy_polys.domainmatrix_lu_solve(
    [[1, 2], [3, 4]],
    [[1], [0]],
    "QQ",
  )
  guard dm_trim(ours_lu_solve) == dm_trim(oracle_lu_solve) else {
    fail(
      "domainmatrix lu_solve mismatch: ours=\{ours_lu_solve}, oracle=\{oracle_lu_solve}",
    )
  }
}

///|
test "domainmatrix: qr invariants over QQ" {
  let rows = [[1, 2], [3, 4], [5, 6]]
  let a = domain_matrix_from_ints(rows, Domain::QQ)
  let qr = a.qr()
  let recomposed = qr.0.matmul(qr.1).to_matrix_string()
  guard dm_trim(recomposed) == dm_trim(a.to_matrix_string()) else {
    fail("domainmatrix qr reconstruction mismatch: \{recomposed}")
  }
  guard dm_is_diagonal(qr.0.transpose().matmul(qr.0)) else {
    fail("domainmatrix qr should give orthogonal columns")
  }
  guard dm_is_upper(qr.1) else {
    fail("domainmatrix qr should give upper-triangular R")
  }
}

///|
test "domainmatrix: fflu invariants and charpoly parity over ZZ" {
  let rows = [[1, 2], [3, 4]]
  let a = domain_matrix_from_ints(rows, Domain::ZZ)
  let fflu = a.fflu()
  let lhs = fflu.1.to_field().matmul(fflu.2.to_field().inv()).matmul(fflu.3.to_field())
  let rhs = fflu.0.to_field().matmul(a.to_field())
  guard dm_trim(lhs.to_matrix_string()) == dm_trim(rhs.to_matrix_string()) else {
    fail("domainmatrix fflu invariant mismatch")
  }
  guard dm_is_diagonal(fflu.2) else {
    fail("domainmatrix fflu should return diagonal D")
  }
  guard dm_is_upper(fflu.3) else {
    fail("domainmatrix fflu should return upper-triangular U")
  }

  let ours_charpoly = dm_coeffs_text(a.charpoly())
  let oracle_charpoly = @sympy_polys.domainmatrix_charpoly(rows, "ZZ")
  guard dm_trim(ours_charpoly) == dm_trim(oracle_charpoly) else {
    fail(
      "domainmatrix charpoly mismatch: ours=\{ours_charpoly}, oracle=\{oracle_charpoly}",
    )
  }
}

///|
test "domainmatrix: structural helper parity" {
  let diag_case = domain_matrix_from_ints([[1, 0], [0, 4]], Domain::ZZ)
  let ours_diag = dm_coeffs_text(diag_case.diagonal())
  let oracle_diag = @sympy_polys.domainmatrix_diagonal([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(ours_diag) == dm_trim(oracle_diag) else {
    fail("domainmatrix diagonal mismatch: ours=\{ours_diag}, oracle=\{oracle_diag}")
  }

  let ours_flat = dm_coeffs_text(diag_case.to_list_flat())
  let oracle_flat = @sympy_polys.domainmatrix_to_list_flat([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(ours_flat) == dm_trim(oracle_flat) else {
    fail("domainmatrix to_list_flat mismatch: ours=\{ours_flat}, oracle=\{oracle_flat}")
  }

  let ours_from_flat = DomainMatrix::from_list_flat(diag_case.to_list_flat(), (2, 2), Domain::ZZ)
  let oracle_from_flat = @sympy_polys.domainmatrix_from_list_flat([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(ours_from_flat.to_matrix_string()) == dm_trim(oracle_from_flat) else {
    fail(
      "domainmatrix from_list_flat mismatch: ours=\{ours_from_flat.to_matrix_string()}, oracle=\{oracle_from_flat}",
    )
  }

  let flat_nz = diag_case.to_flat_nz()
  let roundtrip_flat_nz = diag_case.from_flat_nz(flat_nz.0, flat_nz.1, Domain::ZZ)
  guard dm_trim(roundtrip_flat_nz.to_matrix_string()) == dm_trim(diag_case.to_matrix_string()) else {
    fail("domainmatrix from_flat_nz roundtrip mismatch")
  }
  guard dm_coeffs_text(flat_nz.0) == "[1, 0, 0, 4]" else {
    fail("domainmatrix to_flat_nz elements mismatch")
  }

  let ours_dod = dm_dod_text(diag_case.to_dod())
  let oracle_dod = @sympy_polys.domainmatrix_to_dod([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(ours_dod) == dm_trim(oracle_dod) else {
    fail("domainmatrix to_dod mismatch: ours=\{ours_dod}, oracle=\{oracle_dod}")
  }
  let from_dod = diag_case.from_dod_like(diag_case.to_dod())
  let oracle_from_dod = @sympy_polys.domainmatrix_from_dod_roundtrip([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(from_dod.to_matrix_string()) == dm_trim(oracle_from_dod) else {
    fail("domainmatrix from_dod mismatch: ours=\{from_dod.to_matrix_string()}, oracle=\{oracle_from_dod}")
  }

  let ours_dok = dm_dok_text(diag_case.to_dok())
  let oracle_dok = @sympy_polys.domainmatrix_to_dok([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(ours_dok) == dm_trim(oracle_dok) else {
    fail("domainmatrix to_dok mismatch: ours=\{ours_dok}, oracle=\{oracle_dok}")
  }
  let from_dok = DomainMatrix::from_dok(diag_case.to_dok(), (2, 2), Domain::ZZ)
  let oracle_from_dok = @sympy_polys.domainmatrix_from_dok_roundtrip([[1, 0], [0, 4]], "ZZ")
  guard dm_trim(from_dok.to_matrix_string()) == dm_trim(oracle_from_dok) else {
    fail("domainmatrix from_dok mismatch: ours=\{from_dok.to_matrix_string()}, oracle=\{oracle_from_dok}")
  }

  let two_zz = try! fe_from_int(2, Domain::ZZ)
  let applied = diag_case.applyfunc(fn(value : FieldElem) raise PolyError { fe_mul(value, two_zz) })
  guard dm_trim(applied.to_matrix_string()) == dm_trim("Matrix([[2, 0], [0, 8]])") else {
    fail("domainmatrix applyfunc mismatch: ours=\{applied.to_matrix_string()}")
  }
  guard diag_case.is_square() else {
    fail("domainmatrix is_square should hold")
  }

  guard diag_case.nnz() == @sympy_polys.domainmatrix_nnz([[1, 0], [0, 4]], "ZZ") else {
    fail("domainmatrix nnz mismatch")
  }

  let pow_case = domain_matrix_from_ints([[1, 1], [0, 1]], Domain::ZZ)
  let ours_pow = pow_case.pow(3).to_matrix_string()
  let oracle_pow = @sympy_polys.domainmatrix_pow([[1, 1], [0, 1]], "ZZ", 3)
  guard dm_trim(ours_pow) == dm_trim(oracle_pow) else {
    fail("domainmatrix pow mismatch: ours=\{ours_pow}, oracle=\{oracle_pow}")
  }

  let block_rows = [[6, -1, 0, 0], [9, 12, 0, 0], [0, 0, 1, 2], [0, 0, 5, 6]]
  let block = domain_matrix_from_ints(block_rows, Domain::ZZ)
  let ours_scc = block.scc().to_string()
  let oracle_scc = @sympy_polys.domainmatrix_scc(block_rows, "ZZ")
  guard dm_trim(ours_scc) == dm_trim(oracle_scc) else {
    fail("domainmatrix scc mismatch: ours=\{ours_scc}, oracle=\{oracle_scc}")
  }

  let ours_blocks = block.charpoly_factor_blocks().to_string()
  let oracle_blocks = @sympy_polys.domainmatrix_charpoly_factor_blocks(block_rows, "ZZ")
  guard dm_trim(ours_blocks) == dm_trim(oracle_blocks) else {
    fail(
      "domainmatrix charpoly_factor_blocks mismatch: ours=\{ours_blocks}, oracle=\{oracle_blocks}",
    )
  }

  let ours_factor_list = dm_factor_list_text(block.charpoly_factor_list())
  let oracle_factor_list = @sympy_polys.domainmatrix_charpoly_factor_list(block_rows, "ZZ")
  guard dm_trim(ours_factor_list) == dm_trim(oracle_factor_list) else {
    fail(
      "domainmatrix charpoly_factor_list mismatch: ours=\{ours_factor_list}, oracle=\{oracle_factor_list}",
    )
  }

  let lattice_rows = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  let lattice = domain_matrix_from_ints(lattice_rows, Domain::ZZ)
  let reduced = lattice.lll()
  let hnf_orig = @sympy_polys.matrix_hnf_code(lattice_rows)
  let hnf_reduced = @sympy_polys.matrix_hnf_code(try! dm_to_int_rows(reduced))
  guard hnf_orig == hnf_reduced else {
    fail("domainmatrix lll lattice mismatch")
  }
  let lll_transform = lattice.lll_transform()
  let recomposed = lll_transform.1.matmul(lattice).to_matrix_string()
  guard dm_trim(recomposed) == dm_trim(lll_transform.0.to_matrix_string()) else {
    fail("domainmatrix lll_transform reconstruction mismatch")
  }
  let hnf_transformed = @sympy_polys.matrix_hnf_code(try! dm_to_int_rows(lll_transform.0))
  guard hnf_orig == hnf_transformed else {
    fail("domainmatrix lll_transform lattice mismatch")
  }
}

///|
test "domainmatrix: content primitive cancel and charpoly-solve parity" {
  let qq_rows = [["1/2", "3/4"]]
  let qq = domain_matrix_from_dense([[dm_rat(1, 2), dm_rat(3, 4)]], Domain::QQ)
  let ours_content = fe_to_string(qq.content())
  let oracle_content = @sympy_polys.domainmatrix_content_expr(qq_rows, "QQ")
  guard dm_trim(ours_content) == dm_trim(oracle_content) else {
    fail("domainmatrix content mismatch: ours=\{ours_content}, oracle=\{oracle_content}")
  }

  let primitive = qq.primitive()
  let ours_primitive = "\{fe_to_string(primitive.0)}||\{primitive.1.to_matrix_string()}"
  let oracle_primitive = @sympy_polys.domainmatrix_primitive_expr(qq_rows, "QQ")
  guard dm_trim(ours_primitive) == dm_trim(oracle_primitive) else {
    fail(
      "domainmatrix primitive mismatch: ours=\{ours_primitive}, oracle=\{oracle_primitive}",
    )
  }

  let zz_rows = [["4", "6"]]
  let zz = domain_matrix_from_ints([[4, 6]], Domain::ZZ)
  let ours_cancel = zz.cancel_denom(try! fe_from_int(12, Domain::ZZ))
  let ours_cancel_text = "\{ours_cancel.0.to_matrix_string()}||\{fe_to_string(ours_cancel.1)}"
  let oracle_cancel = @sympy_polys.domainmatrix_cancel_denom_expr(zz_rows, "12", "ZZ")
  guard dm_trim(ours_cancel_text) == dm_trim(oracle_cancel) else {
    fail("domainmatrix cancel_denom mismatch: ours=\{ours_cancel_text}, oracle=\{oracle_cancel}")
  }

  let ours_cancel_elt = zz.cancel_denom_elementwise(try! fe_from_int(12, Domain::ZZ))
  let ours_cancel_elt_text =
    "\{ours_cancel_elt.0.to_matrix_string()}||\{ours_cancel_elt.1.to_matrix_string()}"
  let oracle_cancel_elt = @sympy_polys.domainmatrix_cancel_denom_elementwise_expr(
    zz_rows,
    "12",
    "ZZ",
  )
  guard dm_trim(ours_cancel_elt_text) == dm_trim(oracle_cancel_elt) else {
    fail(
      "domainmatrix cancel_denom_elementwise mismatch: ours=\{ours_cancel_elt_text}, oracle=\{oracle_cancel_elt}",
    )
  }

  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let b = domain_matrix_from_ints([[5], [6]], Domain::ZZ)
  let adj_poly_det = a.adj_poly_det()
  let ours_adj_poly_det =
    "\{dm_coeffs_text(adj_poly_det.0)}||\{fe_to_string(adj_poly_det.1)}"
  let oracle_adj_poly_det = @sympy_polys.domainmatrix_adj_poly_det([[1, 2], [3, 4]], "ZZ")
  guard dm_trim(ours_adj_poly_det) == dm_trim(oracle_adj_poly_det) else {
    fail(
      "domainmatrix adj_poly_det mismatch: ours=\{ours_adj_poly_det}, oracle=\{oracle_adj_poly_det}",
    )
  }

  let coeffs = [fe_from_int(1, Domain::ZZ), fe_from_int(2, Domain::ZZ), fe_from_int(3, Domain::ZZ)]
  let ours_eval_poly = a.eval_poly(coeffs).to_matrix_string()
  let oracle_eval_poly = @sympy_polys.domainmatrix_eval_poly(
    [[1, 2], [3, 4]],
    ["1", "2", "3"],
    "ZZ",
  )
  guard dm_trim(ours_eval_poly) == dm_trim(oracle_eval_poly) else {
    fail(
      "domainmatrix eval_poly mismatch: ours=\{ours_eval_poly}, oracle=\{oracle_eval_poly}",
    )
  }

  let ours_eval_poly_mul = a.eval_poly_mul(coeffs, b).to_matrix_string()
  let oracle_eval_poly_mul = @sympy_polys.domainmatrix_eval_poly_mul(
    [[1, 2], [3, 4]],
    ["1", "2", "3"],
    [[5], [6]],
    "ZZ",
  )
  guard dm_trim(ours_eval_poly_mul) == dm_trim(oracle_eval_poly_mul) else {
    fail(
      "domainmatrix eval_poly_mul mismatch: ours=\{ours_eval_poly_mul}, oracle=\{oracle_eval_poly_mul}",
    )
  }

  let ours_solve_charpoly = a.solve_den_charpoly(b)
  let ours_solve_charpoly_text =
    "\{ours_solve_charpoly.0.to_matrix_string()}||\{fe_to_string(ours_solve_charpoly.1)}"
  let oracle_solve_charpoly = @sympy_polys.domainmatrix_solve_den_charpoly(
    [[1, 2], [3, 4]],
    [[5], [6]],
    "ZZ",
  )
  guard dm_trim(ours_solve_charpoly_text) == dm_trim(oracle_solve_charpoly) else {
    fail(
      "domainmatrix solve_den_charpoly mismatch: ours=\{ours_solve_charpoly_text}, oracle=\{oracle_solve_charpoly}",
    )
  }
}

///|
test "domainmatrix: adjugate, adj_det, inv_den, solve_den parity over ZZ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let b = domain_matrix_from_ints([[5], [6]], Domain::ZZ)
  let adj_det = a.adj_det()
  let inv_den = a.inv_den()
  let solve_den = a.solve_den(b)

  let ours_adjugate = a.adjugate().to_matrix_string()
  let ours_adj_det = "\{adj_det.0.to_matrix_string()}||\{fe_to_string(adj_det.1)}"
  let ours_inv_den = "\{inv_den.0.to_matrix_string()}||\{fe_to_string(inv_den.1)}"
  let ours_solve_den = "\{solve_den.0.to_matrix_string()}||\{fe_to_string(solve_den.1)}"

  let oracle_adjugate = @sympy_polys.domainmatrix_adjugate([[1, 2], [3, 4]], "ZZ")
  let oracle_adj_det = @sympy_polys.domainmatrix_adj_det([[1, 2], [3, 4]], "ZZ")
  let oracle_inv_den = @sympy_polys.domainmatrix_inv_den([[1, 2], [3, 4]], "ZZ")
  let oracle_solve_den = @sympy_polys.domainmatrix_solve_den(
    [[1, 2], [3, 4]],
    [[5], [6]],
    "ZZ",
  )

  guard dm_trim(ours_adjugate) == dm_trim(oracle_adjugate) else {
    fail("domainmatrix adjugate mismatch: ours=\{ours_adjugate}, oracle=\{oracle_adjugate}")
  }
  guard dm_trim(ours_adj_det) == dm_trim(oracle_adj_det) else {
    fail("domainmatrix adj_det mismatch: ours=\{ours_adj_det}, oracle=\{oracle_adj_det}")
  }
  guard dm_trim(ours_inv_den) == dm_trim(oracle_inv_den) else {
    fail("domainmatrix inv_den mismatch: ours=\{ours_inv_den}, oracle=\{oracle_inv_den}")
  }
  guard dm_trim(ours_solve_den) == dm_trim(oracle_solve_den) else {
    fail("domainmatrix solve_den mismatch: ours=\{ours_solve_den}, oracle=\{oracle_solve_den}")
  }
}

///|
test "domainmatrix: smith normal form parity over ZZ" {
  let rows = [[12, 6, 4], [3, 9, 6], [2, 16, 14]]
  let a = domain_matrix_from_ints(rows, Domain::ZZ)
  let smf = a.smith_normal_form()
  let decomp = a.smith_normal_decomp()
  let ours_invs = dm_field_tuple_text(a.invariant_factors())
  let ours_smf = smf.to_matrix_string()
  let oracle_invs = @sympy_polys.domainmatrix_invariant_factors(rows, "ZZ")
  let oracle_smf = @sympy_polys.domainmatrix_smith_normal_form(rows, "ZZ")
  guard ours_invs == oracle_invs else {
    fail("domainmatrix invariant_factors mismatch: ours=\{ours_invs}, oracle=\{oracle_invs}")
  }
  guard dm_trim(ours_smf) == dm_trim(oracle_smf) else {
    fail("domainmatrix smith_normal_form mismatch: ours=\{ours_smf}, oracle=\{oracle_smf}")
  }
  guard smf.is_smith_normal_form() else {
    fail("domainmatrix smith_normal_form should satisfy smith predicate")
  }
  guard @sympy_polys.domainmatrix_is_smith_normal_form(try! dm_to_int_rows(smf), "ZZ") else {
    fail("oracle smith predicate should accept smith normal form")
  }
  let recomposed = decomp.1.matmul(a).matmul(decomp.2).to_matrix_string()
  guard dm_trim(recomposed) == dm_trim(ours_smf) else {
    fail("domainmatrix smith decomposition reconstruction mismatch")
  }
}

///|
test "domainmatrix: row/column/nullspace parity over QQ" {
  let rows = [[1, 2, 3], [2, 4, 6], [1, 1, 1]]
  let a = domain_matrix_from_ints(rows, Domain::QQ)

  let ours_rowspace = a.rowspace().to_matrix_string()
  let ours_columnspace = a.columnspace().to_matrix_string()
  let ours_nullspace = a.nullspace().to_matrix_string()

  let oracle_rowspace = @sympy_polys.domainmatrix_rowspace(rows, "QQ")
  let oracle_columnspace = @sympy_polys.domainmatrix_columnspace(rows, "QQ")
  let oracle_nullspace = @sympy_polys.domainmatrix_nullspace(rows, "QQ")

  guard dm_trim(ours_rowspace) == dm_trim(oracle_rowspace) else {
    fail("domainmatrix rowspace mismatch: ours=\{ours_rowspace}, oracle=\{oracle_rowspace}")
  }
  guard dm_trim(ours_columnspace) == dm_trim(oracle_columnspace) else {
    fail(
      "domainmatrix columnspace mismatch: ours=\{ours_columnspace}, oracle=\{oracle_columnspace}",
    )
  }
  guard dm_trim(ours_nullspace) == dm_trim(oracle_nullspace) else {
    fail("domainmatrix nullspace mismatch: ours=\{ours_nullspace}, oracle=\{oracle_nullspace}")
  }
}

///|
test "domainmatrix: non-field nullspace parity over ZZ" {
  let rows = [[6, -3], [4, -2]]
  let a = domain_matrix_from_ints(rows, Domain::ZZ)
  let ours = a.nullspace().to_matrix_string()
  let oracle = @sympy_polys.domainmatrix_nullspace(rows, "ZZ")
  guard dm_trim(ours) == dm_trim(oracle) else {
    fail("domainmatrix ZZ nullspace mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "domainmatrix: solve_den_rref parity on rectangular ZZ system" {
  let a_rows = [[2, 0], [0, 3], [2, 3]]
  let b_rows = [[1], [1], [2]]
  let a = domain_matrix_from_ints(a_rows, Domain::ZZ)
  let b = domain_matrix_from_ints(b_rows, Domain::ZZ)
  let ours = a.solve_den_rref(b)
  let ours_text = "\{ours.0.to_matrix_string()}||\{fe_to_string(ours.1)}"
  let oracle = @sympy_polys.domainmatrix_solve_den_rref(a_rows, b_rows, "ZZ")
  guard dm_trim(ours_text) == dm_trim(oracle) else {
    fail("domainmatrix solve_den_rref mismatch: ours=\{ours_text}, oracle=\{oracle}")
  }
}

///|
test "domainmatrix: solve_den_rref rejects non-unique systems" {
  let under = domain_matrix_from_ints([[1, 1]], Domain::ZZ)
  let under_rhs = domain_matrix_from_ints([[1]], Domain::ZZ)
  guard (try? under.solve_den_rref(under_rhs)) is Err(_) else {
    fail("solve_den_rref should reject underdetermined systems")
  }

  let inconsistent = domain_matrix_from_ints([[1, 1], [1, 1]], Domain::ZZ)
  let inconsistent_rhs = domain_matrix_from_ints([[1], [2]], Domain::ZZ)
  guard (try? inconsistent.solve_den_rref(inconsistent_rhs)) is Err(_) else {
    fail("solve_den_rref should reject inconsistent systems")
  }
}

///|
test "domainmatrix: elimination does not mutate the input matrix" {
  let a = domain_matrix_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let _ = a.det()
  let _ = a.rref()
  let _ = a.rref_den()
  let _ = a.inv()
  guard dm_trim(a.to_matrix_string()) == dm_trim("Matrix([[1, 2], [3, 5]])") else {
    fail("domainmatrix operations should not mutate the receiver")
  }
}
