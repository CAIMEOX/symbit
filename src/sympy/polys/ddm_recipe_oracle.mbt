///|
fn ddm_foundation_source() -> String {
  (
    #|def _symbit_ddm_rref_text(result):
    #|    if not isinstance(result, (list, tuple)) or len(result) < 2:
    #|        raise ValueError("ddm-rref-tuple")
    #|    matrix, pivots = result[0], result[1]
    #|    if not isinstance(pivots, (list, tuple)):
    #|        raise ValueError("expected list/tuple")
    #|    return str(matrix) + "||[" + ",".join(
    #|        str(int(pivot)) for pivot in pivots
    #|    ) + "]"
  )
}

///|
priv struct DdmRecipe {
  domain_recipe : DomainRecipe
}

///|
fn DdmRecipe::new() -> DdmRecipe raise {
  let domain_recipe = DomainRecipe::new()
  { domain_recipe, }
}

///|
fn rectangular_shape(
  rows : Array[Array[Int]],
  error_message : String,
) -> (Int, Int) raise {
  let row_count = rows.length()
  let column_count = if row_count == 0 { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != column_count {
      fail(error_message)
    }
  }
  (row_count, column_count)
}

///|
fn DdmRecipe::domain(
  self : DdmRecipe,
  domain_spec : String,
) -> @recipe.ValueRef raise {
  self.domain_recipe.domain(domain_spec)
}

///|
fn DdmRecipe::ddm(
  self : DdmRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let (row_count, column_count) = rectangular_shape(rows, "ddm-ragged")
  let convert = self.domain_recipe.builder.getattr(domain, "convert")
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    let encoded_row : Array[@recipe.RecipeArg] = []
    for value in row {
      let converted = self.domain_recipe.builder.call(convert, [
        DecimalInt(Show::to_string(value)),
      ])
      encoded_row.push(Ref(converted))
    }
    encoded_rows.push(Ref(self.domain_recipe.builder.list(encoded_row)))
  }
  let data = self.domain_recipe.builder.list(encoded_rows)
  let shape = self.domain_recipe.builder.tuple([
    DecimalInt(Show::to_string(row_count)),
    DecimalInt(Show::to_string(column_count)),
  ])
  let ddm_module = self.domain_recipe.builder.import_module(
    "sympy.polys.matrices.ddm",
  )
  let ddm_class = self.domain_recipe.builder.getattr(ddm_module, "DDM")
  self.domain_recipe.builder.call(ddm_class, [
    Ref(data),
    Ref(shape),
    Ref(domain),
  ])
}

///|
fn DdmRecipe::matrix(
  self : DdmRecipe,
  rows : Array[Array[Int]],
) -> @recipe.ValueRef raise {
  ignore(rectangular_shape(rows, "matrix-ragged"))
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    let encoded_row : Array[@recipe.RecipeArg] = []
    for value in row {
      encoded_row.push(DecimalInt(Show::to_string(value)))
    }
    encoded_rows.push(Ref(self.domain_recipe.builder.list(encoded_row)))
  }
  let data = self.domain_recipe.builder.list(encoded_rows)
  let matrix_class = self.domain_recipe.builder.getattr(
    self.domain_recipe.sympy,
    "Matrix",
  )
  self.domain_recipe.builder.call(matrix_class, [Ref(data)])
}

///|
fn DdmRecipe::domain_int(
  self : DdmRecipe,
  domain : @recipe.ValueRef,
  value : Int,
) -> @recipe.ValueRef raise {
  let convert = self.domain_recipe.builder.getattr(domain, "convert")
  self.domain_recipe.builder.call(convert, [DecimalInt(Show::to_string(value))])
}

///|
fn DdmRecipe::call_method(
  self : DdmRecipe,
  object : @recipe.ValueRef,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let callable = self.domain_recipe.builder.getattr(object, name)
  self.domain_recipe.builder.call(callable, args)
}

///|
fn DdmRecipe::render_rref(
  self : DdmRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let scope = self.domain_recipe.builder.exec(
    self.domain_recipe.scope,
    ddm_foundation_source(),
  )
  let renderer = self.domain_recipe.builder.getitem(
    scope,
    Str("_symbit_ddm_rref_text"),
  )
  self.domain_recipe.builder.call(renderer, [Ref(result)])
}

///|
fn DdmRecipe::request_str(
  self : DdmRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  self.domain_recipe.builder.request_str(result)
}

///|
fn DdmRecipe::request_int(
  self : DdmRecipe,
  result : @recipe.ValueRef,
) -> Int raise {
  parse_domain_int(self.domain_recipe.builder.request_int(result))
}
