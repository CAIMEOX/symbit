///|
fn ms_trim(s : String) -> String {
  s.replace_all(old=" ", new="").replace_all(old="\n", new="")
}

///|
fn ms_nonzero_cols_text(nonzero_cols : Map[Int, Array[Int]]) -> String {
  let items : Array[(Int, String)] = Array::new()
  for col, rows in nonzero_cols {
    let sorted_rows = rows.copy()
    sorted_rows.sort()
    let joined_rows = sorted_rows.map(r => r.to_string()).join(", ")
    items.push((col, "[\{joined_rows}]"))
  }
  items.sort_by((lhs, rhs) => lhs.0 - rhs.0)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push("\{item.0}: \{item.1}")
  }
  let joined_parts = parts.join(", ")
  "{\{joined_parts}}"
}

///|
test "matrix sparse wrappers: sdm_irref and RREF helpers align with methods" {
  let a = ddm_from_ints([[1, 2, 3], [0, 1, 1]], Domain::QQ).to_sdm()
  let (rref, pivots, nonzero_cols) = sdm_irref(a)
  let (expected_rref, expected_pivots) = a.rref()
  guard pivots == expected_pivots else {
    fail("sdm_irref pivot mismatch")
  }
  guard ms_trim(rref.to_dense().to_string()) == ms_trim(expected_rref.to_dense().to_string()) else {
    fail("sdm_irref matrix mismatch")
  }
  let oracle_rref = @sympy_polys.domainmatrix_rref([[1, 2, 3], [0, 1, 1]], "QQ")
  guard ms_trim(
    "\{rref.to_domain_matrix().to_matrix_string()}||\{pivots.to_string()}",
  ) == ms_trim(oracle_rref) else {
    fail("sdm_irref oracle mismatch")
  }
  guard ms_trim(ms_nonzero_cols_text(nonzero_cols)) == ms_trim("{2: [0, 1]}") else {
    fail("sdm_irref nonzero_cols mismatch: \{ms_nonzero_cols_text(nonzero_cols)}")
  }

  let (nullspace, nonpivots) = sdm_nullspace_from_rref(
    rref,
    fe_from_int(1, Domain::QQ),
    3,
    pivots,
    nonzero_cols,
  )
  let (expected_nullspace, expected_nonpivots) = rref.nullspace_from_rref(pivots~)
  guard nonpivots == expected_nonpivots else {
    fail("sdm_nullspace_from_rref nonpivots mismatch")
  }
  guard ms_trim(nullspace.to_dense().to_string()) == ms_trim(expected_nullspace.to_dense().to_string()) else {
    fail("sdm_nullspace_from_rref basis mismatch")
  }

  let particular = sdm_particular_from_rref(rref, 3, pivots)
  guard ms_trim(particular.to_dense().to_string()) == ms_trim(rref.particular(pivots~).to_dense().to_string()) else {
    fail("sdm_particular_from_rref mismatch")
  }
}

///|
test "matrix sparse wrappers: sdm_nullspace_from_rref accepts augmented RREF" {
  let aug = ddm_from_ints([[1, 1, 0], [0, 0, 1]], Domain::QQ).to_sdm()
  let (basis, nonpivots) = sdm_nullspace_from_rref(
    aug,
    fe_from_int(1, Domain::QQ),
    2,
    [0, 2],
    { 1: [0] },
  )
  guard nonpivots == [1] else {
    fail("augmented nonpivots mismatch")
  }
  guard ms_trim(basis.to_dense().to_string()) == ms_trim("[[-1, 1]]") else {
    fail("augmented nullspace basis mismatch: \{basis.to_dense().to_string()}")
  }
}
