///|
fn polys_roots_foundation_source() -> String {
  (
    #|def _symbit_polys_p5a8_default_gens(expression):
    #|    return sorted(expression.free_symbols, key=lambda symbol: symbol.name)
    #|
    #|def _symbit_polys_p5a8_poly(expression, generators, use_generators):
    #|    if not use_generators:
    #|        generators = _symbit_polys_p5a8_default_gens(expression)
    #|    return sympy.Poly(expression, *generators)
    #|
    #|def _symbit_polys_p5a8_root_factors(function, expression, generators, use_generators):
    #|    if not use_generators:
    #|        generators = _symbit_polys_p5a8_default_gens(expression)
    #|    return function(expression, *generators)
    #|
    #|def _symbit_polys_p5a8_require_graph(value):
    #|    if value is None:
    #|        raise ValueError("roots result contains None")
    #|    if isinstance(value, dict):
    #|        for key, item in value.items():
    #|            _symbit_polys_p5a8_require_graph(key)
    #|            _symbit_polys_p5a8_require_graph(item)
    #|    elif isinstance(value, (list, tuple, set, frozenset)):
    #|        for item in value:
    #|            _symbit_polys_p5a8_require_graph(item)
    #|    return value
    #|
    #|def _symbit_polys_p5a8_compact(value):
    #|    _symbit_polys_p5a8_require_graph(value)
    #|    if isinstance(value, list):
    #|        return "[" + ",".join(_symbit_polys_p5a8_compact(item) for item in value) + "]"
    #|    if isinstance(value, tuple):
    #|        return "(" + ",".join(_symbit_polys_p5a8_compact(item) for item in value) + ")"
    #|    return str(value).replace(" ", "")
    #|
    #|def _symbit_polys_p5a8_preprocess_text(result):
    #|    if not isinstance(result, (list, tuple)) or len(result) != 2:
    #|        raise ValueError("preprocess_roots result must be a pair")
    #|    coefficient, polynomial = result
    #|    _symbit_polys_p5a8_require_graph(coefficient)
    #|    _symbit_polys_p5a8_require_graph(polynomial)
    #|    expression = polynomial.as_expr()
    #|    _symbit_polys_p5a8_require_graph(expression)
    #|    return _symbit_polys_p5a8_compact(coefficient) + "||" + _symbit_polys_p5a8_compact(expression)
    #|
    #|def _symbit_polys_p5a8_root_object_text(value):
    #|    _symbit_polys_p5a8_require_graph(value)
    #|    if isinstance(value, sympy.Poly):
    #|        value = value.as_expr()
    #|        _symbit_polys_p5a8_require_graph(value)
    #|    return str(value)
    #|
  )
}

///|
priv struct RootsRecipe {
  polys : PolysRecipe
  scope : @recipe.ValueRef
}

///|
fn RootsRecipe::new() -> RootsRecipe raise {
  let polys = PolysRecipe::new()
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    polys_roots_foundation_source(),
  )
  { polys, scope }
}

///|
fn RootsRecipe::callable(
  self : RootsRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.getitem(self.scope, Str(name))
}

///|
fn RootsRecipe::poly(
  self : RootsRecipe,
  expression : @symcore.Expr,
  gens : Array[String],
) -> @recipe.ValueRef raise {
  let poly_constructor = self.callable("_symbit_polys_p5a8_poly")
  self.polys.builder.require_non_none(
    self.polys.builder.call(poly_constructor, [
      Ref(self.polys.expr(expression)),
      Ref(self.polys.literal_symbol_list(gens)),
      Bool(!gens.is_empty()),
    ]),
    message="sympy-call-none:sympy.Poly",
  )
}

///|
fn RootsRecipe::request_compact(
  self : RootsRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.callable("_symbit_polys_p5a8_compact")
  let rendered = self.polys.builder.require_non_none(
    self.polys.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-roots-render-none",
  )
  self.polys.builder.request_str(rendered)
}

///|
fn RootsRecipe::request_preprocess(
  self : RootsRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.callable("_symbit_polys_p5a8_preprocess_text")
  let rendered = self.polys.builder.require_non_none(
    self.polys.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-preprocess-roots-render-none",
  )
  self.polys.builder.request_str(rendered)
}

///|
fn RootsRecipe::request_object(
  self : RootsRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.callable("_symbit_polys_p5a8_root_object_text")
  let rendered = self.polys.builder.require_non_none(
    self.polys.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-root-object-render-none",
  )
  self.polys.builder.request_str(rendered)
}

///|
fn roots_specialized_front(
  expression : @symcore.Expr,
  gens : Array[String],
  path : String,
) -> String raise {
  let recipe = RootsRecipe::new()
  let polynomial = recipe.poly(expression, gens)
  let result = recipe.polys.call(path, [Ref(polynomial)])
  recipe.request_compact(result)
}

///|
pub fn roots_linear(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_linear")
}

///|
pub fn roots_quadratic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_quadratic")
}

///|
pub fn roots_cubic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_cubic")
}

///|
pub fn roots_quartic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_quartic")
}

///|
pub fn roots_quintic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_quintic")
}

///|
pub fn roots_binomial(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_binomial")
}

///|
pub fn roots_cyclotomic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  roots_specialized_front(expr, gens, "sympy.polys.polyroots.roots_cyclotomic")
}

///|
pub fn preprocess_roots(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = RootsRecipe::new()
  let polynomial = recipe.poly(expr, gens)
  let result = recipe.polys.call("sympy.polys.polyroots.preprocess_roots", [
    Ref(polynomial),
  ])
  recipe.request_preprocess(result)
}

///|
pub fn root_factors(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = RootsRecipe::new()
  let target = recipe_sympy_callable(
    recipe.polys.builder,
    "sympy.polys.polyroots.root_factors",
  )
  let caller = recipe.callable("_symbit_polys_p5a8_root_factors")
  let result = recipe.polys.builder.require_non_none(
    recipe.polys.builder.call(caller, [
      Ref(target),
      Ref(recipe.polys.expr(expr)),
      Ref(recipe.polys.literal_symbol_list(gens)),
      Bool(!gens.is_empty()),
    ]),
    message="sympy-call-none:sympy.polys.polyroots.root_factors",
  )
  recipe.request_compact(result)
}

///|
pub fn rootof(
  expr : @symcore.Expr,
  index : Int,
  radicals? : Bool = true,
) -> String raise {
  let recipe = RootsRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if !radicals {
    kwargs["radicals"] = Bool(false)
  }
  let result = recipe.polys.call(
    "sympy.polys.rootoftools.rootof",
    [Ref(recipe.polys.expr(expr)), DecimalInt(Show::to_string(index))],
    kwargs~,
  )
  recipe.request_object(result)
}
