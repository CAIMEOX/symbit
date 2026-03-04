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
