///|
fn polys_dispersion_foundation_source() -> String {
  (
    #|def _symbit_polys_dispersion_poly(expression, generators, use_generators):
    #|    if not use_generators:
    #|        generators = sorted(expression.free_symbols, key=lambda symbol: symbol.name)
    #|    return sympy.Poly(expression, *generators)
    #|
    #|def _symbit_polys_dispersion_set_text(value):
    #|    if value is None:
    #|        raise ValueError("dispersionset returned None")
    #|    items = sorted(value)
    #|    if any(item is None for item in items):
    #|        raise ValueError("dispersionset contains None")
    #|    return "[" + ",".join(str(int(item)) for item in items) + "]"
    #|
    #|def _symbit_polys_dispersion_text(value):
    #|    if value is None:
    #|        raise ValueError("dispersion returned None")
    #|    return str(value)
    #|
  )
}

///|
priv struct DispersionRecipe {
  polys : PolysRecipe
  scope : @recipe.ValueRef
}

///|
fn DispersionRecipe::new() -> DispersionRecipe raise {
  let polys = PolysRecipe::new()
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    polys_dispersion_foundation_source(),
  )
  { polys, scope }
}

///|
fn DispersionRecipe::callable(
  self : DispersionRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.getitem(self.scope, Str(name))
}

///|
fn DispersionRecipe::poly(
  self : DispersionRecipe,
  expression : @symcore.Expr,
  gens : Array[String],
) -> @recipe.ValueRef raise {
  let result = self.polys.builder.call(
    self.callable("_symbit_polys_dispersion_poly"),
    [
      Ref(self.polys.expr(expression)),
      Ref(self.polys.literal_symbol_list(gens)),
      Bool(!gens.is_empty()),
    ],
  )
  self.polys.builder.require_non_none(
    result,
    message="sympy-call-none:sympy.Poly",
  )
}

///|
fn DispersionRecipe::request_rendered(
  self : DispersionRecipe,
  result : @recipe.ValueRef,
  renderer_name : String,
) -> String raise {
  let rendered = self.polys.builder.call(self.callable(renderer_name), [
    Ref(result),
  ])
  self.polys.builder.request_str(
    self.polys.builder.require_non_none(
      rendered,
      message="sympy-polys-dispersion-render-none",
    ),
  )
}

///|
fn dispersion_recipe_front(
  p : @symcore.Expr,
  q : @symcore.Expr?,
  gens : Array[String],
  path : String,
  renderer_name : String,
) -> String raise {
  let recipe = DispersionRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.poly(p, gens))]
  match q {
    Some(expression) => args.push(Ref(recipe.poly(expression, gens)))
    None => ()
  }
  let result = recipe.polys.call(path, args)
  recipe.request_rendered(result, renderer_name)
}

///|
pub fn dispersionset_expr(
  p : @symcore.Expr,
  q? : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  dispersion_recipe_front(
    p, q, gens, "sympy.polys.dispersion.dispersionset", "_symbit_polys_dispersion_set_text",
  )
}

///|
pub fn dispersion_expr(
  p : @symcore.Expr,
  q? : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  dispersion_recipe_front(
    p, q, gens, "sympy.polys.dispersion.dispersion", "_symbit_polys_dispersion_text",
  )
}
