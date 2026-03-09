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
fn dm_rat(num : Int, den : Int) -> FieldElem raise PolyError {
  fe_from_rational(
    try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den)),
    Domain::QQ,
  )
}

///|
test "domainmatrix: add/mul parity over QQ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 4]], Domain::QQ)
  let b = domain_matrix_from_ints([[5, 6], [7, 8]], Domain::QQ)

  let ours_add = a.add(b).to_matrix_string()
  let ours_mul = a.mul(b).to_matrix_string()

  let oracle_add = @sympy_polys.domainmatrix_add(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )
  let oracle_mul = @sympy_polys.domainmatrix_mul(
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]],
    "QQ",
  )

  guard dm_trim(ours_add) == dm_trim(oracle_add) else {
    fail("domainmatrix add mismatch: ours=\{ours_add}, oracle=\{oracle_add}")
  }
  guard dm_trim(ours_mul) == dm_trim(oracle_mul) else {
    fail("domainmatrix mul mismatch: ours=\{ours_mul}, oracle=\{oracle_mul}")
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
