///|
test "polys matrix SDM worker preserves the raw domain suffix" {
  let recipe = MatrixSdmRecipe::new()
  let domain = recipe.domain("  ZZ  ")
  let (matrix, _, _) = recipe.sdm([[0, 2], [1, 0]], domain)
  assert_eq(
    recipe.request_str(recipe.render_dense_summary(matrix, "  ZZ  ")),
    "[[0, 2], [1, 0]]@  ZZ  |sparse",
  )
}

///|
test "polys matrix SDM worker preserves functional outputs" {
  let a = [[0, 2], [1, 0]]
  let b = [[3, 0], [0, 4]]
  let dense = [[1, 2], [3, 4]]
  assert_eq(sdm_transpose_summary(a, "ZZ"), "[[0, 1], [2, 0]]@ZZ|sparse")
  assert_eq(sdm_matmul_summary(a, b, "ZZ"), "[[0, 8], [3, 0]]@ZZ|sparse")
  assert_eq(sdm_rref_den_summary(dense, "ZZ"), "({0:{0:-2},1:{1:-2}},-2,[0,1])")
  assert_eq(sdm_berk_summary(dense, "ZZ"), "{0:1,1:-5,2:-2}")
}

///|
test "polys matrix SDM worker rejects ragged input" {
  let rejected = try {
    sdm_transpose_summary([[1], [2, 3]], "ZZ") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys matrix SDM worker rejects None and recovers" {
  let recipe = MatrixSdmRecipe::new()
  let none = recipe.domainmatrix_recipe.domain_recipe.builder.value(Null)
  let rejected = try {
    recipe.request_str(recipe.render_compact(none)) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(sdm_berk_summary([[7]], "ZZ"), "{0:1,1:-7}")
}
