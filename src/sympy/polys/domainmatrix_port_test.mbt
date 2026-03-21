///|
fn dm_trim(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
fn dm_clear_denoms_repr(
  den : DomainScalar,
  num : DomainMatrix,
) -> String raise PolyError {
  "\{den.to_string()}@\{@sympolys.domain_to_sympy_string(den.domain)}||\{num.to_matrix_string()}@\{@sympolys.domain_to_sympy_string(num.domain)}"
}

///|
fn dm_clear_denoms_rowwise_repr(
  den : DomainMatrix,
  num : DomainMatrix,
) -> String raise PolyError {
  "\{den.to_matrix_string()}@\{@sympolys.domain_to_sympy_string(den.domain)}||\{num.to_matrix_string()}@\{@sympolys.domain_to_sympy_string(num.domain)}"
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
    return "(\{@sympolys.fe_to_string(values[0])},)"
  }
  let joined = values.map(fe_to_string).join(", ")
  "(\{joined})"
}

///|
fn dm_normalize_expr_text(text : String) -> String {
  text.replace_all(old=" + -", new=" - ")
}

///|
fn dm_dom_eigenvects_text(
  values : (DomainMatrixRationalEigenvects, DomainMatrixAlgebraicEigenvects),
) -> String raise PolyError {
  let parts : Array[String] = Array::new()
  for item in values.0 {
    parts.push(
      "r:\{@sympolys.fe_to_string(item.1)}:\{item.2}:\{item.3.to_matrix_string()}",
    )
  }
  for item in values.1 {
    parts.push(
      "a:\{dm_normalize_expr_text(item.1.to_string())}:\{item.2}:\{item.3.to_matrix_string()}",
    )
  }
  parts.sort()
  parts.join("||")
}

///|
fn dm_solve_summary(
  value : (DomainMatrix, DomainMatrix),
) -> String raise PolyError {
  "\{value.0.to_matrix_string()}||\{value.1.to_matrix_string()}"
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
      cols.push("\{c}: \{@sympolys.fe_to_string(row[c])}")
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
    items.push((key.0, key.1, @sympolys.fe_to_string(value)))
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
fn dm_expr_matrix_text(rows : MatrixExpr) -> String {
  let row_text : Array[String] = Array::new()
  for row in rows {
    let cells = row.map(@symprint.to_string).join(", ")
    row_text.push("[\{cells}]")
  }
  let joined = row_text.join(", ")
  "Matrix([\{joined}])"
}

///|
fn dm_fmt(dm : DomainMatrix) -> String {
  match dm.rep {
    DomainMatrixRep::Dense(_) => "dense"
    DomainMatrixRep::Sparse(_) => "sparse"
  }
}

///|
fn dm_summary(dm : DomainMatrix) -> String raise PolyError {
  "\{dm.to_matrix_string()}@\{@sympolys.domain_to_sympy_string(dm.domain)}|\{dm_fmt(dm)}"
}

///|
fn dm_is_diagonal(dm : DomainMatrix) -> Bool raise PolyError {
  let rows = dm.to_dense()
  for i in 0..<dm.rows {
    for j in 0..<dm.cols {
      if i != j && !@sympolys.fe_is_zero(rows[i][j]) {
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
      if i > j && !@sympolys.fe_is_zero(rows[i][j]) {
        return false
      }
    }
  }
  true
}

///|
fn dm_rat(num : Int, den : Int) -> FieldElem raise PolyError {
  @sympolys.fe_from_rational(
    @symnum.BigRational::from_ints(num, den) catch {
      _ => raise PolyError::DivisionByZero
    },
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
      let q = @sympolys.fe_expect_rational(value)
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
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = @sympolys.domain_matrix_from_ints([[5, 6], [7, 8]], Domain::QQ)
  let two = @sympolys.fe_from_int(2, Domain::QQ)

  let ours_add = a.add(b).to_matrix_string()
  let ours_matmul = a.matmul(b).to_matrix_string()
  let ours_mul = a.mul(two).to_matrix_string()

  let oracle_add = domainmatrix_add([[1, 2], [3, 4]], [[5, 6], [7, 8]], "QQ")
  let oracle_matmul = domainmatrix_matmul(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_mul = domainmatrix_mul([[1, 2], [3, 4]], 2, "QQ")

  assert_eq(dm_trim(ours_add), dm_trim(oracle_add))
  assert_eq(dm_trim(ours_matmul), dm_trim(oracle_matmul))
  assert_eq(dm_trim(ours_mul), dm_trim(oracle_mul))
}

///|
test "domainmatrix: determinant parity over ZZ" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let ours = @sympolys.fe_to_string(a.det())
  let oracle = domainmatrix_det([[1, 2], [3, 4]], "ZZ")
  assert_eq(dm_trim(ours), dm_trim(oracle))
}

///|
test "domainmatrix: rref parity over QQ" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let (rref, pivots) = a.rref()
  let pivot_str = pivots.map(i => i.to_string()).join(",")
  let ours = "\{rref.to_matrix_string()}||[\{pivot_str}]"
  let oracle = domainmatrix_rref([[1, 2], [3, 4]], "QQ")
  assert_eq(dm_trim(ours), dm_trim(oracle))
}

///|
test "domainmatrix: rref_den parity over ZZ" {
  let rows = [[1, 2, 3], [4, 5, 6]]
  let a = @sympolys.domain_matrix_from_ints(rows, Domain::ZZ)

  let ff = a.rref_den(rref_method="FF")
  let ff_pivots = ff.2.map(i => i.to_string()).join(",")
  let ours_ff = "\{ff.0.to_matrix_string()}||\{@sympolys.fe_to_string(ff.1)}||[\{ff_pivots}]"
  let oracle_ff = domainmatrix_rref_den(rows, "ZZ", rref_method="FF")

  let gj = a.rref_den(rref_method="GJ")
  let gj_pivots = gj.2.map(i => i.to_string()).join(",")
  let ours_gj = "\{gj.0.to_matrix_string()}||\{@sympolys.fe_to_string(gj.1)}||[\{gj_pivots}]"
  let oracle_gj = domainmatrix_rref_den(rows, "ZZ", rref_method="GJ")

  assert_eq(dm_trim(ours_ff), dm_trim(oracle_ff))
  assert_eq(dm_trim(ours_gj), dm_trim(oracle_gj))
}

///|
test "domainmatrix: convert_to and to_field parity" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)

  let ours_convert = a.convert_to(Domain::QQ).to_matrix_string()
  let ours_field = a.to_field().to_matrix_string()

  let oracle_convert = domainmatrix_convert_to([[1, 2], [3, 4]], "ZZ", "QQ")
  let oracle_field = domainmatrix_to_field([[1, 2], [3, 4]], "ZZ")

  assert_eq(dm_trim(ours_convert), dm_trim(oracle_convert))
  assert_eq(dm_trim(ours_field), dm_trim(oracle_field))
}

///|
test "domainmatrix: clear_denoms parity over QQ" {
  let a = @sympolys.domain_matrix_from_dense(
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
  let oracle_keep = domainmatrix_clear_denoms_expr(rows, "QQ")
  let oracle_convert = domainmatrix_clear_denoms_expr(rows, "QQ", convert=true)

  assert_eq(dm_trim(ours_keep), dm_trim(oracle_keep))
  assert_eq(dm_trim(ours_convert), dm_trim(oracle_convert))
}

///|
test "domainmatrix: clear_denoms_rowwise parity over QQ" {
  let a = @sympolys.domain_matrix_from_dense(
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
  let oracle_keep = domainmatrix_clear_denoms_rowwise_expr(rows, "QQ")
  let oracle_convert = domainmatrix_clear_denoms_rowwise_expr(
    rows,
    "QQ",
    convert=true,
  )

  assert_eq(dm_trim(ours_keep), dm_trim(oracle_keep))
  assert_eq(dm_trim(ours_convert), dm_trim(oracle_convert))
}

///|
test "domainmatrix: inverse parity over QQ" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let ours = a.inv().to_matrix_string()
  let oracle = domainmatrix_inv([[1, 2], [3, 5]], "QQ")
  assert_eq(dm_trim(ours), dm_trim(oracle))
}

///|
test "domainmatrix: lu and lu_solve parity over QQ" {
  let lu_rows = [[0, 1], [1, 1]]
  let a = @sympolys.domain_matrix_from_ints(lu_rows, Domain::QQ)
  let lu = a.lu()
  let ours_lu = "\{lu.0.to_matrix_string()}||\{lu.1.to_matrix_string()}||\{dm_swaps_text(lu.2)}"
  let oracle_lu = domainmatrix_lu(lu_rows, "QQ")
  assert_eq(dm_trim(ours_lu), dm_trim(oracle_lu))

  let rhs = @sympolys.domain_matrix_from_ints([[1], [0]], Domain::QQ)
  let ours_lu_solve = @sympolys.domain_matrix_from_ints(
      [[1, 2], [3, 4]],
      Domain::QQ,
    )
    .lu_solve(rhs)
    .to_matrix_string()
  let oracle_lu_solve = domainmatrix_lu_solve(
    [[1, 2], [3, 4]],
    [[1], [0]],
    "QQ",
  )
  assert_eq(dm_trim(ours_lu_solve), dm_trim(oracle_lu_solve))
}

///|
test "domainmatrix: qr invariants over QQ" {
  let rows = [[1, 2], [3, 4], [5, 6]]
  let a = @sympolys.domain_matrix_from_ints(rows, Domain::QQ)
  let qr = a.qr()
  let recomposed = qr.0.matmul(qr.1).to_matrix_string()
  assert_eq(dm_trim(recomposed), dm_trim(a.to_matrix_string()))
  assert_true(dm_is_diagonal(qr.0.transpose().matmul(qr.0)))
  assert_true(dm_is_upper(qr.1))
}

///|
test "domainmatrix: fflu invariants and charpoly parity over ZZ" {
  let rows = [[1, 2], [3, 4]]
  let a = @sympolys.domain_matrix_from_ints(rows, Domain::ZZ)
  let fflu = a.fflu()
  let lhs = fflu.1
    .to_field()
    .matmul(fflu.2.to_field().inv())
    .matmul(fflu.3.to_field())
  let rhs = fflu.0.to_field().matmul(a.to_field())
  assert_eq(dm_trim(lhs.to_matrix_string()), dm_trim(rhs.to_matrix_string()))
  assert_true(dm_is_diagonal(fflu.2))
  assert_true(dm_is_upper(fflu.3))

  let ours_charpoly = dm_coeffs_text(a.charpoly())
  let oracle_charpoly = domainmatrix_charpoly(rows, "ZZ")
  assert_eq(dm_trim(ours_charpoly), dm_trim(oracle_charpoly))
}

///|
test "domainmatrix: structural helper parity" {
  let diag_case = @sympolys.domain_matrix_from_ints(
    [[1, 0], [0, 4]],
    Domain::ZZ,
  )
  let ours_diag = dm_coeffs_text(diag_case.diagonal())
  let oracle_diag = domainmatrix_diagonal([[1, 0], [0, 4]], "ZZ")
  assert_eq(dm_trim(ours_diag), dm_trim(oracle_diag))

  let ours_flat = dm_coeffs_text(diag_case.to_list_flat())
  let oracle_flat = domainmatrix_to_list_flat([[1, 0], [0, 4]], "ZZ")
  assert_eq(dm_trim(ours_flat), dm_trim(oracle_flat))

  let ours_from_flat = DomainMatrix::from_list_flat(
    diag_case.to_list_flat(),
    (2, 2),
    Domain::ZZ,
  )
  let oracle_from_flat = domainmatrix_from_list_flat([[1, 0], [0, 4]], "ZZ")
  assert_eq(
    dm_trim(ours_from_flat.to_matrix_string()),
    dm_trim(oracle_from_flat),
  )

  let flat_nz = diag_case.to_flat_nz()
  let roundtrip_flat_nz = diag_case.from_flat_nz(
    flat_nz.0,
    flat_nz.1,
    Domain::ZZ,
  )
  assert_eq(
    dm_trim(roundtrip_flat_nz.to_matrix_string()),
    dm_trim(diag_case.to_matrix_string()),
  )
  assert_eq(dm_coeffs_text(flat_nz.0), "[1, 0, 0, 4]")

  let ours_dod = dm_dod_text(diag_case.to_dod())
  let oracle_dod = domainmatrix_to_dod([[1, 0], [0, 4]], "ZZ")
  assert_eq(dm_trim(ours_dod), dm_trim(oracle_dod))
  let from_dod = diag_case.from_dod_like(diag_case.to_dod())
  let oracle_from_dod = domainmatrix_from_dod_roundtrip([[1, 0], [0, 4]], "ZZ")
  assert_eq(dm_trim(from_dod.to_matrix_string()), dm_trim(oracle_from_dod))

  let ours_dok = dm_dok_text(diag_case.to_dok())
  let oracle_dok = domainmatrix_to_dok([[1, 0], [0, 4]], "ZZ")
  assert_eq(dm_trim(ours_dok), dm_trim(oracle_dok))
  let from_dok = DomainMatrix::from_dok(diag_case.to_dok(), (2, 2), Domain::ZZ)
  let oracle_from_dok = domainmatrix_from_dok_roundtrip([[1, 0], [0, 4]], "ZZ")
  assert_eq(dm_trim(from_dok.to_matrix_string()), dm_trim(oracle_from_dok))

  let two_zz = @sympolys.fe_from_int(2, Domain::ZZ)
  let applied = diag_case.applyfunc(fn(value : FieldElem) raise PolyError {
    @sympolys.fe_mul(value, two_zz)
  })
  assert_eq(
    dm_trim(applied.to_matrix_string()),
    dm_trim("Matrix([[2, 0], [0, 8]])"),
  )
  assert_true(diag_case.is_square())

  assert_eq(diag_case.nnz(), domainmatrix_nnz([[1, 0], [0, 4]], "ZZ"))

  let pow_case = @sympolys.domain_matrix_from_ints([[1, 1], [0, 1]], Domain::ZZ)
  let ours_pow = pow_case.pow(3).to_matrix_string()
  let oracle_pow = domainmatrix_pow([[1, 1], [0, 1]], "ZZ", 3)
  assert_eq(dm_trim(ours_pow), dm_trim(oracle_pow))

  let block_rows = [[6, -1, 0, 0], [9, 12, 0, 0], [0, 0, 1, 2], [0, 0, 5, 6]]
  let block = @sympolys.domain_matrix_from_ints(block_rows, Domain::ZZ)
  let ours_scc = block.scc().to_string()
  let oracle_scc = domainmatrix_scc(block_rows, "ZZ")
  assert_eq(dm_trim(ours_scc), dm_trim(oracle_scc))

  let ours_blocks = block.charpoly_factor_blocks().to_string()
  let oracle_blocks = domainmatrix_charpoly_factor_blocks(block_rows, "ZZ")
  assert_eq(dm_trim(ours_blocks), dm_trim(oracle_blocks))

  let ours_factor_list = dm_factor_list_text(block.charpoly_factor_list())
  let oracle_factor_list = domainmatrix_charpoly_factor_list(block_rows, "ZZ")
  assert_eq(dm_trim(ours_factor_list), dm_trim(oracle_factor_list))

  let lattice_rows = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  let lattice = @sympolys.domain_matrix_from_ints(lattice_rows, Domain::ZZ)
  let reduced = lattice.lll()
  let hnf_orig = matrix_hnf_code(lattice_rows)
  let hnf_reduced = matrix_hnf_code(dm_to_int_rows(reduced))
  assert_eq(hnf_orig, hnf_reduced)
  let lll_transform = lattice.lll_transform()
  let recomposed = lll_transform.1.matmul(lattice).to_matrix_string()
  assert_eq(dm_trim(recomposed), dm_trim(lll_transform.0.to_matrix_string()))
  let hnf_transformed = matrix_hnf_code(dm_to_int_rows(lll_transform.0))
  assert_eq(hnf_orig, hnf_transformed)
}

///|
test "domainmatrix: constructor, accessors, slicing, and unify_eq" {
  let rows = [
    [
      @sympolys.fe_from_int(1, Domain::ZZ),
      @sympolys.fe_from_int(2, Domain::ZZ),
      @sympolys.fe_from_int(3, Domain::ZZ),
    ],
    [
      @sympolys.fe_from_int(4, Domain::ZZ),
      @sympolys.fe_from_int(5, Domain::ZZ),
      @sympolys.fe_from_int(6, Domain::ZZ),
    ],
    [
      @sympolys.fe_from_int(7, Domain::ZZ),
      @sympolys.fe_from_int(8, Domain::ZZ),
      @sympolys.fe_from_int(9, Domain::ZZ),
    ],
  ]
  let a = DomainMatrix::from_list(rows, Domain::ZZ)
  assert_eq(a.getitem(1, -2).to_string(), "5")
  assert_eq(a.extract([-1], [0]).to_matrix_string(), "Matrix([[7]])")
  let slice = a.extract_slice(
    row_start=Some(1),
    row_stop=Some(3),
    col_stop=Some(-2),
  )
  assert_eq(slice.to_matrix_string(), "Matrix([[4], [7]])")
  let reversed = a.extract_slice(row_step=-1)
  assert_eq(
    reversed.to_matrix_string(),
    "Matrix([[7, 8, 9], [4, 5, 6], [1, 2, 3]])",
  )
  let updated = a.setitem(-1, -1, @sympolys.fe_from_int(10, Domain::ZZ))
  assert_eq(updated.getitem(-1, -1).to_string(), "10")
  assert_eq(a.getitem(-1, -1).to_string(), "9")
  assert_true(a.unify_eq(a.convert_to(Domain::QQ)))
  assert_true(
    !a.unify_eq(@sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)),
  )
}

///|
test "domainmatrix: format-preserving copy convert_to and unify parity" {
  let sparse = @sympolys.domain_matrix_from_ints([[0, 1], [2, 0]], Domain::ZZ).to_sparse()
  let copied = sparse.copy()
  assert_eq(
    dm_trim(dm_summary(copied)),
    dm_trim("Matrix([[0, 1], [2, 0]])@ZZ|sparse"),
  )

  let ours_convert = dm_summary(sparse.convert_to(Domain::QQ))
  let oracle_convert = domainmatrix_convert_to_summary(
    [[0, 1], [2, 0]],
    "ZZ",
    "QQ",
    fmt="sparse",
  )
  assert_eq(dm_trim(ours_convert), dm_trim(oracle_convert))

  let dense_q = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let unified = sparse.unify(dense_q)
  let ours_unify = "\{dm_summary(unified.0)}||\{dm_summary(unified.1)}"
  let oracle_unify = domainmatrix_unify_summary(
    [[0, 1], [2, 0]],
    "ZZ",
    "sparse",
    [[1, 2], [3, 4]],
    "QQ",
    "dense",
  )
  assert_eq(dm_trim(ours_unify), dm_trim(oracle_unify))

  let unified_dense = sparse.unify(dense_q, fmt="dense")
  let ours_unify_dense = "\{dm_summary(unified_dense.0)}||\{dm_summary(unified_dense.1)}"
  let oracle_unify_dense = domainmatrix_unify_summary(
    [[0, 1], [2, 0]],
    "ZZ",
    "sparse",
    [[1, 2], [3, 4]],
    "QQ",
    "dense",
    fmt="dense",
  )
  assert_eq(dm_trim(ours_unify_dense), dm_trim(oracle_unify_dense))
}

///|
test "domainmatrix: direct format checks and stack semantics" {
  let sparse = @sympolys.domain_matrix_from_ints([[0, 1], [2, 0]], Domain::ZZ).to_sparse()
  let dense = @sympolys.domain_matrix_from_ints([[1, 0], [0, 3]], Domain::ZZ)

  assert_true((try? sparse.add(dense)) is Err(PolyError::DomainMismatch))
  assert_true((try? sparse.sub(dense)) is Err(PolyError::DomainMismatch))
  assert_true(
    (try? sparse.mul_elementwise(dense)) is Err(PolyError::DomainMismatch),
  )

  let sparse_sum = sparse.add(dense.to_sparse())
  assert_eq(
    dm_trim(dm_summary(sparse_sum)),
    dm_trim("Matrix([[1, 1], [2, 3]])@ZZ|sparse"),
  )
  assert_eq(dm_fmt(sparse.transpose()), "sparse")
  assert_eq(dm_fmt(sparse.extract([0, 1], [0])), "sparse")

  let dense_q = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let ours_hstack = dm_summary(sparse.hstack(dense_q))
  let oracle_hstack = domainmatrix_hstack_summary(
    [[0, 1], [2, 0]],
    "ZZ",
    "sparse",
    [[1, 2], [3, 4]],
    "QQ",
    "dense",
  )
  assert_eq(dm_trim(ours_hstack), dm_trim(oracle_hstack))

  let ours_vstack = dm_summary(sparse.vstack(dense_q))
  let oracle_vstack = domainmatrix_vstack_summary(
    [[0, 1], [2, 0]],
    "ZZ",
    "sparse",
    [[1, 2], [3, 4]],
    "QQ",
    "dense",
  )
  assert_eq(dm_trim(ours_vstack), dm_trim(oracle_vstack))
}

///|
test "domainmatrix: truediv parity and scalar fast paths" {
  let sparse_zz = @sympolys.domain_matrix_from_ints(
    [[1, 2], [3, 4]],
    Domain::ZZ,
  ).to_sparse()

  let ours_half = dm_summary(
    sparse_zz.truediv(@sympolys.domain_scalar_from_int(2, Domain::ZZ)),
  )
  let oracle_half = domainmatrix_truediv_summary(
    [[1, 2], [3, 4]],
    "ZZ",
    "2",
    fmt="sparse",
  )
  assert_eq(dm_trim(ours_half), dm_trim(oracle_half))

  let sparse_qq = sparse_zz.to_field()
  let two_thirds = @sympolys.domain_scalar_new(dm_rat(2, 3), Domain::QQ)
  let ours_two_thirds = dm_summary(sparse_qq.truediv(two_thirds))
  let oracle_two_thirds = domainmatrix_truediv_summary(
    [[1, 2], [3, 4]],
    "QQ",
    "2/3",
    fmt="sparse",
  )
  assert_eq(dm_trim(ours_two_thirds), dm_trim(oracle_two_thirds))

  assert_eq(
    dm_trim(
      dm_summary(sparse_zz._scalarmul(@sympolys.fe_from_int(1, Domain::ZZ))),
    ),
    dm_trim(dm_summary(sparse_zz)),
  )
  assert_eq(
    dm_trim(
      dm_summary(sparse_zz._scalarmul(@sympolys.fe_from_int(0, Domain::ZZ))),
    ),
    dm_trim("Matrix([[0, 0], [0, 0]])@ZZ|sparse"),
  )
  assert_true(
    (try? sparse_zz.truediv(@sympolys.domain_scalar_from_int(0, Domain::ZZ)))
    is Err(PolyError::DivisionByZero),
  )
}

///|
test "domainmatrix: sympy-style constructor and conversion parity" {
  let expr_rows : MatrixExpr = [
    [@symcore.rational_from_ints(1, 2), @symcore.int(2)],
    [@symcore.int(3), @symcore.int(4)],
  ]
  let ours_from_list = DomainMatrix::from_list_sympy(2, 2, expr_rows)
  let oracle_from_list = domainmatrix_from_list_sympy_expr([
    ["1/2", "2"],
    ["3", "4"],
  ])
  assert_eq(dm_trim(dm_summary(ours_from_list)), dm_trim(oracle_from_list))

  let ours_from_matrix = DomainMatrix::from_Matrix(expr_rows)
  let oracle_from_matrix = domainmatrix_from_matrix_expr(
    [["1/2", "2"], ["3", "4"]],
    fmt="sparse",
  )
  assert_eq(dm_trim(dm_summary(ours_from_matrix)), dm_trim(oracle_from_matrix))

  let choose = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ).choose_domain(
    field=true,
  )
  let oracle_choose = domainmatrix_choose_domain(
    [[1, 2], [3, 4]],
    "ZZ",
    field=true,
  )
  assert_eq(dm_trim(dm_summary(choose)), dm_trim(oracle_choose))

  assert_eq(
    dm_trim(dm_expr_matrix_text(ours_from_list.to_Matrix())),
    dm_trim("Matrix([[1/2, 2], [3, 4]])"),
  )
  assert_eq(
    dm_trim(dm_expr_matrix_text(ours_from_list.to_sympy())),
    dm_trim("Matrix([[1/2, 2], [3, 4]])"),
  )
  assert_eq(@symprint.to_string(ours_from_list.getitem_sympy(0, 0)), "1/2")

  let ddm_dm = ours_from_list.to_ddm().to_domain_matrix()
  let ddm_rep = DomainMatrix::from_rep(
    ddm_dm.rep,
    ddm_dm.shape(),
    ddm_dm.domain,
  )
  assert_eq(
    dm_trim(ddm_rep.to_matrix_string()),
    dm_trim(ours_from_list.to_matrix_string()),
  )
  let sdm_dm = ours_from_matrix.to_sdm().to_domain_matrix()
  let sdm_rep = DomainMatrix::from_rep(
    sdm_dm.rep,
    sdm_dm.shape(),
    sdm_dm.domain,
  )
  assert_eq(
    dm_trim(sdm_rep.to_matrix_string()),
    dm_trim(ours_from_matrix.to_matrix_string()),
  )
  assert_eq(dm_trim(ours_from_matrix.to_dfm().to_string()), "[[1/2,2],[3,4]]")
}

///|
test "domainmatrix: content primitive cancel and charpoly-solve parity" {
  let qq_rows = [["1/2", "3/4"]]
  let qq = @sympolys.domain_matrix_from_dense(
    [[dm_rat(1, 2), dm_rat(3, 4)]],
    Domain::QQ,
  )
  let ours_content = @sympolys.fe_to_string(qq.content())
  let oracle_content = domainmatrix_content_expr(qq_rows, "QQ")
  assert_eq(dm_trim(ours_content), dm_trim(oracle_content))

  let primitive = qq.primitive()
  let ours_primitive = "\{@sympolys.fe_to_string(primitive.0)}||\{primitive.1.to_matrix_string()}"
  let oracle_primitive = domainmatrix_primitive_expr(qq_rows, "QQ")
  assert_eq(dm_trim(ours_primitive), dm_trim(oracle_primitive))

  let zz_rows = [["4", "6"]]
  let zz = @sympolys.domain_matrix_from_ints([[4, 6]], Domain::ZZ)
  let ours_cancel = zz.cancel_denom(@sympolys.fe_from_int(12, Domain::ZZ))
  let ours_cancel_text = "\{ours_cancel.0.to_matrix_string()}||\{@sympolys.fe_to_string(ours_cancel.1)}"
  let oracle_cancel = domainmatrix_cancel_denom_expr(zz_rows, "12", "ZZ")
  assert_eq(dm_trim(ours_cancel_text), dm_trim(oracle_cancel))

  let ours_cancel_elt = zz.cancel_denom_elementwise(
    @sympolys.fe_from_int(12, Domain::ZZ),
  )
  let ours_cancel_elt_text = "\{ours_cancel_elt.0.to_matrix_string()}||\{ours_cancel_elt.1.to_matrix_string()}"
  let oracle_cancel_elt = domainmatrix_cancel_denom_elementwise_expr(
    zz_rows, "12", "ZZ",
  )
  assert_eq(dm_trim(ours_cancel_elt_text), dm_trim(oracle_cancel_elt))

  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let b = @sympolys.domain_matrix_from_ints([[5], [6]], Domain::ZZ)
  let adj_poly_det = a.adj_poly_det()
  let ours_adj_poly_det = "\{dm_coeffs_text(adj_poly_det.0)}||\{@sympolys.fe_to_string(adj_poly_det.1)}"
  let oracle_adj_poly_det = domainmatrix_adj_poly_det([[1, 2], [3, 4]], "ZZ")
  assert_eq(dm_trim(ours_adj_poly_det), dm_trim(oracle_adj_poly_det))

  let coeffs = [
    @sympolys.fe_from_int(1, Domain::ZZ),
    @sympolys.fe_from_int(2, Domain::ZZ),
    @sympolys.fe_from_int(3, Domain::ZZ),
  ]
  let ours_eval_poly = a.eval_poly(coeffs).to_matrix_string()
  let oracle_eval_poly = domainmatrix_eval_poly(
    [[1, 2], [3, 4]],
    ["1", "2", "3"],
    "ZZ",
  )
  assert_eq(dm_trim(ours_eval_poly), dm_trim(oracle_eval_poly))

  let ours_eval_poly_mul = a.eval_poly_mul(coeffs, b).to_matrix_string()
  let oracle_eval_poly_mul = domainmatrix_eval_poly_mul(
    [[1, 2], [3, 4]],
    ["1", "2", "3"],
    [[5], [6]],
    "ZZ",
  )
  assert_eq(dm_trim(ours_eval_poly_mul), dm_trim(oracle_eval_poly_mul))

  let ours_solve_charpoly = a.solve_den_charpoly(b)
  let ours_solve_charpoly_text = "\{ours_solve_charpoly.0.to_matrix_string()}||\{@sympolys.fe_to_string(ours_solve_charpoly.1)}"
  let oracle_solve_charpoly = domainmatrix_solve_den_charpoly(
    [[1, 2], [3, 4]],
    [[5], [6]],
    "ZZ",
  )
  assert_eq(dm_trim(ours_solve_charpoly_text), dm_trim(oracle_solve_charpoly))
}

///|
test "domainmatrix: adjugate, adj_det, inv_den, solve_den parity over ZZ" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let b = @sympolys.domain_matrix_from_ints([[5], [6]], Domain::ZZ)
  let adj_det = a.adj_det()
  let inv_den = a.inv_den()
  let solve_den = a.solve_den(b)

  let ours_adjugate = a.adjugate().to_matrix_string()
  let ours_adj_det = "\{adj_det.0.to_matrix_string()}||\{@sympolys.fe_to_string(adj_det.1)}"
  let ours_inv_den = "\{inv_den.0.to_matrix_string()}||\{@sympolys.fe_to_string(inv_den.1)}"
  let ours_solve_den = "\{solve_den.0.to_matrix_string()}||\{@sympolys.fe_to_string(solve_den.1)}"

  let oracle_adjugate = domainmatrix_adjugate([[1, 2], [3, 4]], "ZZ")
  let oracle_adj_det = domainmatrix_adj_det([[1, 2], [3, 4]], "ZZ")
  let oracle_inv_den = domainmatrix_inv_den([[1, 2], [3, 4]], "ZZ")
  let oracle_solve_den = domainmatrix_solve_den(
    [[1, 2], [3, 4]],
    [[5], [6]],
    "ZZ",
  )

  assert_eq(dm_trim(ours_adjugate), dm_trim(oracle_adjugate))
  assert_eq(dm_trim(ours_adj_det), dm_trim(oracle_adj_det))
  assert_eq(dm_trim(ours_inv_den), dm_trim(oracle_inv_den))
  assert_eq(dm_trim(ours_solve_den), dm_trim(oracle_solve_den))
}

///|
test "domainmatrix: smith normal form parity over ZZ" {
  let rows = [[12, 6, 4], [3, 9, 6], [2, 16, 14]]
  let a = @sympolys.domain_matrix_from_ints(rows, Domain::ZZ)
  let smf = a.smith_normal_form()
  let decomp = a.smith_normal_decomp()
  let ours_invs = dm_field_tuple_text(a.invariant_factors())
  let ours_smf = smf.to_matrix_string()
  let oracle_invs = domainmatrix_invariant_factors(rows, "ZZ")
  let oracle_smf = domainmatrix_smith_normal_form(rows, "ZZ")
  assert_eq(ours_invs, oracle_invs)
  assert_eq(dm_trim(ours_smf), dm_trim(oracle_smf))
  assert_true(smf.is_smith_normal_form())
  assert_true(domainmatrix_is_smith_normal_form(dm_to_int_rows(smf), "ZZ"))
  let recomposed = decomp.1.matmul(a).matmul(decomp.2).to_matrix_string()
  assert_eq(dm_trim(recomposed), dm_trim(ours_smf))
}

///|
test "domainmatrix: rational dom_eigenvects parity over QQ" {
  let rational = @sympolys.domain_matrix_from_ints([[1, 0], [0, 2]], Domain::QQ)
  let rational_text = dm_dom_eigenvects_text(rational.dom_eigenvects())
  let oracle_rational = domainmatrix_dom_eigenvects_summary(
    [[1, 0], [0, 2]],
    "QQ",
  )
  assert_eq(dm_trim(rational_text), dm_trim(oracle_rational))
}

///|
test "domainmatrix: algebraic dom_eigenvects parity over QQ" {
  let algebraic = @sympolys.domain_matrix_from_ints(
    [[0, 2], [1, 0]],
    Domain::QQ,
  )
  let algebraic_text = dm_dom_eigenvects_text(algebraic.dom_eigenvects())
  let oracle_algebraic = domainmatrix_dom_eigenvects_summary(
    [[0, 2], [1, 0]],
    "QQ",
  )
  assert_eq(dm_trim(algebraic_text), dm_trim(oracle_algebraic))
}

///|
test "domainmatrix: _solve and particular parity over QQ" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [2, 4]], Domain::QQ)
  let b = @sympolys.domain_matrix_from_ints([[1], [2]], Domain::QQ)
  let ours = dm_solve_summary(a._solve(b))
  let oracle = domainmatrix_internal_solve_summary(
    [[1, 2], [2, 4]],
    [[1], [2]],
    "QQ",
  )
  assert_eq(dm_trim(ours), dm_trim(oracle))

  let (rref_aug, pivots) = a.hstack(b).rref()
  let particular = rref_aug.particular(pivots~).to_matrix_string()
  assert_eq(particular, "Matrix([[1, 0]])")
}

///|
test "domainmatrix: row/column/nullspace parity over QQ" {
  let rows = [[1, 2, 3], [2, 4, 6], [1, 1, 1]]
  let a = @sympolys.domain_matrix_from_ints(rows, Domain::QQ)

  let ours_rowspace = a.rowspace().to_matrix_string()
  let ours_columnspace = a.columnspace().to_matrix_string()
  let ours_nullspace = a.nullspace().to_matrix_string()

  let oracle_rowspace = domainmatrix_rowspace(rows, "QQ")
  let oracle_columnspace = domainmatrix_columnspace(rows, "QQ")
  let oracle_nullspace = domainmatrix_nullspace(rows, "QQ")

  assert_eq(dm_trim(ours_rowspace), dm_trim(oracle_rowspace))
  assert_eq(dm_trim(ours_columnspace), dm_trim(oracle_columnspace))
  assert_eq(dm_trim(ours_nullspace), dm_trim(oracle_nullspace))
}

///|
test "domainmatrix: non-field nullspace parity over ZZ" {
  let rows = [[6, -3], [4, -2]]
  let a = @sympolys.domain_matrix_from_ints(rows, Domain::ZZ)
  let ours = a.nullspace().to_matrix_string()
  let oracle = domainmatrix_nullspace(rows, "ZZ")
  assert_eq(dm_trim(ours), dm_trim(oracle))
}

///|
test "domainmatrix: solve_den_rref parity on rectangular ZZ system" {
  let a_rows = [[2, 0], [0, 3], [2, 3]]
  let b_rows = [[1], [1], [2]]
  let a = @sympolys.domain_matrix_from_ints(a_rows, Domain::ZZ)
  let b = @sympolys.domain_matrix_from_ints(b_rows, Domain::ZZ)
  let ours = a.solve_den_rref(b)
  let ours_text = "\{ours.0.to_matrix_string()}||\{@sympolys.fe_to_string(ours.1)}"
  let oracle = domainmatrix_solve_den_rref(a_rows, b_rows, "ZZ")
  assert_eq(dm_trim(ours_text), dm_trim(oracle))
}

///|
test "domainmatrix: solve_den_rref rejects non-unique systems" {
  let under = @sympolys.domain_matrix_from_ints([[1, 1]], Domain::ZZ)
  let under_rhs = @sympolys.domain_matrix_from_ints([[1]], Domain::ZZ)
  assert_true((try? under.solve_den_rref(under_rhs)) is Err(_))

  let inconsistent = @sympolys.domain_matrix_from_ints(
    [[1, 1], [1, 1]],
    Domain::ZZ,
  )
  let inconsistent_rhs = @sympolys.domain_matrix_from_ints(
    [[1], [2]],
    Domain::ZZ,
  )
  assert_true((try? inconsistent.solve_den_rref(inconsistent_rhs)) is Err(_))
}

///|
test "domainmatrix: elimination does not mutate the input matrix" {
  let a = @sympolys.domain_matrix_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let _ = a.det()
  let _ = a.rref()
  let _ = a.rref_den()
  let _ = a.inv()
  assert_eq(dm_trim(a.to_matrix_string()), dm_trim("Matrix([[1, 2], [3, 5]])"))
}
