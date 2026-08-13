///|
test "polys DomainMatrix structural worker facade is request scoped" {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("ZZ")
  let matrix = recipe.domainmatrix([[1]], domain)
  assert_eq(recipe.request_str(recipe.render_matrix(matrix)), "Matrix([[1]])")
}

///|
test "polys DomainMatrix worker preserves arithmetic formats and conversion" {
  assert_eq(
    domainmatrix_add([[1, 2], [3, 4]], [[5, 6], [7, 8]], "ZZ"),
    "Matrix([[6, 8], [10, 12]])",
  )
  assert_eq(
    domainmatrix_mul([[1, 2], [3, 4]], 2, "ZZ"),
    "Matrix([[2, 4], [6, 8]])",
  )
  assert_eq(
    domainmatrix_matmul([[1, 2], [3, 4]], [[5, 6], [7, 8]], "ZZ"),
    "Matrix([[19, 22], [43, 50]])",
  )
  assert_eq(
    domainmatrix_truediv_summary([[1, 2], [3, 4]], "ZZ", "2", fmt="sparse"),
    "Matrix([[1/2, 1], [3/2, 2]])@QQ|sparse",
  )
  assert_eq(
    domainmatrix_convert_to([[1, 2], [3, 4]], "ZZ", "QQ"),
    "Matrix([[1, 2], [3, 4]])",
  )
  assert_eq(
    domainmatrix_convert_to_summary([[0, 1], [2, 0]], "ZZ", "QQ", fmt="sparse"),
    "Matrix([[0, 1], [2, 0]])@QQ|sparse",
  )
  assert_eq(
    domainmatrix_to_field([[1, 2], [3, 4]], "ZZ"),
    "Matrix([[1, 2], [3, 4]])",
  )
}

///|
test "polys DomainMatrix worker preserves structural roundtrips" {
  let rows = [[1, 2], [3, 4]]
  assert_eq(domainmatrix_diagonal(rows, "ZZ"), "[1, 4]")
  assert_eq(domainmatrix_to_list_flat(rows, "ZZ"), "[1, 2, 3, 4]")
  assert_eq(domainmatrix_from_list_flat(rows, "ZZ"), "Matrix([[1, 2], [3, 4]])")
  assert_eq(
    domainmatrix_to_flat_nz(rows, "ZZ"),
    "([1, 2, 3, 4], (((0, 0), (0, 1), (1, 0), (1, 1)), (2, 2)))",
  )
  assert_eq(
    domainmatrix_to_dod(rows, "ZZ"),
    "{0: {0: 1, 1: 2}, 1: {0: 3, 1: 4}}",
  )
  assert_eq(
    domainmatrix_from_dod_roundtrip(rows, "ZZ"),
    "Matrix([[1, 2], [3, 4]])",
  )
  assert_eq(
    domainmatrix_to_dok(rows, "ZZ"),
    "{(0, 0): 1, (0, 1): 2, (1, 0): 3, (1, 1): 4}",
  )
  assert_eq(
    domainmatrix_from_dok_roundtrip(rows, "ZZ"),
    "Matrix([[1, 2], [3, 4]])",
  )
  assert_eq(domainmatrix_nnz(rows, "ZZ"), 4)
  assert_eq(
    domainmatrix_pow([[1, 1], [0, 1]], "ZZ", 3),
    "Matrix([[1, 3], [0, 1]])",
  )
  assert_eq(
    domainmatrix_scc(
      [[6, -1, 0, 0], [9, 12, 0, 0], [0, 0, 1, 2], [0, 0, 5, 6]],
      "ZZ",
    ),
    "[[0, 1], [2, 3]]",
  )
}

///|
test "polys DomainMatrix worker preserves constructors and option presence" {
  let expr_rows = [["1/2", "2"], ["3", "4"]]
  assert_eq(
    domainmatrix_from_list_sympy_expr(expr_rows),
    "Matrix([[1/2, 2], [3, 4]])@QQ|dense",
  )
  assert_eq(
    domainmatrix_from_matrix_expr(expr_rows, fmt="sparse"),
    "Matrix([[1/2, 2], [3, 4]])@QQ|sparse",
  )
  assert_eq(
    domainmatrix_choose_domain([[1, 2], [3, 4]], "ZZ", field=true),
    "Matrix([[1, 2], [3, 4]])@QQ|dense",
  )
  assert_eq(
    domainmatrix_choose_domain([[1, 2], [3, 4]], "ZZ"),
    "Matrix([[1, 2], [3, 4]])@ZZ|dense",
  )
}

///|
test "polys DomainMatrix worker preserves stacking and explicit unify format" {
  let sparse_rows = [[0, 1], [2, 0]]
  let dense_rows = [[1, 2], [3, 4]]
  assert_eq(
    domainmatrix_hstack_summary(
      sparse_rows, "ZZ", "sparse", dense_rows, "QQ", "dense",
    ),
    "Matrix([[0, 1, 1, 2], [2, 0, 3, 4]])@QQ|sparse",
  )
  assert_eq(
    domainmatrix_vstack_summary(
      sparse_rows, "ZZ", "sparse", dense_rows, "QQ", "dense",
    ),
    "Matrix([[0, 1], [2, 0], [1, 2], [3, 4]])@QQ|dense",
  )
  assert_eq(
    domainmatrix_unify_summary(
      sparse_rows, "ZZ", "sparse", dense_rows, "QQ", "dense",
    ),
    "Matrix([[0, 1], [2, 0]])@QQ|sparse||Matrix([[1, 2], [3, 4]])@QQ|dense",
  )
  assert_eq(
    domainmatrix_unify_summary(
      sparse_rows,
      "ZZ",
      "sparse",
      dense_rows,
      "QQ",
      "dense",
      fmt="dense",
    ),
    "Matrix([[0, 1], [2, 0]])@QQ|dense||Matrix([[1, 2], [3, 4]])@QQ|dense",
  )
}

///|
test "polys DomainMatrix worker rejects ragged constructors then recovers" {
  let from_list_ragged = try {
    domainmatrix_from_list_sympy_expr([["1"], ["2", "3"]]) |> ignore
    false
  } catch {
    _ => true
  }
  let from_matrix_ragged = try {
    domainmatrix_from_matrix_expr([["1"], ["2", "3"]]) |> ignore
    false
  } catch {
    _ => true
  }
  let int_ragged = try {
    domainmatrix_add([[1], [2, 3]], [[1], [2]], "ZZ") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(from_list_ragged)
  assert_true(from_matrix_ragged)
  assert_true(int_ragged)
  assert_eq(domainmatrix_nnz([[7]], "ZZ"), 1)
}
