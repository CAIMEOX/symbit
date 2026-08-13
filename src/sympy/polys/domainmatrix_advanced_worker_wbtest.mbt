///|
test "polys DomainMatrix advanced worker constructs expression rows in one domain" {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("QQ")
  let matrix = recipe.domainmatrix_expr([["1/2", "3/4"]], domain)
  assert_eq(
    recipe.request_str(recipe.render_summary(matrix)),
    "Matrix([[1/2, 3/4]])@QQ|dense",
  )
}

///|
test "polys DomainMatrix advanced worker preserves clear-denominator formats" {
  assert_eq(
    domainmatrix_clear_denoms([[1, 2]], "QQ"),
    "1@ZZ||Matrix([[1, 2]])@QQ",
  )
  assert_eq(
    domainmatrix_clear_denoms_expr([["1/2", "3/4"]], "QQ"),
    "4@ZZ||Matrix([[2, 3]])@QQ",
  )
  assert_eq(
    domainmatrix_clear_denoms_expr([["1/2", "3/4"]], "QQ", convert=true),
    "4@ZZ||Matrix([[2, 3]])@ZZ",
  )
  assert_eq(
    domainmatrix_clear_denoms_rowwise_expr(
      [["1/2", "1/3"], ["1/5", "1/7"]],
      "QQ",
    ),
    "Matrix([[6, 0], [0, 35]])@ZZ||Matrix([[3, 2], [7, 5]])@QQ",
  )
}

///|
test "polys DomainMatrix advanced worker preserves matrix-scalar tuples" {
  let rows = [[1, 2], [3, 4]]
  let rhs = [[5], [6]]
  assert_eq(domainmatrix_adj_det(rows, "ZZ"), "Matrix([[4, -2], [-3, 1]])||-2")
  assert_eq(domainmatrix_adjugate(rows, "ZZ"), "Matrix([[4, -2], [-3, 1]])")
  assert_eq(domainmatrix_inv_den(rows, "ZZ"), "Matrix([[4, -2], [-3, 1]])||-2")
  assert_eq(domainmatrix_solve_den(rows, rhs, "ZZ"), "Matrix([[8], [-9]])||-2")
  assert_eq(
    domainmatrix_solve_den_rref(rows, rhs, "ZZ"),
    "Matrix([[8], [-9]])||-2",
  )
}

///|
test "polys DomainMatrix advanced worker preserves domain scalar codecs" {
  let rows = [["1/2", "3/4"]]
  assert_eq(domainmatrix_content_expr(rows, "QQ"), "1/4")
  assert_eq(domainmatrix_primitive_expr(rows, "QQ"), "1/4||Matrix([[2, 3]])")
  assert_eq(
    domainmatrix_cancel_denom_expr(rows, "12", "QQ"),
    "Matrix([[2, 3]])||48",
  )
  assert_eq(
    domainmatrix_cancel_denom_elementwise_expr(rows, "12", "QQ"),
    "Matrix([[1, 1]])||Matrix([[24, 16]])",
  )
}

///|
test "polys DomainMatrix advanced worker preserves polynomial calls" {
  let rows = [[1, 2], [3, 4]]
  let rhs = [[5], [6]]
  let coefficients = ["1", "2", "3"]
  assert_eq(domainmatrix_adj_poly_det(rows, "ZZ"), "[-1, 5]||-2")
  assert_eq(
    domainmatrix_eval_poly(rows, coefficients, "ZZ"),
    "Matrix([[12, 14], [21, 33]])",
  )
  assert_eq(
    domainmatrix_eval_poly_mul(rows, coefficients, rhs, "ZZ"),
    "Matrix([[144], [303]])",
  )
  assert_eq(
    domainmatrix_solve_den_charpoly(rows, rhs, "ZZ"),
    "Matrix([[8], [-9]])||-2",
  )
}

///|
test "polys DomainMatrix advanced worker preserves LLL matrix order" {
  let rows = [[1, 0, 0], [-1, 1, 0], [0, -1, 1]]
  assert_eq(domainmatrix_lll(rows), "Matrix([[1, 0, 0], [0, 1, 0], [0, 0, 1]])")
  assert_eq(
    domainmatrix_lll_transform(rows),
    "Matrix([[1, 0, 0], [0, 1, 0], [0, 0, 1]])||Matrix([[1, 0, 0], [1, 1, 0], [1, 1, 1]])",
  )
}

///|
test "polys DomainMatrix advanced worker normalizes Smith diagonals" {
  let rows = [[12, 6, 4], [3, 9, 6], [2, 16, 14]]
  assert_eq(domainmatrix_invariant_factors(rows, "ZZ"), "(1, 10, 30)")
  assert_eq(
    domainmatrix_smith_normal_form(rows, "ZZ"),
    "Matrix([[1, 0, 0], [0, 10, 0], [0, 0, 30]])",
  )
  assert_true(
    domainmatrix_is_smith_normal_form(
      [[1, 0, 0], [0, 10, 0], [0, 0, -30]],
      "ZZ",
    ),
  )
  assert_false(domainmatrix_is_smith_normal_form(rows, "ZZ"))
  assert_eq(domainmatrix_invariant_factors([[6]], "ZZ"), "(6,)")
}

///|
test "polys DomainMatrix advanced worker preserves eigen and solve summaries" {
  assert_eq(
    domainmatrix_dom_eigenvects_summary([[1, 0], [0, 2]], "QQ"),
    "r:1:1:Matrix([[1, 0]])||r:2:1:Matrix([[0, 1]])",
  )
  assert_eq(
    domainmatrix_dom_eigenvects_summary([[0, 2], [1, 0]], "QQ"),
    "a:_lambda**2 - 2:1:Matrix([[_lambda, 1]])",
  )
  assert_eq(
    domainmatrix_internal_solve_summary([[1, 2], [2, 4]], [[1], [2]], "QQ"),
    "Matrix([[1, 0]])||Matrix([[-2, 1]])",
  )
}

///|
test "polys DomainMatrix advanced worker rejects strict shapes and recovers" {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("ZZ")
  let matrix = recipe.domainmatrix([[1]], domain)
  let short_result = recipe.domain_recipe.builder.tuple([Ref(matrix)])
  let rejected = try {
    recipe.request_str(recipe.render_advanced("adj_det", short_result))
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(
    domainmatrix_smith_normal_decomp([[2, 4], [4, 8]], "QQ"),
    "Matrix([[2, 0], [0, 0]])||Matrix([[1, 0], [-2, 1]])||Matrix([[1, -2], [0, 1]])",
  )
  let singular_rejected = try {
    domainmatrix_inv_den([[1, 2], [2, 4]], "ZZ") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(singular_rejected)
  assert_eq(domainmatrix_adjugate([[7]], "ZZ"), "Matrix([[1]])")
}
