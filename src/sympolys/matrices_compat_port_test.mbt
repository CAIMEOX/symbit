///|
fn mx_trim(s : String) -> String {
  s
  .replace_all(old=" ", new="")
  .replace_all(old="\n", new="")
  .replace_all(old=".0", new="")
}

///|
fn mx_expr_norm(e : @symcore.Expr) -> String {
  (try! @sympy_polys.sympy_normalize(@symprint.to_string(e)).trim().to_string()).replace_all(
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
      rows.push("[\{fe_to_string(v)}]")
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
    return "(\{fe_to_string(values[0])},)"
  }
  let joined = values.map(fe_to_string).join(", ")
  "(\{joined})"
}

///|
fn sdm_summary_like_oracle(sdm : SDM) -> String raise PolyError {
  "\{sdm.to_ddm().to_string()}@\{domain_to_sympy_string(sdm.domain())}|sparse"
}

///|
fn ddm_to_int_rows(ddm : DDM) -> Array[Array[Int]] raise PolyError {
  let rows = ddm.to_list()
  let out : Array[Array[Int]] = Array::new()
  for row in rows {
    let out_row : Array[Int] = Array::new()
    for v in row {
      let q = fe_expect_rational(v)
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
  fe_from_rational(
    try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den)),
    Domain::QQ,
  )
}

///|
fn ddm_clear_denoms_repr(
  den : DomainScalar,
  num : DDM,
) -> String raise PolyError {
  "\{den.to_string()}@\{domain_to_sympy_string(den.domain)}||Matrix(\{num.to_string()})@\{domain_to_sympy_string(num.domain())}"
}

///|
fn ddm_clear_denoms_rowwise_repr(
  den : DDM,
  num : DDM,
) -> String raise PolyError {
  "\{den.to_domain_matrix().to_matrix_string()}@\{domain_to_sympy_string(den.domain())}||Matrix(\{num.to_string()})@\{domain_to_sympy_string(num.domain())}"
}

///|
test "matrices: DDM add/matmul/scalarmul/det/rref parity" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = ddm_from_ints([[5, 6], [7, 8]], Domain::QQ)
  let two = try! fe_from_int(2, Domain::QQ)

  let ours_add = a.add(b).to_string()
  let ours_matmul = a.matmul(b).to_string()
  let ours_mul = a.mul(two).to_string()
  let ours_det = fe_to_string(a.det())
  let (r, pivots) = a.rref()
  let pivot_text = pivots.map(i => i.to_string()).join(",")
  let ours_rref = "\{r.to_string()}||[\{pivot_text}]"

  let oracle_add = @sympy_polys.ddm_add(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_matmul = @sympy_polys.ddm_matmul(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_mul = @sympy_polys.ddm_mul([[1, 2], [3, 4]], 2, "QQ")
  let oracle_det = @sympy_polys.ddm_det([[1, 2], [3, 4]], "QQ")
  let oracle_rref = @sympy_polys.ddm_rref([[1, 2], [3, 4]], "QQ")

  guard mx_trim(ours_add) == mx_trim(oracle_add) else {
    fail("ddm add mismatch: ours=\{ours_add}, oracle=\{oracle_add}")
  }
  guard mx_trim(ours_matmul) == mx_trim(oracle_matmul) else {
    fail("ddm matmul mismatch: ours=\{ours_matmul}, oracle=\{oracle_matmul}")
  }
  guard mx_trim(ours_mul) == mx_trim(oracle_mul) else {
    fail("ddm scalarmul mismatch: ours=\{ours_mul}, oracle=\{oracle_mul}")
  }
  guard mx_trim(ours_det) == mx_trim(oracle_det) else {
    fail("ddm det mismatch: ours=\{ours_det}, oracle=\{oracle_det}")
  }
  guard mx_trim(ours_rref) == mx_trim(oracle_rref) else {
    fail("ddm rref mismatch: ours=\{ours_rref}, oracle=\{oracle_rref}")
  }
}

///|
test "matrices: DDM rank/inv/nullspace parity" {
  let rank_case = ddm_from_ints([[1, 2], [2, 4]], Domain::QQ)
  guard rank_case.rank() == @sympy_polys.ddm_rank([[1, 2], [2, 4]], "QQ") else {
    fail("ddm rank mismatch")
  }

  let inv_case = ddm_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let ours_inv = "Matrix(\{inv_case.inv().to_string()})"
  let oracle_inv = @sympy_polys.ddm_inv([[1, 2], [3, 5]], "QQ")
  guard mx_trim(ours_inv) == mx_trim(oracle_inv) else {
    fail("ddm inv mismatch: ours=\{ours_inv}, oracle=\{oracle_inv}")
  }

  let ns_case = ddm_from_ints([[1, 2, 3], [2, 4, 6]], Domain::QQ)
  let ours_ns = basis_to_sympy_text(ns_case.nullspace())
  let oracle_ns = @sympy_polys.ddm_nullspace([[1, 2, 3], [2, 4, 6]], "QQ")
  guard mx_trim(ours_ns) == mx_trim(oracle_ns) else {
    fail("ddm nullspace mismatch: ours=\{ours_ns}, oracle=\{oracle_ns}")
  }
}

///|
test "matrices: DDM exact denominator parity" {
  let qq_rows = [
    [ddm_rat(1, 2), ddm_rat(1, 3), ddm_rat(1, 4)],
    [ddm_rat(1, 5), ddm_rat(1, 6), ddm_rat(1, 7)],
  ]
  let qq = ddm_from_dense(qq_rows, Domain::QQ)
  let clear = qq.clear_denoms()
  let clear_rowwise = qq.clear_denoms_rowwise()

  let ours_clear = ddm_clear_denoms_repr(clear.0, clear.1)
  let ours_clear_rowwise = ddm_clear_denoms_rowwise_repr(
    clear_rowwise.0,
    clear_rowwise.1,
  )

  let expr_rows = [["1/2", "1/3", "1/4"], ["1/5", "1/6", "1/7"]]
  let oracle_clear = @sympy_polys.domainmatrix_clear_denoms_expr(
    expr_rows, "QQ",
  )
  let oracle_clear_rowwise = @sympy_polys.domainmatrix_clear_denoms_rowwise_expr(
    expr_rows, "QQ",
  )

  guard mx_trim(ours_clear) == mx_trim(oracle_clear) else {
    fail(
      "ddm clear_denoms mismatch: ours=\{ours_clear}, oracle=\{oracle_clear}",
    )
  }
  guard mx_trim(ours_clear_rowwise) == mx_trim(oracle_clear_rowwise) else {
    fail(
      "ddm clear_denoms_rowwise mismatch: ours=\{ours_clear_rowwise}, oracle=\{oracle_clear_rowwise}",
    )
  }

  let zz = ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ)
  let rhs = ddm_from_ints([[5], [6]], Domain::ZZ)
  let adj_det = zz.adj_det()
  let inv_den = zz.inv_den()
  let solve_den = zz.solve_den(rhs)

  let ours_adjugate = "Matrix(\{zz.adjugate().to_string()})"
  let ours_adj_det = "Matrix(\{adj_det.0.to_string()})||\{fe_to_string(adj_det.1)}"
  let ours_inv_den = "Matrix(\{inv_den.0.to_string()})||\{fe_to_string(inv_den.1)}"
  let ours_solve_den = "Matrix(\{solve_den.0.to_string()})||\{fe_to_string(solve_den.1)}"

  let oracle_adjugate = @sympy_polys.domainmatrix_adjugate(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  let oracle_adj_det = @sympy_polys.domainmatrix_adj_det([[1, 2], [3, 4]], "ZZ")
  let oracle_inv_den = @sympy_polys.domainmatrix_inv_den([[1, 2], [3, 4]], "ZZ")
  let oracle_solve_den = @sympy_polys.domainmatrix_solve_den(
    [[1, 2], [3, 4]],
    [[5], [6]],
    "ZZ",
  )

  guard mx_trim(ours_adjugate) == mx_trim(oracle_adjugate) else {
    fail(
      "ddm adjugate mismatch: ours=\{ours_adjugate}, oracle=\{oracle_adjugate}",
    )
  }
  guard mx_trim(ours_adj_det) == mx_trim(oracle_adj_det) else {
    fail("ddm adj_det mismatch: ours=\{ours_adj_det}, oracle=\{oracle_adj_det}")
  }
  guard mx_trim(ours_inv_den) == mx_trim(oracle_inv_den) else {
    fail("ddm inv_den mismatch: ours=\{ours_inv_den}, oracle=\{oracle_inv_den}")
  }
  guard mx_trim(ours_solve_den) == mx_trim(oracle_solve_den) else {
    fail(
      "ddm solve_den mismatch: ours=\{ours_solve_den}, oracle=\{oracle_solve_den}",
    )
  }
}

///|
test "matrices: DDM rref_den/nullspace/solve_den_rref parity" {
  let rows = [[1, 2, 3], [4, 5, 6]]
  let a = ddm_from_ints(rows, Domain::ZZ)
  let rref_den = a.rref_den(rref_method="FF")
  let pivots = rref_den.2.map(i => i.to_string()).join(",")
  let ours_rref_den = "Matrix(\{rref_den.0.to_string()})||\{fe_to_string(rref_den.1)}||[\{pivots}]"
  let oracle_rref_den = @sympy_polys.domainmatrix_rref_den(
    rows,
    "ZZ",
    rref_method="FF",
  )
  guard mx_trim(ours_rref_den) == mx_trim(oracle_rref_den) else {
    fail(
      "ddm rref_den mismatch: ours=\{ours_rref_den}, oracle=\{oracle_rref_den}",
    )
  }

  let zz_ns = ddm_from_ints([[6, -3], [4, -2]], Domain::ZZ)
  let ours_ns = basis_rows_to_matrix_text(zz_ns.nullspace())
  let oracle_ns = @sympy_polys.domainmatrix_nullspace([[6, -3], [4, -2]], "ZZ")
  guard mx_trim(ours_ns) == mx_trim(oracle_ns) else {
    fail("ddm ZZ nullspace mismatch: ours=\{ours_ns}, oracle=\{oracle_ns}")
  }

  let sys_a = ddm_from_ints([[2, 0], [0, 3], [2, 3]], Domain::ZZ)
  let sys_b = ddm_from_ints([[1], [1], [2]], Domain::ZZ)
  let ours_solve = sys_a.solve_den_rref(sys_b)
  let ours_solve_text = "Matrix(\{ours_solve.0.to_string()})||\{fe_to_string(ours_solve.1)}"
  let oracle_solve = @sympy_polys.domainmatrix_solve_den_rref(
    [[2, 0], [0, 3], [2, 3]],
    [[1], [1], [2]],
    "ZZ",
  )
  guard mx_trim(ours_solve_text) == mx_trim(oracle_solve) else {
    fail(
      "ddm solve_den_rref mismatch: ours=\{ours_solve_text}, oracle=\{oracle_solve}",
    )
  }
}

///|
test "matrices: DDM lu/lu_solve/charpoly parity and qr/fflu invariants" {
  let lu_case = ddm_from_ints([[0, 1], [1, 1]], Domain::QQ)
  let lu = lu_case.lu()
  let ours_lu = "\{lu.0.to_domain_matrix().to_matrix_string()}||\{lu.1.to_domain_matrix().to_matrix_string()}||\{swap_text(lu.2)}"
  let oracle_lu = @sympy_polys.domainmatrix_lu([[0, 1], [1, 1]], "QQ")
  guard mx_trim(ours_lu) == mx_trim(oracle_lu) else {
    fail("ddm lu mismatch: ours=\{ours_lu}, oracle=\{oracle_lu}")
  }

  let qr_case = ddm_from_ints([[1, 2], [3, 4], [5, 6]], Domain::QQ)
  let qr = qr_case.qr()
  let qr_left = qr.0.to_domain_matrix()
  let qr_right = qr.1.to_domain_matrix()
  let recomposed = qr_left.matmul(qr_right).to_matrix_string()
  guard mx_trim(recomposed) ==
    mx_trim(qr_case.to_domain_matrix().to_matrix_string()) else {
    fail("ddm qr reconstruction mismatch")
  }
  guard dm_is_diagonal(qr_left.transpose().matmul(qr_left)) else {
    fail("ddm qr should give orthogonal columns")
  }
  guard dm_is_upper(qr_right) else {
    fail("ddm qr should give upper-triangular R")
  }

  let solve_case = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let rhs = ddm_from_ints([[1], [0]], Domain::QQ)
  let ours_lu_solve = solve_case
    .lu_solve(rhs)
    .to_domain_matrix()
    .to_matrix_string()
  let oracle_lu_solve = @sympy_polys.domainmatrix_lu_solve(
    [[1, 2], [3, 4]],
    [[1], [0]],
    "QQ",
  )
  guard mx_trim(ours_lu_solve) == mx_trim(oracle_lu_solve) else {
    fail(
      "ddm lu_solve mismatch: ours=\{ours_lu_solve}, oracle=\{oracle_lu_solve}",
    )
  }

  let zz = ddm_from_ints([[1, 2], [3, 4]], Domain::ZZ)
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
  guard mx_trim(fflu_left.to_matrix_string()) ==
    mx_trim(fflu_right.to_matrix_string()) else {
    fail("ddm fflu invariant mismatch")
  }
  guard dm_is_diagonal(fflu.2.to_domain_matrix()) else {
    fail("ddm fflu should return diagonal D")
  }
  guard dm_is_upper(fflu.3.to_domain_matrix()) else {
    fail("ddm fflu should return upper-triangular U")
  }

  let ours_charpoly = coeffs_text(zz.charpoly())
  let oracle_charpoly = @sympy_polys.domainmatrix_charpoly(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  guard mx_trim(ours_charpoly) == mx_trim(oracle_charpoly) else {
    fail(
      "ddm charpoly mismatch: ours=\{ours_charpoly}, oracle=\{oracle_charpoly}",
    )
  }
}

///|
test "matrices: DomainMatrix LLL and transform parity" {
  let rows = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
  let a = ddm_from_ints(rows, Domain::ZZ)

  let reduced = a.lll()
  let hnf_orig = @sympy_polys.matrix_hnf_code(rows)
  let hnf_reduced = @sympy_polys.matrix_hnf_code(try! ddm_to_int_rows(reduced))
  guard hnf_orig == hnf_reduced else {
    fail(
      "lll lattice mismatch: hnf(orig)=\{hnf_orig}, hnf(reduced)=\{hnf_reduced}",
    )
  }

  let (reduced2, transform) = a.lll_transform()
  let recomposed = transform.matmul(a).to_string()
  guard mx_trim(recomposed) == mx_trim(reduced2.to_string()) else {
    fail("lll transform reconstruction mismatch")
  }
  let hnf_reduced2 = @sympy_polys.matrix_hnf_code(
    try! ddm_to_int_rows(reduced2),
  )
  guard hnf_orig == hnf_reduced2 else { fail("lll transform lattice mismatch") }
}

///|
test "matrices: HNF parity on integer cases" {
  let cases = [[[1, 0, 0], [0, 1, 0], [0, 0, 1]]]
  for rows in cases {
    let a = ddm_from_ints(rows, Domain::ZZ)
    let ours_rows = try! ddm_to_int_rows(a.hermite_normal_form())
    let oracle_code = @sympy_polys.matrix_hnf_code(rows)
    let ours_code = @sympy_polys.matrix_hnf_code(ours_rows)
    guard ours_code == oracle_code else {
      fail("hnf lattice mismatch: ours=\{ours_code}, oracle=\{oracle_code}")
    }
  }
}

///|
test "matrices: Smith normal form parity on integer cases" {
  let rows = [[12, 6, 4], [3, 9, 6], [2, 16, 14]]
  let a = ddm_from_ints(rows, Domain::ZZ)
  let smf = a.smith_normal_form()
  let decomp = a.smith_normal_decomp()
  let ours_invs = field_tuple_text(a.invariant_factors())
  let ours_smf = smf.to_domain_matrix().to_matrix_string()
  let oracle_invs = @sympy_polys.domainmatrix_invariant_factors(rows, "ZZ")
  let oracle_smf = @sympy_polys.domainmatrix_smith_normal_form(rows, "ZZ")
  guard ours_invs == oracle_invs else {
    fail(
      "ddm invariant_factors mismatch: ours=\{ours_invs}, oracle=\{oracle_invs}",
    )
  }
  guard mx_trim(ours_smf) == mx_trim(oracle_smf) else {
    fail(
      "ddm smith_normal_form mismatch: ours=\{ours_smf}, oracle=\{oracle_smf}",
    )
  }
  guard smf.is_smith_normal_form() else {
    fail("ddm smith_normal_form should satisfy smith predicate")
  }
  let recomposed = decomp.1
    .matmul(a)
    .matmul(decomp.2)
    .to_domain_matrix()
    .to_matrix_string()
  guard mx_trim(recomposed) == mx_trim(ours_smf) else {
    fail("ddm smith decomposition reconstruction mismatch")
  }
}

///|
test "matrices: SDM add/matmul/scalarmul and dense conversion" {
  let two = try! fe_from_int(2, Domain::ZZ)
  let one = try! fe_from_int(1, Domain::ZZ)
  let three = try! fe_from_int(3, Domain::ZZ)
  let four = try! fe_from_int(4, Domain::ZZ)

  let s = sdm_from_entries(2, 2, [(0, 1, two), (1, 0, one)], Domain::ZZ)
  let t = sdm_from_entries(2, 2, [(0, 0, three), (1, 1, four)], Domain::ZZ)

  let add = s.add(t)
  let scaled = s.mul(two)
  let mul = s.matmul(t)
  let add_dense = add.to_dense().to_string()
  let scaled_dense = scaled.to_dense().to_string()
  let mul_dense = mul.to_dense().to_string()

  guard mx_trim(add_dense) == "[[3,2],[1,4]]" else {
    fail("sdm add mismatch: \{add_dense}")
  }
  guard mx_trim(scaled_dense) == "[[0,4],[2,0]]" else {
    fail("sdm scalarmul mismatch: \{scaled_dense}")
  }
  guard mx_trim(mul_dense) == "[[0,8],[3,0]]" else {
    fail("sdm matmul mismatch: \{mul_dense}")
  }
}

///|
test "matrices: SDM rref_den and nullspace_from_rref parity" {
  let one = try! fe_from_int(1, Domain::ZZ)
  let two = try! fe_from_int(2, Domain::ZZ)
  let three = try! fe_from_int(3, Domain::ZZ)
  let four = try! fe_from_int(4, Domain::ZZ)
  let five = try! fe_from_int(5, Domain::ZZ)
  let six = try! fe_from_int(6, Domain::ZZ)
  let a = sdm_from_entries(
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
  let ours_rref_den = "\{rref_den.0.to_dense().to_domain_matrix().to_matrix_string()}||\{fe_to_string(rref_den.1)}||[\{pivots}]"
  let oracle_rref_den = @sympy_polys.domainmatrix_rref_den(
    [[1, 2, 3], [4, 5, 6]],
    "ZZ",
    rref_method="FF",
  )
  guard mx_trim(ours_rref_den) == mx_trim(oracle_rref_den) else {
    fail(
      "sdm rref_den mismatch: ours=\{ours_rref_den}, oracle=\{oracle_rref_den}",
    )
  }

  let ns_source = sdm_from_entries(
    2,
    2,
    [
      (0, 0, six),
      (0, 1, try! fe_from_int(-3, Domain::ZZ)),
      (1, 0, four),
      (1, 1, try! fe_from_int(-2, Domain::ZZ)),
    ],
    Domain::ZZ,
  )
  let (ns_basis, _) = ns_source.rref_den(rref_method="FF").0.nullspace_from_rref()
  let ours_ns = ns_basis.to_dense().to_domain_matrix().to_matrix_string()
  let oracle_ns = @sympy_polys.domainmatrix_nullspace([[6, -3], [4, -2]], "ZZ")
  guard mx_trim(ours_ns) == mx_trim(oracle_ns) else {
    fail(
      "sdm nullspace_from_rref mismatch: ours=\{ours_ns}, oracle=\{oracle_ns}",
    )
  }
}

///|
test "matrices: DDM and SDM particular wrappers" {
  let ddm_aug = ddm_from_ints([[1, 2, 1], [2, 4, 2]], Domain::QQ)
  let (ddm_rref, ddm_pivots) = ddm_aug.rref()
  let ddm_particular = ddm_rref
    .particular(pivots=ddm_pivots)
    .to_domain_matrix()
    .to_matrix_string()
  guard ddm_particular == "Matrix([[1, 0]])" else {
    fail("ddm particular mismatch: \{ddm_particular}")
  }

  let one = try! fe_from_int(1, Domain::QQ)
  let two = try! fe_from_int(2, Domain::QQ)
  let sdm_aug = sdm_from_entries(
    2,
    3,
    [
      (0, 0, one),
      (0, 1, two),
      (0, 2, one),
      (1, 0, two),
      (1, 1, try! fe_from_int(4, Domain::QQ)),
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
  guard sdm_particular == "Matrix([[1, 0]])" else {
    fail("sdm particular mismatch: \{sdm_particular}")
  }
}

///|
test "matrices: SDM lu/lu_solve/charpoly parity and qr/fflu invariants" {
  let zero = try! fe_from_int(0, Domain::QQ)
  let oneq = try! fe_from_int(1, Domain::QQ)
  let a = sdm_from_entries(
    2,
    2,
    [(0, 1, oneq), (1, 0, oneq), (1, 1, oneq)],
    Domain::QQ,
  )
  let lu = a.lu()
  let ours_lu = "\{lu.0.to_dense().to_domain_matrix().to_matrix_string()}||\{lu.1.to_dense().to_domain_matrix().to_matrix_string()}||\{swap_text(lu.2)}"
  let oracle_lu = @sympy_polys.domainmatrix_lu([[0, 1], [1, 1]], "QQ")
  guard mx_trim(ours_lu) == mx_trim(oracle_lu) else {
    fail("sdm lu mismatch: ours=\{ours_lu}, oracle=\{oracle_lu}")
  }

  let qr = sdm_from_entries(
    3,
    2,
    [
      (0, 0, oneq),
      (0, 1, try! fe_from_int(2, Domain::QQ)),
      (1, 0, try! fe_from_int(3, Domain::QQ)),
      (1, 1, try! fe_from_int(4, Domain::QQ)),
      (2, 0, try! fe_from_int(5, Domain::QQ)),
      (2, 1, try! fe_from_int(6, Domain::QQ)),
    ],
    Domain::QQ,
  ).qr()
  let q_left = qr.0.to_dense().to_domain_matrix()
  let q_right = qr.1.to_dense().to_domain_matrix()
  let orig_qr = domain_matrix_from_ints([[1, 2], [3, 4], [5, 6]], Domain::QQ)
  guard mx_trim(q_left.matmul(q_right).to_matrix_string()) ==
    mx_trim(orig_qr.to_matrix_string()) else {
    fail("sdm qr reconstruction mismatch")
  }
  guard dm_is_diagonal(q_left.transpose().matmul(q_left)) else {
    fail("sdm qr should give orthogonal columns")
  }
  guard dm_is_upper(q_right) else {
    fail("sdm qr should give upper-triangular R")
  }

  let solve_a = sdm_from_entries(
    2,
    2,
    [
      (0, 0, oneq),
      (0, 1, try! fe_from_int(2, Domain::QQ)),
      (1, 0, try! fe_from_int(3, Domain::QQ)),
      (1, 1, try! fe_from_int(4, Domain::QQ)),
    ],
    Domain::QQ,
  )
  let solve_rhs = sdm_from_entries(
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
  let oracle_lu_solve = @sympy_polys.domainmatrix_lu_solve(
    [[1, 2], [3, 4]],
    [[1], [0]],
    "QQ",
  )
  guard mx_trim(ours_lu_solve) == mx_trim(oracle_lu_solve) else {
    fail(
      "sdm lu_solve mismatch: ours=\{ours_lu_solve}, oracle=\{oracle_lu_solve}",
    )
  }

  let zz = sdm_from_entries(
    2,
    2,
    [
      (0, 0, try! fe_from_int(1, Domain::ZZ)),
      (0, 1, try! fe_from_int(2, Domain::ZZ)),
      (1, 0, try! fe_from_int(3, Domain::ZZ)),
      (1, 1, try! fe_from_int(4, Domain::ZZ)),
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
  guard mx_trim(left.to_matrix_string()) == mx_trim(right.to_matrix_string()) else {
    fail("sdm fflu invariant mismatch")
  }
  guard dm_is_diagonal(fflu.2.to_dense().to_domain_matrix()) else {
    fail("sdm fflu should return diagonal D")
  }
  guard dm_is_upper(fflu.3.to_dense().to_domain_matrix()) else {
    fail("sdm fflu should return upper-triangular U")
  }

  let ours_charpoly = coeffs_text(zz.charpoly())
  let oracle_charpoly = @sympy_polys.domainmatrix_charpoly(
    [[1, 2], [3, 4]],
    "ZZ",
  )
  guard mx_trim(ours_charpoly) == mx_trim(oracle_charpoly) else {
    fail(
      "sdm charpoly mismatch: ours=\{ours_charpoly}, oracle=\{oracle_charpoly}",
    )
  }
}

///|
test "matrices: DDM and SDM structural wrappers" {
  let ddm = ddm_from_ints([[1, 0], [0, 4]], Domain::ZZ)
  guard mx_trim(
      DDM::from_list_flat(ddm.to_list_flat(), (2, 2), Domain::ZZ).to_string(),
    ) ==
    mx_trim(ddm.to_string()) else {
    fail("ddm from_list_flat mismatch")
  }
  guard mx_trim(DDM::zeros(2, 2, Domain::ZZ).to_string()) == "[[0,0],[0,0]]" else {
    fail("ddm zeros mismatch")
  }
  guard mx_trim(DDM::ones(2, 2, Domain::ZZ).to_string()) == "[[1,1],[1,1]]" else {
    fail("ddm ones mismatch")
  }
  guard mx_trim(DDM::eye(2, Domain::ZZ).to_string()) == "[[1,0],[0,1]]" else {
    fail("ddm eye mismatch")
  }
  guard mx_trim(
      DDM::diag(
        [try! fe_from_int(1, Domain::ZZ), try! fe_from_int(4, Domain::ZZ)],
        Domain::ZZ,
      ).to_string(),
    ) ==
    mx_trim(ddm.to_string()) else {
    fail("ddm diag mismatch")
  }
  guard coeffs_text(ddm.diagonal()) == "[1, 4]" else {
    fail("ddm diagonal mismatch")
  }
  guard coeffs_text(ddm.to_list_flat()) == "[1, 0, 0, 4]" else {
    fail("ddm flat mismatch")
  }
  let ddm_flat_nz = ddm.to_flat_nz()
  guard mx_trim(
      ddm.from_flat_nz(ddm_flat_nz.0, ddm_flat_nz.1, Domain::ZZ).to_string(),
    ) ==
    mx_trim(ddm.to_string()) else {
    fail("ddm from_flat_nz mismatch")
  }
  guard ddm.to_dod().length() == 2 && ddm.to_dok().length() == 2 else {
    fail("ddm dod/dok mismatch")
  }
  let ddm_two = try! fe_from_int(2, Domain::ZZ)
  guard mx_trim(
      ddm
      .applyfunc(fn(value : FieldElem) raise PolyError {
        fe_mul(value, ddm_two)
      })
      .to_string(),
    ) ==
    "[[2,0],[0,8]]" else {
    fail("ddm applyfunc mismatch")
  }
  guard mx_trim(ddm.to_ddm().to_string()) == mx_trim(ddm.to_string()) else {
    fail("ddm to_ddm mismatch")
  }
  guard ddm.nnz() == 2 else { fail("ddm nnz mismatch") }
  guard ddm.is_diagonal() && ddm.is_upper() && ddm.is_lower() else {
    fail("ddm triangular predicates mismatch")
  }
  guard !ddm.is_zero_matrix() else { fail("ddm zero predicate mismatch") }
  guard mx_trim(ddm.hstack(ddm).to_string()) == "[[1,0,1,0],[0,4,0,4]]" else {
    fail("ddm hstack mismatch")
  }
  guard mx_trim(ddm.vstack(ddm).to_string()) == "[[1,0],[0,4],[1,0],[0,4]]" else {
    fail("ddm vstack mismatch")
  }
  guard mx_trim(ddm.mul_elementwise(ddm).to_string()) == "[[1,0],[0,16]]" else {
    fail("ddm mul_elementwise mismatch")
  }
  guard mx_trim(ddm.rmul(try! fe_from_int(2, Domain::ZZ)).to_string()) ==
    "[[2,0],[0,8]]" else {
    fail("ddm rmul mismatch")
  }
  guard ddm.scc().to_string() == "[[0], [1]]" else { fail("ddm scc mismatch") }
  guard mx_trim(ddm.to_sdm().to_dense().to_string()) == mx_trim(ddm.to_string()) else {
    fail("ddm to_sdm roundtrip mismatch")
  }

  let one = try! fe_from_int(1, Domain::QQ)
  let four = try! fe_from_int(4, Domain::QQ)
  let sdm = sdm_from_entries(2, 2, [(0, 0, one), (1, 1, four)], Domain::QQ)
  guard mx_trim(
      SDM::from_list_flat(sdm.to_list_flat(), (2, 2), Domain::QQ)
      .to_dense()
      .to_string(),
    ) ==
    mx_trim(sdm.to_dense().to_string()) else {
    fail("sdm from_list_flat mismatch")
  }
  guard mx_trim(SDM::zeros(2, 2, Domain::QQ).to_dense().to_string()) ==
    "[[0,0],[0,0]]" else {
    fail("sdm zeros mismatch")
  }
  guard mx_trim(SDM::ones(2, 2, Domain::QQ).to_dense().to_string()) ==
    "[[1,1],[1,1]]" else {
    fail("sdm ones mismatch")
  }
  guard mx_trim(SDM::eye(2, Domain::QQ).to_dense().to_string()) ==
    "[[1,0],[0,1]]" else {
    fail("sdm eye mismatch")
  }
  guard mx_trim(SDM::diag([one, four], Domain::QQ).to_dense().to_string()) ==
    mx_trim(sdm.to_dense().to_string()) else {
    fail("sdm diag mismatch")
  }
  guard coeffs_text(sdm.diagonal()) == "[1, 4]" else {
    fail("sdm diagonal mismatch")
  }
  guard coeffs_text(sdm.to_list_flat()) == "[1, 0, 0, 4]" else {
    fail("sdm flat mismatch")
  }
  let sdm_flat_nz = sdm.to_flat_nz()
  guard mx_trim(
      sdm
      .from_flat_nz(sdm_flat_nz.0, sdm_flat_nz.1, Domain::QQ)
      .to_dense()
      .to_string(),
    ) ==
    mx_trim(sdm.to_dense().to_string()) else {
    fail("sdm from_flat_nz mismatch")
  }
  guard sdm.to_dod().length() == 2 && sdm.to_dok().length() == 2 else {
    fail("sdm dod/dok mismatch")
  }
  let sdm_two = try! fe_from_int(2, Domain::QQ)
  guard mx_trim(
      sdm
      .applyfunc(fn(value : FieldElem) raise PolyError {
        fe_mul(value, sdm_two)
      })
      .to_dense()
      .to_string(),
    ) ==
    "[[2,0],[0,8]]" else {
    fail("sdm applyfunc mismatch")
  }
  guard mx_trim(sdm.to_sdm().to_dense().to_string()) ==
    mx_trim(sdm.to_dense().to_string()) else {
    fail("sdm to_sdm mismatch")
  }
  guard sdm.nnz() == 2 else { fail("sdm nnz mismatch") }
  guard sdm.is_diagonal() && sdm.is_upper() && sdm.is_lower() else {
    fail("sdm triangular predicates mismatch")
  }
  guard mx_trim(sdm.transpose().to_dense().to_string()) == "[[1,0],[0,4]]" else {
    fail("sdm transpose mismatch")
  }
  guard mx_trim(sdm.hstack(sdm).to_dense().to_string()) ==
    "[[1,0,1,0],[0,4,0,4]]" else {
    fail("sdm hstack mismatch")
  }
  guard mx_trim(sdm.vstack(sdm).to_dense().to_string()) ==
    "[[1,0],[0,4],[1,0],[0,4]]" else {
    fail("sdm vstack mismatch")
  }
  guard mx_trim(sdm.mul_elementwise(sdm).to_dense().to_string()) ==
    "[[1,0],[0,16]]" else {
    fail("sdm mul_elementwise mismatch")
  }
  guard mx_trim(
      sdm.rmul(try! fe_from_int(2, Domain::QQ)).to_dense().to_string(),
    ) ==
    "[[2,0],[0,8]]" else {
    fail("sdm rmul mismatch")
  }
  guard fe_to_string(sdm.det()) == "4" else { fail("sdm det mismatch") }
  guard mx_trim(sdm.inv().to_dense().to_string()) == "[[1,0],[0,1/4]]" else {
    fail("sdm inv mismatch")
  }
  guard sdm.scc().to_string() == "[[0], [1]]" else { fail("sdm scc mismatch") }
  guard mx_trim(sdm.to_ddm().to_string()) == "[[1,0],[0,4]]" else {
    fail("sdm to_ddm mismatch")
  }

  let zz_sparse = sdm_from_entries(
    3,
    3,
    [
      (0, 0, try! fe_from_int(1, Domain::ZZ)),
      (1, 1, try! fe_from_int(1, Domain::ZZ)),
      (2, 2, try! fe_from_int(1, Domain::ZZ)),
    ],
    Domain::ZZ,
  )
  let sparse_reduced = zz_sparse.lll()
  let sparse_hnf_orig = @sympy_polys.matrix_hnf_code([
    [1, 0, 0],
    [0, 1, 0],
    [0, 0, 1],
  ])
  let sparse_hnf_reduced = @sympy_polys.matrix_hnf_code(
    try! ddm_to_int_rows(sparse_reduced.to_dense()),
  )
  guard sparse_hnf_orig == sparse_hnf_reduced else {
    fail("sdm lll lattice mismatch")
  }
  let sparse_lll_transform = zz_sparse.lll_transform()
  let sparse_recomposed = sparse_lll_transform.1
    .to_dense()
    .matmul(zz_sparse.to_dense())
    .to_string()
  guard mx_trim(sparse_recomposed) ==
    mx_trim(sparse_lll_transform.0.to_dense().to_string()) else {
    fail("sdm lll_transform reconstruction mismatch")
  }
  let sparse_hnf_transformed = @sympy_polys.matrix_hnf_code(
    try! ddm_to_int_rows(sparse_lll_transform.0.to_dense()),
  )
  guard sparse_hnf_orig == sparse_hnf_transformed else {
    fail("sdm lll_transform lattice mismatch")
  }
}

///|
test "matrices: DDM and SDM constructor/accessor helpers" {
  let rows = [
    [
      try! fe_from_int(1, Domain::ZZ),
      try! fe_from_int(2, Domain::ZZ),
      try! fe_from_int(3, Domain::ZZ),
    ],
    [
      try! fe_from_int(4, Domain::ZZ),
      try! fe_from_int(5, Domain::ZZ),
      try! fe_from_int(6, Domain::ZZ),
    ],
    [
      try! fe_from_int(7, Domain::ZZ),
      try! fe_from_int(8, Domain::ZZ),
      try! fe_from_int(9, Domain::ZZ),
    ],
  ]
  let ddm = DDM::from_list(rows, (3, 3), Domain::ZZ)
  guard fe_to_string(ddm.getitem(1, -2)) == "5" else {
    fail("ddm getitem mismatch")
  }
  let ddm_set = ddm.setitem(-1, -1, try! fe_from_int(10, Domain::ZZ))
  guard ddm_set.to_domain_matrix().getitem(-1, -1).to_string() == "10" else {
    fail("ddm setitem mismatch")
  }
  let ddm_slice = ddm.extract_slice(
    row_start=Some(1),
    row_stop=Some(3),
    col_stop=Some(-2),
  )
  guard ddm_slice.to_domain_matrix().to_matrix_string() == "Matrix([[4], [7]])" else {
    fail(
      "ddm extract_slice mismatch: \{ddm_slice.to_domain_matrix().to_matrix_string()}",
    )
  }
  let ddm_flat = Array::from_iter(ddm.flatiter()).map(fe_to_string).join(",")
  guard ddm_flat == "1,2,3,4,5,6,7,8,9" else {
    fail("ddm flatiter mismatch: \{ddm_flat}")
  }
  let ddm_copy = DDM::from_ddm(ddm)
  guard ddm_copy.to_string() == ddm.to_string() else {
    fail("ddm from_ddm mismatch")
  }

  let dod : DomainMatrixDOD = Map::new()
  let row0 : Map[Int, FieldElem] = Map::new()
  row0[1] = try! fe_from_int(1, Domain::ZZ)
  dod[0] = row0
  let sdm = SDM::new(dod, (2, 2), Domain::ZZ)
  guard fe_to_string(sdm.getitem(-2, -1)) == "1" else {
    fail("sdm getitem mismatch")
  }
  let sdm_set = sdm.setitem(1, 0, try! fe_from_int(2, Domain::ZZ))
  guard sdm_set
    .extract_slice(
      row_start=Some(1),
      row_stop=Some(2),
      col_start=Some(0),
      col_stop=Some(1),
    )
    .to_dense()
    .to_domain_matrix()
    .to_matrix_string() ==
    "Matrix([[2]])" else {
    fail("sdm extract_slice/setitem mismatch")
  }
  let sdm_from_list = SDM::from_list(
    [
      [try! fe_from_int(1, Domain::ZZ), try! fe_from_int(0, Domain::ZZ)],
      [try! fe_from_int(0, Domain::ZZ), try! fe_from_int(1, Domain::ZZ)],
    ],
    (2, 2),
    Domain::ZZ,
  )
  guard mx_trim(sdm_from_list.to_dense().to_domain_matrix().to_matrix_string()) ==
    mx_trim("Matrix([[1, 0], [0, 1]])") else {
    fail("sdm from_list mismatch")
  }
}

///|
test "matrices: DFM fallback and scalar sympy helpers" {
  let ddm = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  guard mx_trim(ddm.to_dfm().to_string()) == mx_trim(ddm.to_string()) else {
    fail("ddm to_dfm fallback mismatch")
  }
  guard mx_trim(ddm.to_dfm_or_ddm().to_string()) == mx_trim(ddm.to_string()) else {
    fail("ddm to_dfm_or_ddm fallback mismatch")
  }

  let sdm = SDM::from_ddm(ddm)
  guard mx_trim(sdm.to_domain_matrix().to_matrix_string()) ==
    mx_trim("Matrix([[1, 2], [3, 4]])") else {
    fail("sdm from_ddm/to_domain_matrix mismatch")
  }
  guard mx_trim(sdm.to_dfm().to_string()) == mx_trim(ddm.to_string()) else {
    fail("sdm to_dfm fallback mismatch")
  }
  guard mx_trim(sdm.to_dfm_or_ddm().to_string()) == mx_trim(ddm.to_string()) else {
    fail("sdm to_dfm_or_ddm fallback mismatch")
  }

  let scalar = DomainScalar::from_sympy(try! @symcore.rational_from_ints(1, 2))
  let oracle_scalar = @sympy_polys.domainscalar_from_expr("1/2")
  let ours_scalar = "\{scalar.to_string()}@\{domain_to_sympy_string(scalar.domain)}"
  guard mx_trim(ours_scalar) == mx_trim(oracle_scalar) else {
    fail(
      "domainscalar from_sympy mismatch: ours=\{ours_scalar}, oracle=\{oracle_scalar}",
    )
  }
  guard @symprint.to_string(scalar.to_sympy()) == "1/2" else {
    fail("domainscalar to_sympy mismatch")
  }
  let scalar_new = DomainScalar::new(
    try! fe_from_int(3, Domain::ZZ),
    Domain::ZZ,
  )
  guard scalar_new.to_string() == "3" else { fail("domainscalar new mismatch") }
}

///|
test "matrices: DomainScalar coercion and arithmetic" {
  let a = domain_scalar_from_int(2, Domain::ZZ)
  let b = domain_scalar_from_int(1, Domain::QQ)
  let c = a.add(b)
  guard c.domain is Domain::QQ else {
    fail("domain scalar unify should promote to QQ")
  }
  guard c.to_string() == "3" else { fail("domain scalar add mismatch") }

  let d = c.mul(domain_scalar_from_int(2, Domain::QQ))
  guard d.to_string() == "6" else { fail("domain scalar mul mismatch") }

  guard c.convert_to(Domain::QQ).to_string() == "3" else {
    fail("domain scalar convert_to mismatch")
  }
  let q = domain_scalar_from_int(7, Domain::ZZ).floordiv(
    domain_scalar_from_int(3, Domain::ZZ),
  )
  let r = domain_scalar_from_int(7, Domain::ZZ).mod(
    domain_scalar_from_int(3, Domain::ZZ),
  )
  guard q.to_string() == "2" && r.to_string() == "1" else {
    fail("domain scalar floordiv/mod mismatch")
  }
  let qr = domain_scalar_from_int(7, Domain::ZZ).divmod(
    domain_scalar_from_int(3, Domain::ZZ),
  )
  guard qr.0.to_string() == "2" && qr.1.to_string() == "1" else {
    fail("domain scalar divmod mismatch")
  }
  guard domain_scalar_from_int(2, Domain::ZZ).pos().to_string() == "2" else {
    fail("domain scalar pos mismatch")
  }
  guard domain_scalar_from_int(2, Domain::ZZ).neg().to_string() == "-2" else {
    fail("domain scalar neg mismatch")
  }
}

///|
test "matrices: linsolve unique/no-solution/parametric" {
  let a = ddm_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = [fe_from_int(5, Domain::QQ), fe_from_int(11, Domain::QQ)]
  match linear_solve(a, b) {
    LinearSolveResult::Unique(sol) => {
      guard sol.length() == 2 else { fail("unique solution length") }
      guard fe_to_string(sol[0]) == "1" && fe_to_string(sol[1]) == "2" else {
        fail("unique solution mismatch")
      }
    }
    _ => fail("expected unique solution")
  }

  let a2 = ddm_from_ints([[1, 1], [1, 1]], Domain::QQ)
  let b2 = [fe_from_int(1, Domain::QQ), fe_from_int(2, Domain::QQ)]
  guard linear_solve(a2, b2) is LinearSolveResult::NoSolution else {
    fail("expected inconsistent system")
  }

  let a3 = ddm_from_ints([[1, 1]], Domain::QQ)
  let b3 = [fe_from_int(0, Domain::QQ)]
  match linear_solve(a3, b3) {
    LinearSolveResult::Parametric(exprs, params) => {
      guard params.length() == 1 else { fail("param count mismatch") }
      guard params[0] == "t1" else { fail("param naming mismatch") }
      guard exprs.length() == 2 else { fail("solution arity mismatch") }
      guard mx_expr_norm(exprs[0]) == "-t1" && mx_expr_norm(exprs[1]) == "t1" else {
        fail("parametric solution mismatch")
      }
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
  let ours = sympy_dict_to_dm(coeffs, rhs, syms)
  let oracle = @sympy_polys.linsolve_sympy_dict_to_dm_summary(
    [{ "x": "1", "y": "2" }, { "y": "1" }],
    ["3", "1"],
    syms,
  )
  guard mx_trim(sdm_summary_like_oracle(ours)) == mx_trim(oracle) else {
    fail(
      "sympy_dict_to_dm mismatch: ours=\{sdm_summary_like_oracle(ours)}, oracle=\{oracle}",
    )
  }
}
