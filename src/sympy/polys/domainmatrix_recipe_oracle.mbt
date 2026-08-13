///|
fn domainmatrix_structural_source() -> String {
  (
    #|def _symbit_domainmatrix_matrix_text(matrix):
    #|    return str(matrix.to_Matrix())
    #|
    #|def _symbit_domainmatrix_summary(matrix):
    #|    return (
    #|        str(matrix.to_Matrix())
    #|        + "@" + str(matrix.domain)
    #|        + "|" + str(matrix.rep.fmt)
    #|    )
    #|
    #|def _symbit_domainmatrix_unify_text(result):
    #|    if not isinstance(result, (list, tuple)) or len(result) < 2:
    #|        raise ValueError("domainmatrix-unify")
    #|    return (
    #|        _symbit_domainmatrix_summary(result[0])
    #|        + "||"
    #|        + _symbit_domainmatrix_summary(result[1])
    #|    )
  )
}

///|
priv struct DomainMatrixRecipe {
  domain_recipe : DomainRecipe
  domainmatrix_class : @recipe.ValueRef
  matrix_renderer : @recipe.ValueRef
  summary_renderer : @recipe.ValueRef
  unify_renderer : @recipe.ValueRef
}

///|
fn DomainMatrixRecipe::new() -> DomainMatrixRecipe raise {
  let domain_recipe = DomainRecipe::new()
  let matrices = domain_recipe.builder.import_module("sympy.polys.matrices")
  let domainmatrix_class = domain_recipe.builder.getattr(
    matrices, "DomainMatrix",
  )
  let scope = domain_recipe.builder.exec(
    domain_recipe.scope,
    domainmatrix_structural_source(),
  )
  let matrix_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_matrix_text"),
  )
  let summary_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_summary"),
  )
  let unify_renderer = domain_recipe.builder.getitem(
    scope,
    Str("_symbit_domainmatrix_unify_text"),
  )
  {
    domain_recipe,
    domainmatrix_class,
    matrix_renderer,
    summary_renderer,
    unify_renderer,
  }
}

///|
fn rectangular_expr_shape(
  rows : Array[Array[String]],
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
fn DomainMatrixRecipe::domain(
  self : DomainMatrixRecipe,
  domain_spec : String,
) -> @recipe.ValueRef raise {
  self.domain_recipe.domain(domain_spec)
}

///|
fn DomainMatrixRecipe::shape(
  self : DomainMatrixRecipe,
  row_count : Int,
  column_count : Int,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.tuple([
    DecimalInt(Show::to_string(row_count)),
    DecimalInt(Show::to_string(column_count)),
  ])
}

///|
fn DomainMatrixRecipe::domain_int(
  self : DomainMatrixRecipe,
  domain : @recipe.ValueRef,
  value : Int,
) -> @recipe.ValueRef raise {
  let convert = self.domain_recipe.builder.getattr(domain, "convert")
  self.domain_recipe.builder.call(convert, [DecimalInt(Show::to_string(value))])
}

///|
fn DomainMatrixRecipe::domain_int_list(
  self : DomainMatrixRecipe,
  values : Array[Int],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for value in values {
    encoded.push(Ref(self.domain_int(domain, value)))
  }
  self.domain_recipe.builder.list(encoded)
}

///|
fn DomainMatrixRecipe::domain_int_rows(
  self : DomainMatrixRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    encoded_rows.push(Ref(self.domain_int_list(row, domain)))
  }
  self.domain_recipe.builder.list(encoded_rows)
}

///|
fn DomainMatrixRecipe::flat_domain_ints(
  self : DomainMatrixRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for row in rows {
    for value in row {
      encoded.push(Ref(self.domain_int(domain, value)))
    }
  }
  self.domain_recipe.builder.list(encoded)
}

///|
fn DomainMatrixRecipe::domainmatrix(
  self : DomainMatrixRecipe,
  rows : Array[Array[Int]],
  domain : @recipe.ValueRef,
  fmt? : String = "dense",
) -> @recipe.ValueRef raise {
  let (row_count, column_count) = rectangular_shape(rows, "domainmatrix-ragged")
  let data = self.domain_int_rows(rows, domain)
  let shape = self.shape(row_count, column_count)
  let dense = self.domain_recipe.builder.call(self.domainmatrix_class, [
    Ref(data),
    Ref(shape),
    Ref(domain),
  ])
  match fmt {
    "dense" => dense
    "sparse" => self.call_method(dense, "to_sparse", [])
    _ => fail("domainmatrix-fmt")
  }
}

///|
fn DomainMatrixRecipe::expr_rows(
  self : DomainMatrixRecipe,
  rows : Array[Array[String]],
  error_message : String,
) -> (@recipe.ValueRef, Int, Int) raise {
  let (row_count, column_count) = rectangular_expr_shape(rows, error_message)
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    let encoded_row : Array[@recipe.RecipeArg] = []
    for value in row {
      encoded_row.push(Ref(self.domain_recipe.sympify(value)))
    }
    encoded_rows.push(Ref(self.domain_recipe.builder.list(encoded_row)))
  }
  (self.domain_recipe.builder.list(encoded_rows), row_count, column_count)
}

///|
fn DomainMatrixRecipe::matrix_from_exprs(
  self : DomainMatrixRecipe,
  rows : Array[Array[String]],
) -> @recipe.ValueRef raise {
  let (data, _, _) = self.expr_rows(rows, "domainmatrix-from-matrix-ragged")
  let matrix_class = self.domain_recipe.builder.getattr(
    self.domain_recipe.sympy,
    "Matrix",
  )
  self.domain_recipe.builder.call(matrix_class, [Ref(data)])
}

///|
fn DomainMatrixRecipe::scalar_expr(
  self : DomainMatrixRecipe,
  source : String,
) -> @recipe.ValueRef raise {
  try @string.parse_int(source.trim()) catch {
    _ => self.domain_recipe.sympify(source)
  } noraise {
    value =>
      self.domain_recipe.builder.value(DecimalInt(Show::to_string(value)))
  }
}

///|
fn DomainMatrixRecipe::call_method(
  self : DomainMatrixRecipe,
  object : @recipe.ValueRef,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.domain_recipe.builder.getattr(object, name)
  self.domain_recipe.builder.call(callable, args, kwargs~)
}

///|
fn DomainMatrixRecipe::call_class_method(
  self : DomainMatrixRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  self.call_method(self.domainmatrix_class, name, args, kwargs~)
}

///|
fn DomainMatrixRecipe::render_matrix(
  self : DomainMatrixRecipe,
  matrix : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.matrix_renderer, [Ref(matrix)])
}

///|
fn DomainMatrixRecipe::render_summary(
  self : DomainMatrixRecipe,
  matrix : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.summary_renderer, [Ref(matrix)])
}

///|
fn DomainMatrixRecipe::render_unify(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.unify_renderer, [Ref(result)])
}

///|
fn DomainMatrixRecipe::request_str(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  self.domain_recipe.builder.request_str(result)
}

///|
fn DomainMatrixRecipe::request_int(
  self : DomainMatrixRecipe,
  result : @recipe.ValueRef,
) -> Int raise {
  parse_domain_int(self.domain_recipe.builder.request_int(result))
}

///|
fn structural_domain_options(
  field : Bool,
  gaussian : Bool,
  modulus : Int?,
) -> Map[String, @recipe.RecipeArg] {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if field {
    kwargs["field"] = Bool(true)
  }
  if gaussian {
    kwargs["gaussian"] = Bool(true)
  }
  match modulus {
    Some(value) => kwargs["modulus"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  kwargs
}
