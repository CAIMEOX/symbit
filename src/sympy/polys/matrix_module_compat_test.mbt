///|
fn mm_trim(s : String) -> String {
  s.replace_all(old=" ", new="").replace_all(old="\n", new="")
}

///|
fn mm_expr_matrix_text(rows : MatrixExpr) -> String {
  let row_text : Array[String] = Array::new()
  for row in rows {
    let cells = row.map(@symprint.pretty_string).join(", ")
    row_text.push("[\{cells}]")
  }
  let joined = row_text.join(", ")
  "Matrix([\{joined}])"
}

///|
fn mm_sympy_eigen_text(items : SympyEigenvects) -> String {
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(
      "\{@symprint.pretty_string(item.0)}:\{item.1}:\{mm_expr_matrix_text(item.2)}",
    )
  }
  parts.sort()
  parts.join("||")
}

///|
test "matrix module wrappers: lll wrappers align with methods" {
  let a = @sympolys.ddm_from_ints([[1, 0, 0], [0, 1, 0], [1, 1, 1]], ZZ)
  assert_eq(
    mm_trim(@sympolys.ddm_lll(a).to_string()),
    mm_trim(a.lll().to_string()),
  )
  let ours = @sympolys.ddm_lll_transform(a)
  let methods = a.lll_transform()
  assert_eq(mm_trim(ours.0.to_string()), mm_trim(methods.0.to_string()))
  assert_eq(mm_trim(ours.1.to_string()), mm_trim(methods.1.to_string()))
}

///|
test "matrix module wrappers: normalform wrappers match methods and oracle" {
  let rows = [[12, 6, 4], [3, 9, 6], [2, 16, 14]]
  let dm = @sympolys.domain_matrix_from_ints(rows, ZZ)
  assert_eq(
    mm_trim(@sympolys.hermite_normal_form(dm).to_matrix_string()),
    mm_trim(
      dm.to_ddm().hermite_normal_form().to_domain_matrix().to_matrix_string(),
    ),
  )
  let invs = @sympolys.invariant_factors(dm)
  let ours_invs = if invs.is_empty() {
    "()"
  } else if invs.length() == 1 {
    "(\{Show::to_string(invs[0])},)"
  } else {
    let joined = invs.map(fe_to_string).join(", ")
    "(\{joined})"
  }
  let oracle_invs = domainmatrix_invariant_factors(rows, "ZZ")
  assert_eq(mm_trim(ours_invs), mm_trim(oracle_invs))
  let smf = @sympolys.smith_normal_form(dm)
  let oracle_smf = domainmatrix_smith_normal_form(rows, "ZZ")
  assert_eq(mm_trim(smf.to_matrix_string()), mm_trim(oracle_smf))
  assert_true(@sympolys.is_smith_normal_form(smf))
  let decomp = @sympolys.smith_normal_decomp(dm)
  assert_eq(
    mm_trim(
      decomp.1
      .to_field()
      .matmul(dm.to_field())
      .matmul(decomp.2.to_field())
      .to_matrix_string(),
    ),
    mm_trim(decomp.0.to_field().to_matrix_string()),
  )
}

///|
test "matrix module wrappers: eigen wrappers preserve method data" {
  let dm = @sympolys.domain_matrix_from_ints([[1, 0], [0, 2]], QQ)
  let wrapped = @sympolys.dom_eigenvects(dm)
  let expected = dm.dom_eigenvects()
  let wrapped_rational = wrapped.0.map(item => {
    (Show::to_string(item.1), item.2, item.3.to_matrix_string())
  })
  let expected_rational = expected.0.map(item => {
    (Show::to_string(item.1), item.2, item.3.to_matrix_string())
  })
  assert_eq(wrapped_rational, expected_rational)
  let sympy_view = @sympolys.dom_eigenvects_to_sympy(wrapped.0, wrapped.1)
  assert_eq(
    mm_sympy_eigen_text(sympy_view),
    "1:1:Matrix([[1, 0]])||2:1:Matrix([[0, 1]])",
  )
}

///|
test "matrix module wrappers: add_columns and symmetric_residue helpers" {
  let m = @sympolys.ddm_from_ints([[1, 2], [3, 4]], ZZ)
  let out = @sympolys.add_columns(
    m,
    0,
    1,
    @sympolys.fe_from_int(1, ZZ),
    @sympolys.fe_from_int(1, ZZ),
    @sympolys.fe_from_int(0, ZZ),
    @sympolys.fe_from_int(1, ZZ),
  )
  assert_eq(mm_trim(out.to_string()), mm_trim("[[3, 2], [7, 4]]"))
  assert_eq(
    @sympolys.symmetric_residue(BigInt::from_int(4), BigInt::from_int(5)).to_int(),
    -1,
  )
}

///|
test "matrix module wrappers: dup_factor_list exposes dense factors for charpoly data" {
  let f = [
    @sympolys.fe_from_int(1, ZZ),
    @sympolys.fe_from_int(-1, ZZ),
    @sympolys.fe_from_int(-2, ZZ),
  ]
  let (content, factors) = @sympolys.dup_factor_list(f, ZZ)
  assert_eq(Show::to_string(content), "1")
  let parts : Array[String] = Array::new()
  for factor in factors {
    let coeffs = factor.0.map(fe_to_string).join(", ")
    parts.push("[\{coeffs}]^\{factor.1}")
  }
  parts.sort()
  let factors_text = parts.join("||")
  assert_eq(mm_trim(factors_text), mm_trim("[1, 1]^1||[1, -2]^1"))
}
