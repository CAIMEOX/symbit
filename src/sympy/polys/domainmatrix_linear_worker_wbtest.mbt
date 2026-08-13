///|
test "polys DomainMatrix linear worker preserves determinant and compact pivots" {
  assert_eq(domainmatrix_det([[1, 2], [3, 4]], "ZZ"), "-2")
  assert_eq(
    domainmatrix_rref([[1, 2], [3, 4]], "QQ"),
    "Matrix([[1, 0], [0, 1]])||[0,1]",
  )
}

///|
test "polys DomainMatrix linear worker preserves rref_den kwargs" {
  let rows = [[1, 2, 3], [4, 5, 6]]
  assert_eq(
    domainmatrix_rref_den(rows, "ZZ", rref_method="GJ", keep_domain=false),
    "Matrix([[1, 0, -1], [0, 1, 2]])||1||[0,1]",
  )
  assert_eq(
    domainmatrix_rref_den(rows, "ZZ", rref_method="FF"),
    "Matrix([[-3, 0, 3], [0, -3, -6]])||-3||[0,1]",
  )
}

///|
test "polys DomainMatrix linear worker preserves LU QR solve and FFLU order" {
  assert_eq(
    domainmatrix_lu([[0, 1], [1, 1]], "QQ"),
    "Matrix([[1, 0], [0, 1]])||Matrix([[1, 1], [0, 1]])||[(0, 1)]",
  )
  assert_eq(
    domainmatrix_qr([[1, 2], [3, 4], [5, 6]], "QQ"),
    "Matrix([[1, 26/35], [3, 8/35], [5, -2/7]])||Matrix([[1, 44/35], [0, 1]])",
  )
  assert_eq(
    domainmatrix_lu_solve([[1, 2], [3, 4]], [[1], [0]], "QQ"),
    "Matrix([[-2], [3/2]])",
  )
  assert_eq(
    domainmatrix_fflu([[1, 2], [3, 4]], "ZZ"),
    "Matrix([[1, 0], [0, 1]])||Matrix([[1, 0], [3, -2]])||Matrix([[1, 0], [0, -2]])||Matrix([[1, 2], [0, -2]])",
  )
}

///|
test "polys DomainMatrix linear worker preserves charpoly outputs" {
  let rows = [[1, 2], [3, 4]]
  assert_eq(domainmatrix_charpoly(rows, "ZZ"), "[1, -5, -2]")
  assert_eq(
    domainmatrix_charpoly_factor_blocks(rows, "ZZ"),
    "[([1, -5, -2], 1)]",
  )
  assert_eq(domainmatrix_charpoly_factor_list(rows, "ZZ"), "[([1, -5, -2], 1)]")
}

///|
test "polys DomainMatrix linear worker preserves spaces and nullspace option" {
  assert_eq(
    domainmatrix_inv([[1, 2], [3, 5]], "QQ"),
    "Matrix([[-5, 2], [3, -1]])",
  )
  let rows = [[1, 2, 3], [2, 4, 6], [1, 1, 1]]
  assert_eq(domainmatrix_rowspace(rows, "QQ"), "Matrix([[1, 2, 3], [2, 4, 6]])")
  assert_eq(
    domainmatrix_columnspace(rows, "QQ"),
    "Matrix([[1, 2], [2, 4], [1, 1]])",
  )
  assert_eq(
    domainmatrix_nullspace(rows, "QQ", divide_last=true),
    "Matrix([[1, -2, 1]])",
  )
  let divide_last_rejected = try {
    domainmatrix_nullspace([[6, -3], [4, -2]], "ZZ", divide_last=true) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(divide_last_rejected)
}

///|
test "polys DomainMatrix linear tuple renderer rejects short results then recovers" {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("QQ")
  let matrix = recipe.domainmatrix([[1]], domain)
  let short_result = recipe.domain_recipe.builder.tuple([Ref(matrix)])
  let rejected = try {
    recipe.request_str(recipe.render_rref(short_result)) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(domainmatrix_det([[7]], "ZZ"), "7")
}
