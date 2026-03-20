///|
fn mx_trim(s : String) -> String {
  s
  .replace_all(old=" ", new="")
  .replace_all(old="\n", new="")
  .replace_all(old=".0", new="")
}

///|
fn mx_expr_norm(e : @symcore.Expr) -> String {
  (try! sympy_normalize(@symprint.to_string(e)).trim().to_string()).replace_all(
    old=" ",
    new="",
  )
}

///|
fn basis_to_sympy_text(basis : Array[Array[FieldElem]]) -> String {
  let cols : Array[String] = Array::new()
  for vec in basis {
    let rows : Array[String] = Array::new()
    for v in vec {
      rows.push("[\{@sympolys.fe_to_string(v)}]")
    }
    let rows_joined = rows.join(",")
    cols.push("Matrix([\{rows_joined}])")
  }
  let cols_joined = cols.join(",")
  "[\{cols_joined}]"
}

///|
fn basis_rows_to_matrix_text(basis : Array[Array[FieldElem]]) -> String {
  let rows : Array[String] = Array::new()
  for vec in basis {
    let cells = vec.map(fe_to_string).join(", ")
    rows.push("[\{cells}]")
  }
  let joined = rows.join(", ")
  "Matrix([\{joined}])"
}

///|
fn swap_text(swaps : Array[(Int, Int)]) -> String {
  let parts : Array[String] = Array::new()
  for swap in swaps {
    parts.push("(\{swap.0}, \{swap.1})")
  }
  let joined = parts.join(", ")
  "[\{joined}]"
}

///|
fn coeffs_text(coeffs : Array[FieldElem]) -> String {
  let joined = coeffs.map(fe_to_string).join(", ")
  "[\{joined}]"
}

///|
fn field_tuple_text(values : Array[FieldElem]) -> String {
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
fn sdm_summary_like_oracle(sdm : SDM) -> String raise PolyError {
  "\{sdm.to_ddm().to_string()}@\{@sympolys.domain_to_sympy_string(sdm.domain())}|sparse"
}

///|
fn ddm_to_int_rows(ddm : DDM) -> Array[Array[Int]] raise PolyError {
  let rows = ddm.to_list()
  let out : Array[Array[Int]] = Array::new()
  for row in rows {
    let out_row : Array[Int] = Array::new()
    for v in row {
      let q = @sympolys.fe_expect_rational(v)
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
fn ddm_rat(num : Int, den : Int) -> FieldElem raise PolyError {
  @sympolys.fe_from_rational(
    try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den)),
    Domain::QQ,
  )
}

///|
fn ddm_clear_denoms_repr(
  den : DomainScalar,
  num : DDM,
) -> String raise PolyError {
  "\{den.to_string()}@\{@sympolys.domain_to_sympy_string(den.domain)}||Matrix(\{num.to_string()})@\{@sympolys.domain_to_sympy_string(num.domain())}"
}

///|
fn ddm_clear_denoms_rowwise_repr(
  den : DDM,
  num : DDM,
) -> String raise PolyError {
  "\{den.to_domain_matrix().to_matrix_string()}@\{@sympolys.domain_to_sympy_string(den.domain())}||Matrix(\{num.to_string()})@\{@sympolys.domain_to_sympy_string(num.domain())}"
}

///|
test "matrices: DDM add/matmul/scalarmul/det/rref parity" {
  let a = @sympolys.ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = @sympolys.ddm_from_ints([[5, 6], [7, 8]], Domain::QQ)
  let two = @sympolys.fe_from_int(2, Domain::QQ)

  let ours_add = a.add(b).to_string()
  let ours_matmul = a.matmul(b).to_string()
  let ours_mul = a.mul(two).to_string()
  let ours_det = @sympolys.fe_to_string(a.det())
  let (r, pivots) = a.rref()
  let pivot_text = pivots.map(i => i.to_string()).join(",")
  let ours_rref = "\{r.to_string()}||[\{pivot_text}]"

  let oracle_add = ddm_add(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_matmul = ddm_matmul(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_mul = ddm_mul([[1, 2], [3, 4]], 2, "QQ")
  let oracle_det = ddm_det([[1, 2], [3, 4]], "QQ")
  let oracle_rref = ddm_rref([[1, 2], [3, 4]], "QQ")

  assert_eq(mx_trim(ours_add), mx_trim(oracle_add))
  assert_eq(mx_trim(ours_matmul), mx_trim(oracle_matmul))
  assert_eq(mx_trim(ours_mul), mx_trim(oracle_mul))
  assert_eq(mx_trim(ours_det), mx_trim(oracle_det))
  assert_eq(mx_trim(ours_rref), mx_trim(oracle_rref))
}

///|
test "matrices: DDM rank/inv/nullspace parity" {
  let rank_case = @sympolys.ddm_from_ints([[1, 2], [2, 4]], Domain::QQ)
  assert_eq(rank_case.rank(), ddm_rank([[1, 2], [2, 4]], "QQ"))

  let inv_case = @sympolys.ddm_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let ours_inv = "Matrix(\{inv_case.inv().to_string()})"
  let oracle_inv = ddm_inv([[1, 2], [3, 5]], "QQ")
  assert_eq(mx_trim(ours_inv), mx_trim(oracle_inv))

  let ns_case = @sympolys.ddm_from_ints([[1, 2, 3], [2, 4, 6]], Domain::QQ)
  let ours_ns = basis_to_sympy_text(ns_case.nullspace())
  let oracle_ns = ddm_nullspace([[1, 2, 3], [2, 4, 6]], "QQ")
  assert_eq(mx_trim(ours_ns), mx_trim(oracle_ns))
}

///|
test "matrices: DDM exact denominator parity" {
  let qq_rows = [
    [ddm_rat(1, 2), ddm_rat(1, 3), ddm_rat(1, 4)],
    [ddm_rat(1, 5), ddm_rat(1, 6), ddm_rat(1, 7)],
  ]
  let qq = @sympolys.ddm_from_dense(qq_rows, Domain::QQ)
  let clear = qq.clear_denoms()
  let clear_rowwise = qq.clear_denoms_rowwise()

  let ours_clear = ddm_clear_denoms_repr(clear.0, clear.1)
  let ours_clear_rowwise = ddm_clear_denoms_rowwise_repr(
    clear_rowwise.0,
    clear_rowwise.1,
  )

  let expr_rows = [["1/2", "1/3", "1/4"], ["1/5", "1/6", "1/7"]]
  let oracle_clear = domainmatrix_clear_denoms_expr(
    expr_rows, "QQ",
  )
  let oracle_clear_rowwise = domainmatrix_clear_denoms_rowwise_expr(
    expr_rows, "QQ",
  )

  assert_eq(mx_trim(ours_clear), mx_trim(oracle_clear))
  assert_eq(mx_trim(ours_clear_rowwise), mx_trim(oracle_clear_rowwise))

  let zz = @sympolys.ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let rhs = @sympolys.ddm_from_ints([[5], [6]], Domain::ZZ)
  let adj_det = zz.adj_det()
  let inv_den = zz.inv_den()
  let solve_den = zz.solve_den(rhs)

  let ours_adjugate = "Matrix(\{zz.adjugate().to_string()})"
  let ours_adj_det = "Matrix(\{adj_det.0.to_string()})||\{@sympolys.fe_to_string(adj_det.1)}"
  let ours_inv_den = "Matrix(\{inv_den.0.to_string()})||\{@sympolys.fe_to_string(inv_den.1)}"
  let ours_solve_den = "Matrix(\{solve_den.0.to_string()})||\{@sympolys.fe_to_string(solve_den.1)}"

  let oracle_adjugate = domainmatrix_adjugate(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  let oracle_adj_det = domainmatrix_adj_det([[1, 2], [3, 4]], "ZZ")
  let oracle_inv_den = domainmatrix_inv_den([[1, 2], [3, 4]], "ZZ")
  let oracle_solve_den = domainmatrix_solve_den(
    [[1, 2], [3, 4]],
    [[5], [6]],
    "ZZ",
  )

  assert_eq(mx_trim(ours_adjugate), mx_trim(oracle_adjugate))
  assert_eq(mx_trim(ours_adj_det), mx_trim(oracle_adj_det))
  assert_eq(mx_trim(ours_inv_den), mx_trim(oracle_inv_den))
  assert_eq(mx_trim(ours_solve_den), mx_trim(oracle_solve_den))
}

///|
test "matrices: DDM rref_den/nullspace/solve_den_rref parity" {
  let rows = [[1, 2, 3], [4, 5, 6]]
  let a = @sympolys.ddm_from_ints(rows, Domain::ZZ)
  let rref_den = a.rref_den(rref_method="FF")
  let pivots = rref_den.2.map(i => i.to_string()).join(",")
  let ours_rref_den = "Matrix(\{rref_den.0.to_string()})||\{@sympolys.fe_to_string(rref_den.1)}||[\{pivots}]"
  let oracle_rref_den = domainmatrix_rref_den(
    rows,
    "ZZ",
    rref_method="FF",
  )
  assert_eq(mx_trim(ours_rref_den), mx_trim(oracle_rref_den))

  let zz_ns = @sympolys.ddm_from_ints([[6, -3], [4, -2]], Domain::ZZ)
  let ours_ns = basis_rows_to_matrix_text(zz_ns.nullspace())
  let oracle_ns = domainmatrix_nullspace([[6, -3], [4, -2]], "ZZ")
  assert_eq(mx_trim(ours_ns), mx_trim(oracle_ns))

  let sys_a = @sympolys.ddm_from_ints([[2, 0], [0, 3], [2, 3]], Domain::ZZ)
  let sys_b = @sympolys.ddm_from_ints([[1], [1], [2]], Domain::ZZ)
  let ours_solve = sys_a.solve_den_rref(sys_b)
  let ours_solve_text = "Matrix(\{ours_solve.0.to_string()})||\{@sympolys.fe_to_string(ours_solve.1)}"
  let oracle_solve = domainmatrix_solve_den_rref(
    [[2, 0], [0, 3], [2, 3]],
    [[1], [1], [2]],
    "ZZ",
  )
  assert_eq(mx_trim(ours_solve_text), mx_trim(oracle_solve))
}

///|
test "matrices: DDM lu/lu_solve/charpoly parity and qr/fflu invariants" {
  let lu_case = @sympolys.ddm_from_ints([[0, 1], [1, 1]], Domain::QQ)
  let lu = lu_case.lu()
  let ours_lu = "\{lu.0.to_domain_matrix().to_matrix_string()}||\{lu.1.to_domain_matrix().to_matrix_string()}||\{swap_text(lu.2)}"
  let oracle_lu = domainmatrix_lu([[0, 1], [1, 1]], "QQ")
  assert_eq(mx_trim(ours_lu), mx_trim(oracle_lu))

  let qr_case = @sympolys.ddm_from_ints([[1, 2], [3, 4], [5, 6]], Domain::QQ)
  let qr = qr_case.qr()
  let qr_left = qr.0.to_domain_matrix()
  let qr_right = qr.1.to_domain_matrix()
  let recomposed = qr_left.matmul(qr_right).to_matrix_string()
  assert_eq(mx_trim(recomposed), mx_trim(qr_case.to_domain_matrix().to_matrix_string()))
  assert_true(dm_is_diagonal(qr_left.transpose().matmul(qr_left)))
  assert_true(dm_is_upper(qr_right))

  let solve_case = @sympolys.ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let rhs = @sympolys.ddm_from_ints([[1], [0]], Domain::QQ)
  let ours_lu_solve = solve_case
    .lu_solve(rhs)
    .to_domain_matrix()
    .to_matrix_string()
  let oracle_lu_solve = domainmatrix_lu_solve(
    [[1, 2], [3, 4]],
    [[1], [0]],
    "QQ",
  )
  assert_eq(mx_trim(ours_lu_solve), mx_trim(oracle_lu_solve))

  let zz = @sympolys.ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let fflu = zz.fflu()
  let fflu_left = fflu.1
    .to_domain_matrix()
    .to_field()
    .matmul(fflu.2.to_domain_matrix().to_field().inv())
    .matmul(fflu.3.to_domain_matrix().to_field())
  let fflu_right = fflu.0
    .to_domain_matrix()
    .to_field()
    .matmul(zz.to_domain_matrix().to_field())
  assert_eq(mx_trim(fflu_left.to_matrix_string()), mx_trim(fflu_right.to_matrix_string()))
  assert_true(dm_is_diagonal(fflu.2.to_domain_matrix()))
  assert_true(dm_is_upper(fflu.3.to_domain_matrix()))

  let ours_charpoly = coeffs_text(zz.charpoly())
  let oracle_charpoly = domainmatrix_charpoly(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  assert_eq(mx_trim(ours_charpoly), mx_trim(oracle_charpoly))
}

///|
test "matrices: DomainMatrix LLL and transform parity" {
  let rows = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  let a = @sympolys.ddm_from_ints(rows, Domain::ZZ)

  let reduced = a.lll()
  let hnf_orig = matrix_hnf_code(rows)
  let hnf_reduced = matrix_hnf_code(ddm_to_int_rows(reduced))
  assert_eq(hnf_orig, hnf_reduced)

  let (reduced2, transform) = a.lll_transform()
  let recomposed = transform.matmul(a).to_string()
  assert_eq(mx_trim(recomposed), mx_trim(reduced2.to_string()))
  let hnf_reduced2 = matrix_hnf_code(ddm_to_int_rows(reduced2))
  assert_eq(hnf_orig, hnf_reduced2)
}

///|
test "matrices: HNF parity on integer cases" {
  let cases = [[[1, 0, 0], [0, 1, 0], [0, 0, 1]]]
  for rows in cases {
    let a = @sympolys.ddm_from_ints(rows, Domain::ZZ)
    let ours_rows = ddm_to_int_rows(a.hermite_normal_form())
    let oracle_code = matrix_hnf_code(rows)
    let ours_code = matrix_hnf_code(ours_rows)
    assert_eq(ours_code, oracle_code)
  }
}

///|
test "matrices: Smith normal form parity on integer cases" {
  let rows = [[12, 6, 4], [3, 9, 6], [2, 16, 14]]
  let a = @sympolys.ddm_from_ints(rows, Domain::ZZ)
  let smf = a.smith_normal_form()
  let decomp = a.smith_normal_decomp()
  let ours_invs = field_tuple_text(a.invariant_factors())
  let ours_smf = smf.to_domain_matrix().to_matrix_string()
  let oracle_invs = domainmatrix_invariant_factors(rows, "ZZ")
  let oracle_smf = domainmatrix_smith_normal_form(rows, "ZZ")
  assert_eq(ours_invs, oracle_invs)
  assert_eq(mx_trim(ours_smf), mx_trim(oracle_smf))
  assert_true(smf.is_smith_normal_form())
  let recomposed = decomp.1
    .matmul(a)
    .matmul(decomp.2)
    .to_domain_matrix()
    .to_matrix_string()
  assert_eq(mx_trim(recomposed), mx_trim(ours_smf))
}

///|
test "matrices: SDM add/matmul/scalarmul and dense conversion" {
  let two = @sympolys.fe_from_int(2, Domain::ZZ)
  let one = @sympolys.fe_from_int(1, Domain::ZZ)
  let three = @sympolys.fe_from_int(3, Domain::ZZ)
  let four = @sympolys.fe_from_int(4, Domain::ZZ)

  let s = @sympolys.sdm_from_entries(2, 2, [(0, 1, two), (1, 0, one)], Domain::ZZ)
  let t = @sympolys.sdm_from_entries(2, 2, [(0, 0, three), (1, 1, four)], Domain::ZZ)

  let add = s.add(t)
  let scaled = s.mul(two)
  let mul = s.matmul(t)
  let add_dense = add.to_dense().to_string()
  let scaled_dense = scaled.to_dense().to_string()
  let mul_dense = mul.to_dense().to_string()

  assert_eq(mx_trim(add_dense), "[[3,2],[1,4]]")
  assert_eq(mx_trim(scaled_dense), "[[0,4],[2,0]]")
  assert_eq(mx_trim(mul_dense), "[[0,8],[3,0]]")
}

///|
test "matrices: SDM rref_den and nullspace_from_rref parity" {
  let one = @sympolys.fe_from_int(1, Domain::ZZ)
  let two = @sympolys.fe_from_int(2, Domain::ZZ)
  let three = @sympolys.fe_from_int(3, Domain::ZZ)
  let four = @sympolys.fe_from_int(4, Domain::ZZ)
  let five = @sympolys.fe_from_int(5, Domain::ZZ)
  let six = @sympolys.fe_from_int(6, Domain::ZZ)
  let a = @sympolys.sdm_from_entries(
    2,
    3,
    [
      (0, 0, one),
      (0, 1, two),
      (0, 2, three),
      (1, 0, four),
      (1, 1, five),
      (1, 2, six),
    ],
    Domain::ZZ,
  )
  let rref_den = a.rref_den(rref_method="FF")
  let pivots = rref_den.2.map(i => i.to_string()).join(",")
  let ours_rref_den = "\{rref_den.0.to_dense().to_domain_matrix().to_matrix_string()}||\{@sympolys.fe_to_string(rref_den.1)}||[\{pivots}]"
  let oracle_rref_den = domainmatrix_rref_den(
    [[1, 2, 3], [4, 5, 6]],
    "ZZ",
    rref_method="FF",
  )
  assert_eq(mx_trim(ours_rref_den), mx_trim(oracle_rref_den))

  let ns_source = @sympolys.sdm_from_entries(
    2,
    2,
    [
      (0, 0, six),
      (0, 1, @sympolys.fe_from_int(-3, Domain::ZZ)),
      (1, 0, four),
      (1, 1, @sympolys.fe_from_int(-2, Domain::ZZ)),
    ],
    Domain::ZZ,
  )
  let (ns_basis, _) = ns_source.rref_den(rref_method="FF").0.nullspace_from_rref()
  let ours_ns = ns_basis.to_dense().to_domain_matrix().to_matrix_string()
  let oracle_ns = domainmatrix_nullspace([[6, -3], [4, -2]], "ZZ")
  assert_eq(mx_trim(ours_ns), mx_trim(oracle_ns))
}

///|
test "matrices: DDM and SDM particular wrappers" {
  let ddm_aug = @sympolys.ddm_from_ints([[1, 2, 1], [2, 4, 2]], Domain::QQ)
  let (ddm_rref, ddm_pivots) = ddm_aug.rref()
  let ddm_particular = ddm_rref
    .particular(pivots=ddm_pivots)
    .to_domain_matrix()
    .to_matrix_string()
  assert_eq(ddm_particular, "Matrix([[1, 0]])")

  let one = @sympolys.fe_from_int(1, Domain::QQ)
  let two = @sympolys.fe_from_int(2, Domain::QQ)
  let sdm_aug = @sympolys.sdm_from_entries(
    2,
    3,
    [
      (0, 0, one),
      (0, 1, two),
      (0, 2, one),
      (1, 0, two),
      (1, 1, @sympolys.fe_from_int(4, Domain::QQ)),
      (1, 2, two),
    ],
    Domain::QQ,
  )
  let (sdm_rref, sdm_pivots) = sdm_aug.rref()
  let sdm_particular = sdm_rref
    .particular(pivots=sdm_pivots)
    .to_dense()
    .to_domain_matrix()
    .to_matrix_string()
  assert_eq(sdm_particular, "Matrix([[1, 0]])")
}

///|
test "matrices: SDM lu/lu_solve/charpoly parity and qr/fflu invariants" {
  let zero = @sympolys.fe_from_int(0, Domain::QQ)
  let oneq = @sympolys.fe_from_int(1, Domain::QQ)
  let a = @sympolys.sdm_from_entries(
    2,
    2,
    [(0, 1, oneq), (1, 0, oneq), (1, 1, oneq)],
    Domain::QQ,
  )
  let lu = a.lu()
  let ours_lu = "\{lu.0.to_dense().to_domain_matrix().to_matrix_string()}||\{lu.1.to_dense().to_domain_matrix().to_matrix_string()}||\{swap_text(lu.2)}"
  let oracle_lu = domainmatrix_lu([[0, 1], [1, 1]], "QQ")
  assert_eq(mx_trim(ours_lu), mx_trim(oracle_lu))

  let qr = @sympolys.sdm_from_entries(
    3,
    2,
    [
      (0, 0, oneq),
      (0, 1, @sympolys.fe_from_int(2, Domain::QQ)),
      (1, 0, @sympolys.fe_from_int(3, Domain::QQ)),
      (1, 1, @sympolys.fe_from_int(4, Domain::QQ)),
      (2, 0, @sympolys.fe_from_int(5, Domain::QQ)),
      (2, 1, @sympolys.fe_from_int(6, Domain::QQ)),
    ],
    Domain::QQ,
  ).qr()
  let q_left = qr.0.to_dense().to_domain_matrix()
  let q_right = qr.1.to_dense().to_domain_matrix()
  let orig_qr = @sympolys.domain_matrix_from_ints([[1, 2], [3, 4], [5, 6]], Domain::QQ)
  assert_eq(mx_trim(q_left.matmul(q_right).to_matrix_string()), mx_trim(orig_qr.to_matrix_string()))
  assert_true(dm_is_diagonal(q_left.transpose().matmul(q_left)))
  assert_true(dm_is_upper(q_right))

  let solve_a = @sympolys.sdm_from_entries(
    2,
    2,
    [
      (0, 0, oneq),
      (0, 1, @sympolys.fe_from_int(2, Domain::QQ)),
      (1, 0, @sympolys.fe_from_int(3, Domain::QQ)),
      (1, 1, @sympolys.fe_from_int(4, Domain::QQ)),
    ],
    Domain::QQ,
  )
  let solve_rhs = @sympolys.sdm_from_entries(
    2,
    1,
    [(0, 0, oneq), (1, 0, zero)],
    Domain::QQ,
  )
  let ours_lu_solve = solve_a
    .lu_solve(solve_rhs)
    .to_dense()
    .to_domain_matrix()
    .to_matrix_string()
  let oracle_lu_solve = domainmatrix_lu_solve(
    [[1, 2], [3, 4]],
    [[1], [0]],
    "QQ",
  )
  assert_eq(mx_trim(ours_lu_solve), mx_trim(oracle_lu_solve))

  let zz = @sympolys.sdm_from_entries(
    2,
    2,
    [
      (0, 0, @sympolys.fe_from_int(1, Domain::ZZ)),
      (0, 1, @sympolys.fe_from_int(2, Domain::ZZ)),
      (1, 0, @sympolys.fe_from_int(3, Domain::ZZ)),
      (1, 1, @sympolys.fe_from_int(4, Domain::ZZ)),
    ],
    Domain::ZZ,
  )
  let fflu = zz.fflu()
  let left = fflu.1
    .to_dense()
    .to_domain_matrix()
    .to_field()
    .matmul(fflu.2.to_dense().to_domain_matrix().to_field().inv())
    .matmul(fflu.3.to_dense().to_domain_matrix().to_field())
  let right = fflu.0
    .to_dense()
    .to_domain_matrix()
    .to_field()
    .matmul(zz.to_dense().to_domain_matrix().to_field())
  assert_eq(mx_trim(left.to_matrix_string()), mx_trim(right.to_matrix_string()))
  assert_true(dm_is_diagonal(fflu.2.to_dense().to_domain_matrix()))
  assert_true(dm_is_upper(fflu.3.to_dense().to_domain_matrix()))

  let ours_charpoly = coeffs_text(zz.charpoly())
  let oracle_charpoly = domainmatrix_charpoly(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  assert_eq(mx_trim(ours_charpoly), mx_trim(oracle_charpoly))
}

///|
test "matrices: DDM and SDM structural wrappers" {
  let ddm = @sympolys.ddm_from_ints([[1, 0], [0, 4]], Domain::ZZ)
  assert_eq(mx_trim(
          DDM::from_list_flat(ddm.to_list_flat(), (2, 2), Domain::ZZ).to_string(),
        ), mx_trim(ddm.to_string()))
  assert_eq(mx_trim(DDM::zeros(2, 2, Domain::ZZ).to_string()), "[[0,0],[0,0]]")
  assert_eq(mx_trim(DDM::ones(2, 2, Domain::ZZ).to_string()), "[[1,1],[1,1]]")
  assert_eq(mx_trim(DDM::eye(2, Domain::ZZ).to_string()), "[[1,0],[0,1]]")
  assert_eq(mx_trim(
          DDM::diag(
            [@sympolys.fe_from_int(1, Domain::ZZ), @sympolys.fe_from_int(4, Domain::ZZ)],
            Domain::ZZ,
          ).to_string(),
        ), mx_trim(ddm.to_string()))
  assert_eq(coeffs_text(ddm.diagonal()), "[1, 4]")
  assert_eq(coeffs_text(ddm.to_list_flat()), "[1, 0, 0, 4]")
  let ddm_flat_nz = ddm.to_flat_nz()
  assert_eq(mx_trim(
          ddm.from_flat_nz(ddm_flat_nz.0, ddm_flat_nz.1, Domain::ZZ).to_string(),
        ), mx_trim(ddm.to_string()))
  assert_true(ddm.to_dod().length() == 2 && ddm.to_dok().length() == 2)
  let ddm_two = @sympolys.fe_from_int(2, Domain::ZZ)
  assert_eq(mx_trim(
          ddm
          .applyfunc(fn(value : FieldElem) raise PolyError {
            @sympolys.fe_mul(value, ddm_two)
          })
          .to_string(),
        ), "[[2,0],[0,8]]")
  assert_eq(mx_trim(ddm.to_ddm().to_string()), mx_trim(ddm.to_string()))
  assert_eq(ddm.nnz(), 2)
  assert_true(ddm.is_diagonal() && ddm.is_upper() && ddm.is_lower())
  assert_true(!ddm.is_zero_matrix())
  assert_eq(mx_trim(ddm.hstack(ddm).to_string()), "[[1,0,1,0],[0,4,0,4]]")
  assert_eq(mx_trim(ddm.vstack(ddm).to_string()), "[[1,0],[0,4],[1,0],[0,4]]")
  assert_eq(mx_trim(ddm.mul_elementwise(ddm).to_string()), "[[1,0],[0,16]]")
  assert_eq(mx_trim(ddm.rmul(@sympolys.fe_from_int(2, Domain::ZZ)).to_string()), "[[2,0],[0,8]]")
  assert_eq(ddm.scc().to_string(), "[[0], [1]]")
  assert_eq(mx_trim(ddm.to_sdm().to_dense().to_string()), mx_trim(ddm.to_string()))

  let one = @sympolys.fe_from_int(1, Domain::QQ)
  let four = @sympolys.fe_from_int(4, Domain::QQ)
  let sdm = @sympolys.sdm_from_entries(2, 2, [(0, 0, one), (1, 1, four)], Domain::QQ)
  assert_eq(mx_trim(
          SDM::from_list_flat(sdm.to_list_flat(), (2, 2), Domain::QQ)
          .to_dense()
          .to_string(),
        ), mx_trim(sdm.to_dense().to_string()))
  assert_eq(mx_trim(SDM::zeros(2, 2, Domain::QQ).to_dense().to_string()), "[[0,0],[0,0]]")
  assert_eq(mx_trim(SDM::ones(2, 2, Domain::QQ).to_dense().to_string()), "[[1,1],[1,1]]")
  assert_eq(mx_trim(SDM::eye(2, Domain::QQ).to_dense().to_string()), "[[1,0],[0,1]]")
  assert_eq(mx_trim(SDM::diag([one, four], Domain::QQ).to_dense().to_string()), mx_trim(sdm.to_dense().to_string()))
  assert_eq(coeffs_text(sdm.diagonal()), "[1, 4]")
  assert_eq(coeffs_text(sdm.to_list_flat()), "[1, 0, 0, 4]")
  let sdm_flat_nz = sdm.to_flat_nz()
  assert_eq(mx_trim(
          sdm
          .from_flat_nz(sdm_flat_nz.0, sdm_flat_nz.1, Domain::QQ)
          .to_dense()
          .to_string(),
        ), mx_trim(sdm.to_dense().to_string()))
  assert_true(sdm.to_dod().length() == 2 && sdm.to_dok().length() == 2)
  let sdm_two = @sympolys.fe_from_int(2, Domain::QQ)
  assert_eq(mx_trim(
          sdm
          .applyfunc(fn(value : FieldElem) raise PolyError {
            @sympolys.fe_mul(value, sdm_two)
          })
          .to_dense()
          .to_string(),
        ), "[[2,0],[0,8]]")
  assert_eq(mx_trim(sdm.to_sdm().to_dense().to_string()), mx_trim(sdm.to_dense().to_string()))
  assert_eq(sdm.nnz(), 2)
  assert_true(sdm.is_diagonal() && sdm.is_upper() && sdm.is_lower())
  assert_eq(mx_trim(sdm.transpose().to_dense().to_string()), "[[1,0],[0,4]]")
  assert_eq(mx_trim(sdm.hstack(sdm).to_dense().to_string()), "[[1,0,1,0],[0,4,0,4]]")
  assert_eq(mx_trim(sdm.vstack(sdm).to_dense().to_string()), "[[1,0],[0,4],[1,0],[0,4]]")
  assert_eq(mx_trim(sdm.mul_elementwise(sdm).to_dense().to_string()), "[[1,0],[0,16]]")
  assert_eq(mx_trim(sdm.rmul(@sympolys.fe_from_int(2, Domain::QQ)).to_dense().to_string()), "[[2,0],[0,8]]")
  assert_eq(@sympolys.fe_to_string(sdm.det()), "4")
  assert_eq(mx_trim(sdm.inv().to_dense().to_string()), "[[1,0],[0,1/4]]")
  assert_eq(sdm.scc().to_string(), "[[0], [1]]")
  assert_eq(mx_trim(sdm.to_ddm().to_string()), "[[1,0],[0,4]]")

  let zz_sparse = @sympolys.sdm_from_entries(
    3,
    3,
    [
      (0, 0, @sympolys.fe_from_int(1, Domain::ZZ)),
      (1, 1, @sympolys.fe_from_int(1, Domain::ZZ)),
      (2, 2, @sympolys.fe_from_int(1, Domain::ZZ)),
    ],
    Domain::ZZ,
  )
  let sparse_reduced = zz_sparse.lll()
  let sparse_hnf_orig = matrix_hnf_code([
    [1, 0, 0],
    [0, 1, 0],
    [0, 0, 1],
  ])
  let sparse_hnf_reduced = matrix_hnf_code(
    ddm_to_int_rows(sparse_reduced.to_dense()),
  )
  assert_eq(sparse_hnf_orig, sparse_hnf_reduced)
  let sparse_lll_transform = zz_sparse.lll_transform()
  let sparse_recomposed = sparse_lll_transform.1
    .to_dense()
    .matmul(zz_sparse.to_dense())
    .to_string()
  assert_eq(mx_trim(sparse_recomposed), mx_trim(sparse_lll_transform.0.to_dense().to_string()))
  let sparse_hnf_transformed = matrix_hnf_code(
    ddm_to_int_rows(sparse_lll_transform.0.to_dense()),
  )
  assert_eq(sparse_hnf_orig, sparse_hnf_transformed)
}

///|
test "matrices: DDM and SDM constructor/accessor helpers" {
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
  let ddm = DDM::from_list(rows, (3, 3), Domain::ZZ)
  assert_eq(@sympolys.fe_to_string(ddm.getitem(1, -2)), "5")
  let ddm_set = ddm.setitem(-1, -1, @sympolys.fe_from_int(10, Domain::ZZ))
  assert_eq(ddm_set.to_domain_matrix().getitem(-1, -1).to_string(), "10")
  let ddm_slice = ddm.extract_slice(
    row_start=Some(1),
    row_stop=Some(3),
    col_stop=Some(-2),
  )
  assert_eq(ddm_slice.to_domain_matrix().to_matrix_string(), "Matrix([[4], [7]])")
  let ddm_flat = Array::from_iter(ddm.flatiter()).map(fe_to_string).join(",")
  assert_eq(ddm_flat, "1,2,3,4,5,6,7,8,9")
  let ddm_copy = DDM::from_ddm(ddm)
  assert_eq(ddm_copy.to_string(), ddm.to_string())

  let dod : DomainMatrixDOD = Map::new()
  let row0 : Map[Int, FieldElem] = Map::new()
  row0[1] = @sympolys.fe_from_int(1, Domain::ZZ)
  dod[0] = row0
  let sdm = SDM::new(dod, (2, 2), Domain::ZZ)
  assert_eq(@sympolys.fe_to_string(sdm.getitem(-2, -1)), "1")
  let sdm_set = sdm.setitem(1, 0, @sympolys.fe_from_int(2, Domain::ZZ))
  assert_eq(sdm_set
        .extract_slice(
          row_start=Some(1),
          row_stop=Some(2),
          col_start=Some(0),
          col_stop=Some(1),
        )
        .to_dense()
        .to_domain_matrix()
        .to_matrix_string(), "Matrix([[2]])")
  let sdm_from_list = SDM::from_list(
    [
      [@sympolys.fe_from_int(1, Domain::ZZ), @sympolys.fe_from_int(0, Domain::ZZ)],
      [@sympolys.fe_from_int(0, Domain::ZZ), @sympolys.fe_from_int(1, Domain::ZZ)],
    ],
    (2, 2),
    Domain::ZZ,
  )
  assert_eq(mx_trim(sdm_from_list.to_dense().to_domain_matrix().to_matrix_string()), mx_trim("Matrix([[1, 0], [0, 1]])"))
}

///|
test "matrices: DFM fallback and scalar sympy helpers" {
  let ddm = @sympolys.ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  assert_eq(mx_trim(ddm.to_dfm().to_string()), mx_trim(ddm.to_string()))
  assert_eq(mx_trim(ddm.to_dfm_or_ddm().to_string()), mx_trim(ddm.to_string()))

  let sdm = SDM::from_ddm(ddm)
  assert_eq(mx_trim(sdm.to_domain_matrix().to_matrix_string()), mx_trim("Matrix([[1, 2], [3, 4]])"))
  assert_eq(mx_trim(sdm.to_dfm().to_string()), mx_trim(ddm.to_string()))
  assert_eq(mx_trim(sdm.to_dfm_or_ddm().to_string()), mx_trim(ddm.to_string()))

  let scalar = DomainScalar::from_sympy(@symcore.rational_from_ints(1, 2))
  let oracle_scalar = domainscalar_from_expr("1/2")
  let ours_scalar = "\{scalar.to_string()}@\{@sympolys.domain_to_sympy_string(scalar.domain)}"
  assert_eq(mx_trim(ours_scalar), mx_trim(oracle_scalar))
  assert_eq(@symprint.to_string(scalar.to_sympy()), "1/2")
  let scalar_new = DomainScalar::new(@sympolys.fe_from_int(3, Domain::ZZ), Domain::ZZ)
  assert_eq(scalar_new.to_string(), "3")
}

///|
test "matrices: DomainScalar coercion and arithmetic" {
  let a = @sympolys.domain_scalar_from_int(2, Domain::ZZ)
  let b = @sympolys.domain_scalar_from_int(1, Domain::QQ)
  let c = a.add(b)
  assert_true(c.domain is Domain::QQ)
  assert_eq(c.to_string(), "3")

  let d = c.mul(@sympolys.domain_scalar_from_int(2, Domain::QQ))
  assert_eq(d.to_string(), "6")

  assert_eq(c.convert_to(Domain::QQ).to_string(), "3")
  let q = @sympolys.domain_scalar_from_int(7, Domain::ZZ).floordiv(
    @sympolys.domain_scalar_from_int(3, Domain::ZZ),
  )
  let r = @sympolys.domain_scalar_from_int(7, Domain::ZZ).mod(
    @sympolys.domain_scalar_from_int(3, Domain::ZZ),
  )
  assert_true(q.to_string() == "2" && r.to_string() == "1")
  let qr = @sympolys.domain_scalar_from_int(7, Domain::ZZ).divmod(
    @sympolys.domain_scalar_from_int(3, Domain::ZZ),
  )
  assert_true(qr.0.to_string() == "2" && qr.1.to_string() == "1")
  assert_eq(@sympolys.domain_scalar_from_int(2, Domain::ZZ).pos().to_string(), "2")
  assert_eq(@sympolys.domain_scalar_from_int(2, Domain::ZZ).neg().to_string(), "-2")
}

///|
test "matrices: linsolve unique/no-solution/parametric" {
  let a = @sympolys.ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = [@sympolys.fe_from_int(5, Domain::QQ), @sympolys.fe_from_int(11, Domain::QQ)]
  match @sympolys.linear_solve(a, b) {
    LinearSolveResult::Unique(sol) => {
      assert_eq(sol.length(), 2)
      assert_true(@sympolys.fe_to_string(sol[0]) == "1" && @sympolys.fe_to_string(sol[1]) == "2")
    }
    _ => fail("expected unique solution")
  }

  let a2 = @sympolys.ddm_from_ints([[1, 1], [1, 1]], Domain::QQ)
  let b2 = [@sympolys.fe_from_int(1, Domain::QQ), @sympolys.fe_from_int(2, Domain::QQ)]
  assert_true(@sympolys.linear_solve(a2, b2) is LinearSolveResult::NoSolution)

  let a3 = @sympolys.ddm_from_ints([[1, 1]], Domain::QQ)
  let b3 = [@sympolys.fe_from_int(0, Domain::QQ)]
  match @sympolys.linear_solve(a3, b3) {
    LinearSolveResult::Parametric(exprs, params) => {
      assert_eq(params.length(), 1)
      assert_eq(params[0], "t1")
      assert_eq(exprs.length(), 2)
      assert_true(mx_expr_norm(exprs[0]) == "-t1" && mx_expr_norm(exprs[1]) == "t1")
    }
    _ => fail("expected parametric solution")
  }
}

///|
test "matrices: sympy_dict_to_dm parity" {
  let coeffs : Array[Map[String, @symcore.Expr]] = [
    { "x": @symcore.int(1), "y": @symcore.int(2) },
    { "y": @symcore.int(1) },
  ]
  let rhs = [@symcore.int(3), @symcore.int(1)]
  let syms = ["x", "y"]
  let ours = @sympolys.sympy_dict_to_dm(coeffs, rhs, syms)
  let oracle = linsolve_sympy_dict_to_dm_summary(
    [{ "x": "1", "y": "2" }, { "y": "1" }],
    ["3", "1"],
    syms,
  )
  assert_eq(mx_trim(sdm_summary_like_oracle(ours)), mx_trim(oracle))
}
