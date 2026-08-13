///|
fn matrix_sdm_source() -> String {
  (
    #|def _symbit_matrix_sdm_dense_summary(matrix, domain_spec):
    #|    if matrix is None:
    #|        raise ValueError("matrix-sdm-none")
    #|    dense = matrix.to_ddm()
    #|    if dense is None:
    #|        raise ValueError("matrix-sdm-dense-none")
    #|    return str(dense) + "@" + domain_spec + "|sparse"
    #|
    #|def _symbit_matrix_sdm_compact(value):
    #|    if value is None:
    #|        raise ValueError("matrix-sdm-result-none")
    #|    return str(value).replace(" ", "")
  )
}

///|
priv struct MatrixSdmRecipe {
  domainmatrix_recipe : DomainMatrixRecipe
  sdm_class : @recipe.ValueRef
  dense_summary_renderer : @recipe.ValueRef
  compact_renderer : @recipe.ValueRef
}

///|
fn MatrixSdmRecipe::new() -> MatrixSdmRecipe raise {
  let domainmatrix_recipe = DomainMatrixRecipe::new()
  let builder = domainmatrix_recipe.domain_recipe.builder
  let sdm_module = builder.import_module("sympy.polys.matrices.sdm")
  let sdm_class = builder.getattr(sdm_module, "SDM")
  let scope = builder.exec(
    domainmatrix_recipe.domain_recipe.scope,
    matrix_sdm_source(),
  )
  let dense_summary_renderer = builder.getitem(
    scope,
    Str("_symbit_matrix_sdm_dense_summary"),
  )
  let compact_renderer = builder.getitem(
    scope,
    Str("_symbit_matrix_sdm_compact"),
  )
  { domainmatrix_recipe, sdm_class, dense_summary_renderer, compact_renderer }
}

///|
fn MatrixSdmRecipe::domain(
  self : MatrixSdmRecipe,
  domain_spec : String,
) -> @recipe.ValueRef raise {
  self.domainmatrix_recipe.domain(domain_spec)
}

///|
fn MatrixSdmRecipe::sdm(
  self : MatrixSdmRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
) -> (@recipe.ValueRef, Int, Int) raise {
  let (row_count, column_count) = rectangular_shape(rows, "sdm-ragged")
  let data = self.domainmatrix_recipe.domain_int_rows(rows, domain)
  let shape = self.domainmatrix_recipe.shape(row_count, column_count)
  let from_list = self.domainmatrix_recipe.domain_recipe.builder.getattr(
    self.sdm_class,
    "from_list",
  )
  let result = self.domainmatrix_recipe.domain_recipe.builder.call(from_list, [
    Ref(data),
    Ref(shape),
    Ref(domain),
  ])
  let matrix = self.domainmatrix_recipe.domain_recipe.builder.require_non_none(
    result,
    message="matrix-sdm-from-list-none",
  )
  (matrix, row_count, column_count)
}

///|
fn MatrixSdmRecipe::sdm_from_raw(
  self : MatrixSdmRecipe,
  raw : @recipe.ValueRef,
  row_count : Int,
  column_count : Int,
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let shape = self.domainmatrix_recipe.shape(row_count, column_count)
  let result = self.domainmatrix_recipe.domain_recipe.builder.call(
    self.sdm_class,
    [Ref(raw), Ref(shape), Ref(domain)],
  )
  self.domainmatrix_recipe.domain_recipe.builder.require_non_none(
    result,
    message="matrix-sdm-constructor-none",
  )
}

///|
fn MatrixSdmRecipe::call_path(
  self : MatrixSdmRecipe,
  path : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  self.domainmatrix_recipe.call_path(path, args)
}

///|
fn MatrixSdmRecipe::render_dense_summary(
  self : MatrixSdmRecipe,
  matrix : @recipe.ValueRef,
  domain_spec : String,
) -> @recipe.ValueRef raise {
  self.domainmatrix_recipe.domain_recipe.builder.call(
    self.dense_summary_renderer,
    [Ref(matrix), Str(domain_spec)],
  )
}

///|
fn MatrixSdmRecipe::render_compact(
  self : MatrixSdmRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domainmatrix_recipe.domain_recipe.builder.call(self.compact_renderer, [
    Ref(result),
  ])
}

///|
fn MatrixSdmRecipe::request_str(
  self : MatrixSdmRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  self.domainmatrix_recipe.request_str(result)
}
