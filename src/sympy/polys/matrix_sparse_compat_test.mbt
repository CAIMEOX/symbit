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
  let a = @sympolys.ddm_from_ints([[1, 2, 3], [0, 1, 1]], Domain::QQ).to_sdm()
  let (rref, pivots, nonzero_cols) = @sympolys.sdm_irref(a)
  let (expected_rref, expected_pivots) = a.rref()
  assert_eq(pivots, expected_pivots)
  assert_eq(
    ms_trim(rref.to_dense().to_string()),
    ms_trim(expected_rref.to_dense().to_string()),
  )
  let oracle_rref = domainmatrix_rref([[1, 2, 3], [0, 1, 1]], "QQ")
  assert_eq(
    ms_trim(
      "\{rref.to_domain_matrix().to_matrix_string()}||\{Repr(pivots).to_string()}",
    ),
    ms_trim(oracle_rref),
  )
  assert_eq(ms_trim(ms_nonzero_cols_text(nonzero_cols)), ms_trim("{2: [0, 1]}"))

  let (nullspace, nonpivots) = @sympolys.sdm_nullspace_from_rref(
    rref,
    @sympolys.fe_from_int(1, Domain::QQ),
    3,
    pivots,
    nonzero_cols,
  )
  let (expected_nullspace, expected_nonpivots) = rref.nullspace_from_rref(
    pivots~,
  )
  assert_eq(nonpivots, expected_nonpivots)
  assert_eq(
    ms_trim(nullspace.to_dense().to_string()),
    ms_trim(expected_nullspace.to_dense().to_string()),
  )

  let particular = @sympolys.sdm_particular_from_rref(rref, 3, pivots)
  assert_eq(
    ms_trim(particular.to_dense().to_string()),
    ms_trim(rref.particular(pivots~).to_dense().to_string()),
  )
}

///|
test "matrix sparse wrappers: sdm_nullspace_from_rref accepts augmented RREF" {
  let aug = @sympolys.ddm_from_ints([[1, 1, 0], [0, 0, 1]], Domain::QQ).to_sdm()
  let (basis, nonpivots) = @sympolys.sdm_nullspace_from_rref(
    aug,
    @sympolys.fe_from_int(1, Domain::QQ),
    2,
    [0, 2],
    { 1: [0] },
  )
  assert_eq(nonpivots, [1])
  assert_eq(ms_trim(basis.to_dense().to_string()), ms_trim("[[-1, 1]]"))
}
