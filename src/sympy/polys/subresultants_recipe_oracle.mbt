///|
fn subresultants_recipe_source() -> String {
  (
    #|def _symbit_subresultants_poly_text(value):
    #|    if value is None:
    #|        raise ValueError("subresultants-poly-none")
    #|    if isinstance(value, sympy.Poly):
    #|        value = value.as_expr()
    #|    return str(value)
    #|
    #|def _symbit_subresultants_sequence(value, poly_aware):
    #|    if not isinstance(value, (list, tuple)):
    #|        raise ValueError("subresultants-sequence-shape")
    #|    if poly_aware:
    #|        return " | ".join(
    #|            _symbit_subresultants_poly_text(item) for item in value
    #|        )
    #|    return ",".join(str(item) for item in value)
  )
}

///|
priv struct SubresultantsRecipe {
  polys : PolysRecipe
  module_object : @recipe.ValueRef
  poly_renderer : @recipe.ValueRef
  sequence_renderer : @recipe.ValueRef
}

///|
fn SubresultantsRecipe::new() -> SubresultantsRecipe raise {
  let polys = PolysRecipe::new()
  let module_object = polys.builder.import_module(
    "sympy.polys.subresultants_qq_zz",
  )
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    subresultants_recipe_source(),
  )
  {
    polys,
    module_object,
    poly_renderer: polys.builder.getitem(
      scope,
      Str("_symbit_subresultants_poly_text"),
    ),
    sequence_renderer: polys.builder.getitem(
      scope,
      Str("_symbit_subresultants_sequence"),
    ),
  }
}

///|
fn SubresultantsRecipe::call(
  self : SubresultantsRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let callable = self.polys.builder.getattr(self.module_object, name)
  self.polys.builder.require_non_none(
    self.polys.builder.call(callable, args),
    message="sympy-call-none:sympy.polys.subresultants_qq_zz." + name,
  )
}

///|
fn SubresultantsRecipe::pair(
  self : SubresultantsRecipe,
  p : @symcore.Expr,
  q : @symcore.Expr,
  x : String,
) -> (@recipe.ValueRef, @recipe.ValueRef, @recipe.ValueRef) raise {
  (self.polys.expr(p), self.polys.expr(q), self.polys.literal_symbol(x))
}

///|
fn SubresultantsRecipe::pair_call(
  self : SubresultantsRecipe,
  name : String,
  p : @symcore.Expr,
  q : @symcore.Expr,
  x : String,
) -> @recipe.ValueRef raise {
  let (left, right, generator) = self.pair(p, q, x)
  self.call(name, [Ref(left), Ref(right), Ref(generator)])
}

///|
fn SubresultantsRecipe::int_list(
  self : SubresultantsRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.polys.builder.list(items)
}

///|
fn SubresultantsRecipe::matrix(
  self : SubresultantsRecipe,
  rows : Array[Array[Int]],
) -> @recipe.ValueRef raise {
  let encoded_rows : Array[@recipe.RecipeArg] = []
  for row in rows {
    encoded_rows.push(Ref(self.int_list(row)))
  }
  let values = self.polys.builder.list(encoded_rows)
  self.polys.call("sympy.Matrix", [Ref(values)])
}

///|
fn SubresultantsRecipe::row_matrix(
  self : SubresultantsRecipe,
  row : Array[Int],
) -> @recipe.ValueRef raise {
  self.matrix([row])
}

///|
fn SubresultantsRecipe::render_poly(
  self : SubresultantsRecipe,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  self.polys.builder.require_non_none(
    self.polys.builder.call(self.poly_renderer, [Ref(value)]),
    message="subresultants-poly-render-none",
  )
}

///|
fn SubresultantsRecipe::render_sequence(
  self : SubresultantsRecipe,
  value : @recipe.ValueRef,
  poly_aware : Bool,
) -> @recipe.ValueRef raise {
  self.polys.builder.require_non_none(
    self.polys.builder.call(self.sequence_renderer, [
      Ref(value),
      Bool(poly_aware),
    ]),
    message="subresultants-sequence-render-none",
  )
}

///|
fn SubresultantsRecipe::request_raw(
  self : SubresultantsRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(value)
}

///|
fn SubresultantsRecipe::request_poly(
  self : SubresultantsRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.request_raw(self.render_poly(value))
}

///|
fn SubresultantsRecipe::request_sequence(
  self : SubresultantsRecipe,
  value : @recipe.ValueRef,
  poly_aware : Bool,
) -> String raise {
  self.request_raw(self.render_sequence(value, poly_aware))
}

///|
fn subresultants_pair_poly_call(
  name : String,
  p : @symcore.Expr,
  q : @symcore.Expr,
  x : String,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  recipe.request_poly(recipe.pair_call(name, p, q, x))
}

///|
fn subresultants_pair_sequence_call(
  name : String,
  p : @symcore.Expr,
  q : @symcore.Expr,
  x : String,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  recipe.request_sequence(recipe.pair_call(name, p, q, x), true)
}
