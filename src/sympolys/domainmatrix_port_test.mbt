///|
fn dm_trim(s : String) -> String {
  s.replace_all(old=" ", new="")
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
test "domainmatrix: inverse parity over QQ" {
  let a = domain_matrix_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let ours = a.inv().to_matrix_string()
  let oracle = @sympy_polys.domainmatrix_inv([[1, 2], [3, 5]], "QQ")
  guard dm_trim(ours) == dm_trim(oracle) else {
    fail("domainmatrix inv mismatch: ours=\{ours}, oracle=\{oracle}")
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
test "domainmatrix: elimination does not mutate the input matrix" {
  let a = domain_matrix_from_ints([[1, 2], [3, 5]], Domain::QQ)
  let _ = a.det()
  let _ = a.rref()
  let _ = a.inv()
  guard dm_trim(a.to_matrix_string()) == dm_trim("Matrix([[1, 2], [3, 5]])") else {
    fail("domainmatrix operations should not mutate the receiver")
  }
}
