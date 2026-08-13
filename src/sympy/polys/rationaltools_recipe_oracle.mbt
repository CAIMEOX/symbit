///|
fn PolysRecipe::rationaltools_expr_args(
  self : PolysRecipe,
  expr : @symcore.Expr,
  gens : Array[String],
) -> Array[@recipe.RecipeArg] raise {
  let args : Array[@recipe.RecipeArg] = [Ref(self.expr(expr))]
  for symbol in self.literal_symbols(gens) {
    args.push(symbol)
  }
  args
}

///|
fn PolysRecipe::request_rationaltools_string(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let printable = self.builder.require_non_none(
    self.stringify_legacy_call_result(result),
    message="sympy-polys-rationaltools-render-none",
  )
  self.builder.request_str(printable)
}

///|
fn polys_rationaltools_foundation_source() -> String {
  (
    #|def _symbit_polys_galois_group_text(result):
    #|    if result is None or len(result) < 2:
    #|        raise ValueError("galois_group tuple")
    #|    group, alternating = result[0], result[1]
    #|    if group is None or alternating is None:
    #|        raise ValueError("galois_group item is None")
    #|    name = getattr(group, "value", group)
    #|    alt = "true" if str(alternating) == "True" else "false"
    #|    return "(" + str(name) + ", " + alt + ")"
  )
}

///|
fn PolysRecipe::rationaltools_foundation_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_rationaltools_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::partfrac_poly_pair(
  self : PolysRecipe,
  p : @symcore.Expr,
  q : @symcore.Expr,
  gen : String,
) -> (@recipe.ValueRef, @recipe.ValueRef) raise {
  let generator = self.literal_symbol(gen)
  let p_expr = self.expr(p)
  let q_expr = self.expr(q)
  let p_poly = self.call("sympy.Poly", [Ref(p_expr), Ref(generator)])
  let q_poly = self.call("sympy.Poly", [Ref(q_expr), Ref(generator)])
  (p_poly, q_poly)
}

///|
pub fn real_roots(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.real_roots",
    recipe.rationaltools_expr_args(expr, gens),
  )
  recipe.request_rationaltools_string(result)
}

///|
pub fn nroots(expr : @symcore.Expr, gens? : Array[String] = []) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.nroots",
    recipe.rationaltools_expr_args(expr, gens),
  )
  recipe.request_rationaltools_string(result)
}

///|
pub fn nth_power_roots_poly(
  expr : @symcore.Expr,
  n : Int,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  // Preserve the observable HEAD contract: n follows every supplied gen.
  let args = recipe.rationaltools_expr_args(expr, gens)
  args.push(DecimalInt(Show::to_string(n)))
  let result = recipe.call("sympy.polys.polytools.nth_power_roots_poly", args)
  recipe.request_rationaltools_string(result)
}

///|
pub fn is_zero_dimensional(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.expression_list(exprs))]
  for symbol in recipe.literal_symbols(gens) {
    args.push(symbol)
  }
  let result = recipe.call("sympy.polys.polytools.is_zero_dimensional", args)
  recipe.request_rationaltools_string(result)
}

///|
pub fn hurwitz_conditions(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.hurwitz_conditions",
    recipe.rationaltools_expr_args(expr, gens),
  )
  recipe.request_rationaltools_string(result)
}

///|
pub fn schur_conditions(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.schur_conditions",
    recipe.rationaltools_expr_args(expr, gens),
  )
  recipe.request_rationaltools_string(result)
}

///|
pub fn together(
  expr : @symcore.Expr,
  deep? : Bool = false,
  fraction? : Bool = true,
) -> String raise {
  let recipe = PolysRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = {
    "deep": Bool(deep),
    "fraction": Bool(fraction),
  }
  let result = recipe.call(
    "sympy.polys.rationaltools.together",
    [Ref(recipe.expr(expr))],
    kwargs~,
  )
  recipe.request_rationaltools_string(result)
}

///|
pub fn apart(
  expr : @symcore.Expr,
  gen? : String = "",
  full? : Bool = false,
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.expr(expr))]
  if gen != "" {
    args.push(Ref(recipe.literal_symbol(gen)))
  }
  let kwargs : Map[String, @recipe.RecipeArg] = { "full": Bool(full) }
  let result = recipe.call("sympy.polys.partfrac.apart", args, kwargs~)
  recipe.request_rationaltools_string(result)
}

///|
pub fn apart_undetermined_coeffs(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gen : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let (p_poly, q_poly) = recipe.partfrac_poly_pair(p, q, gen)
  let result = recipe.call("sympy.polys.partfrac.apart_undetermined_coeffs", [
    Ref(p_poly),
    Ref(q_poly),
  ])
  recipe.request_rationaltools_string(result)
}

///|
pub fn apart_full_decomposition(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gen : String,
  doit? : Bool = true,
) -> String raise {
  let recipe = PolysRecipe::new()
  let (p_poly, q_poly) = recipe.partfrac_poly_pair(p, q, gen)
  let result = recipe.call("sympy.polys.partfrac.apart_full_decomposition", [
    Ref(p_poly),
    Ref(q_poly),
  ])
  let final_result = if doit {
    let doit_callable = recipe.builder.getattr(result, "doit")
    recipe.builder.require_non_none(
      recipe.builder.call(doit_callable, []),
      message="sympy-call-none:apart_full_decomposition.doit",
    )
  } else {
    result
  }
  recipe.request_rationaltools_string(final_result)
}

///|
pub fn apart_list_full_decomposition_count(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gen : String,
) -> Int raise {
  let recipe = PolysRecipe::new()
  let (p_poly, q_poly) = recipe.partfrac_poly_pair(p, q, gen)
  let dummygen = recipe.call("sympy.utilities.iterables.numbered_symbols", [])
  let result = recipe.call(
    "sympy.polys.partfrac.apart_list_full_decomposition",
    [Ref(p_poly), Ref(q_poly), Ref(dummygen)],
  )
  let builtins = recipe.builder.import_module("builtins")
  let length = recipe.builder.require_non_none(
    recipe.builder.call(recipe.builder.getattr(builtins, "len"), [Ref(result)]),
    message="sympy-call-none:len(apart_list_full_decomposition)",
  )
  let encoded_length = recipe.builder.request_int(length)
  @string.parse_int(encoded_length) catch {
    _ => fail("sympy-polys-partfrac-count:" + encoded_length)
  }
}

///|
pub fn sqf_norm(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  extension? : String = "",
) -> String raise {
  let recipe = PolysRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if extension != "" {
    kwargs["extension"] = Ref(recipe.call("sympy.sympify", [Str(extension)]))
  }
  let result = recipe.call(
    "sympy.polys.polytools.sqf_norm",
    recipe.rationaltools_expr_args(expr, gens),
    kwargs~,
  )
  recipe.request_rationaltools_string(result)
}

///|
pub fn galois_group(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.numberfields.galoisgroups.galois_group",
    recipe.rationaltools_expr_args(expr, gens),
    kwargs={ "by_name": Bool(true) },
  )
  let renderer = recipe.rationaltools_foundation_callable(
    "_symbit_polys_galois_group_text",
  )
  let rendered = recipe.builder.require_non_none(
    recipe.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-galois-group-render-none",
  )
  recipe.builder.request_str(rendered)
}
