///|
fn PolysRecipe::polytools_expr_args(
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
fn PolysRecipe::request_polytools_string(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let printable = self.builder.require_non_none(
    self.stringify_legacy_call_result(result),
    message="sympy-polys-polytools-render-none",
  )
  self.builder.request_str(printable)
}

///|
fn polys_polytools_foundation_source() -> String {
  (
    #|def _symbit_polys_polytools_text(value):
    #|    if value is None:
    #|        raise ValueError("polytools result item is None")
    #|    if isinstance(value, sympy.Poly):
    #|        value = value.as_expr()
    #|    return str(value)
    #|
    #|def _symbit_polys_polytools_join(result, count):
    #|    if not isinstance(result, (list, tuple)) or len(result) < count:
    #|        raise ValueError("polytools result tuple")
    #|    return "||".join(
    #|        _symbit_polys_polytools_text(result[index])
    #|        for index in range(count)
    #|    )
    #|
    #|def _symbit_polys_polytools_first(result):
    #|    if not isinstance(result, (list, tuple)) or len(result) < 1:
    #|        raise ValueError("polytools result tuple")
    #|    if result[0] is None:
    #|        raise ValueError("polytools result item is None")
    #|    return _symbit_polys_polytools_text(result[0])
    #|
    #|def _symbit_polys_polytools_parallel_first(result):
    #|    if not isinstance(result, (list, tuple)) or len(result) < 1:
    #|        raise ValueError("parallel_poly_from_expr result tuple")
    #|    values = result[0]
    #|    if not isinstance(values, (list, tuple)):
    #|        raise ValueError("parallel_poly_from_expr result list")
    #|    if any(value is None for value in values):
    #|        raise ValueError("parallel_poly_from_expr item is None")
    #|    return "||".join(_symbit_polys_polytools_text(value) for value in values)
    #|
    #|def _symbit_polys_polytools_gff(result):
    #|    if not isinstance(result, (list, tuple)):
    #|        raise ValueError("gff_list result list")
    #|    parts = []
    #|    for item in result:
    #|        if not isinstance(item, (list, tuple)):
    #|            raise ValueError("gff_list result pair")
    #|        if len(item) >= 2:
    #|            if item[0] is None or item[1] is None:
    #|                raise ValueError("gff_list result item is None")
    #|            parts.append(
    #|                "(" + _symbit_polys_polytools_text(item[0]) + ", "
    #|                + str(item[1]) + ")"
    #|            )
    #|    return "||".join(parts)
  )
}

///|
fn PolysRecipe::polytools_foundation_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_polytools_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::request_polytools_joined(
  self : PolysRecipe,
  result : @recipe.ValueRef,
  count : Int,
) -> String raise {
  let renderer = self.polytools_foundation_callable(
    "_symbit_polys_polytools_join",
  )
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [
      Ref(result),
      DecimalInt(Show::to_string(count)),
    ]),
    message="sympy-polys-polytools-join-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_polytools_first(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.polytools_foundation_callable(
    "_symbit_polys_polytools_first",
  )
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-polytools-first-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_polytools_parallel_first(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.polytools_foundation_callable(
    "_symbit_polys_polytools_parallel_first",
  )
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-parallel-polytools-first-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_polytools_gff(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.polytools_foundation_callable(
    "_symbit_polys_polytools_gff",
  )
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-polytools-gff-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::polytools_binary_args(
  self : PolysRecipe,
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens : Array[String],
) -> Array[@recipe.RecipeArg] raise {
  let args : Array[@recipe.RecipeArg] = [Ref(self.expr(p)), Ref(self.expr(q))]
  for symbol in self.literal_symbols(gens) {
    args.push(symbol)
  }
  args
}

///|
fn polytools_domain_kwargs(domain : String) -> Map[String, @recipe.RecipeArg] {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  kwargs
}

///|
fn polytools_order_kwargs(order : String) -> Map[String, @recipe.RecipeArg] {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if order != "" {
    kwargs["order"] = Str(order)
  }
  kwargs
}

///|
fn PolysRecipe::polytools_rational_arg(
  self : PolysRecipe,
  numerator : Int,
  denominator : Int,
) -> @recipe.RecipeArg raise {
  Ref(
    self.call("sympy.Rational", [
      DecimalInt(Show::to_string(numerator)),
      DecimalInt(Show::to_string(denominator)),
    ]),
  )
}

///|
pub fn degree(expr : @symcore.Expr, gen? : String = "") -> String raise {
  let recipe = PolysRecipe::new()
  let gens = if gen == "" { [] } else { [gen] }
  let result = recipe.call(
    "sympy.polys.polytools.degree",
    recipe.polytools_expr_args(expr, gens),
  )
  recipe.request_polytools_string(result)
}

///|
pub fn degree_list(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.degree_list",
    recipe.polytools_expr_args(expr, gens),
  )
  recipe.request_polytools_string(result)
}

///|
fn polytools_leading_front(
  expr : @symcore.Expr,
  gens : Array[String],
  order : String,
  path : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    path,
    recipe.polytools_expr_args(expr, gens),
    kwargs=polytools_order_kwargs(order),
  )
  recipe.request_polytools_string(result)
}

///|
pub fn polytools_lc(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  order? : String = "",
) -> String raise {
  polytools_leading_front(expr, gens, order, "sympy.polys.polytools.LC")
}

///|
pub fn polytools_lm(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  order? : String = "",
) -> String raise {
  polytools_leading_front(expr, gens, order, "sympy.polys.polytools.LM")
}

///|
pub fn polytools_lt(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  order? : String = "",
) -> String raise {
  polytools_leading_front(expr, gens, order, "sympy.polys.polytools.LT")
}

///|
pub fn pdiv(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.pdiv",
    recipe.polytools_binary_args(p, q, gens),
    kwargs=polytools_domain_kwargs(domain),
  )
  recipe.request_polytools_joined(result, 2)
}

///|
fn polytools_binary_string_front(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens : Array[String],
  domain : String,
  path : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    path,
    recipe.polytools_binary_args(p, q, gens),
    kwargs=polytools_domain_kwargs(domain),
  )
  recipe.request_polytools_string(result)
}

///|
fn polytools_binary_joined_front(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens : Array[String],
  domain : String,
  path : String,
  count : Int,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    path,
    recipe.polytools_binary_args(p, q, gens),
    kwargs=polytools_domain_kwargs(domain),
  )
  recipe.request_polytools_joined(result, count)
}

///|
pub fn prem(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
) -> String raise {
  polytools_binary_string_front(
    p, q, gens, domain, "sympy.polys.polytools.prem",
  )
}

///|
pub fn pquo(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
) -> String raise {
  polytools_binary_string_front(
    p, q, gens, domain, "sympy.polys.polytools.pquo",
  )
}

///|
pub fn half_gcdex(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
) -> String raise {
  polytools_binary_joined_front(
    p, q, gens, domain, "sympy.polys.polytools.half_gcdex", 2,
  )
}

///|
pub fn gcdex(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
) -> String raise {
  polytools_binary_joined_front(
    p, q, gens, domain, "sympy.polys.polytools.gcdex", 3,
  )
}

///|
pub fn invert(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
) -> String raise {
  polytools_binary_string_front(
    p, q, gens, domain, "sympy.polys.polytools.invert",
  )
}

///|
pub fn count_roots(
  expr : @symcore.Expr,
  inf_num? : Int = 0,
  inf_den? : Int = 1,
  sup_num? : Int = 0,
  sup_den? : Int = 1,
  has_inf? : Bool = false,
  has_sup? : Bool = false,
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.expr(expr))]
  if has_inf {
    args.push(recipe.polytools_rational_arg(inf_num, inf_den))
  }
  if has_sup {
    if !has_inf {
      args.push(Null)
    }
    args.push(recipe.polytools_rational_arg(sup_num, sup_den))
  }
  let result = recipe.call("sympy.polys.polytools.count_roots", args)
  recipe.request_polytools_string(result)
}

///|
pub fn intervals(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.intervals",
    recipe.polytools_expr_args(expr, gens),
  )
  recipe.request_polytools_string(result)
}

///|
pub fn trunc(
  expr : @symcore.Expr,
  modulus : Int,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [
    Ref(recipe.expr(expr)),
    DecimalInt(Show::to_string(modulus)),
  ]
  for symbol in recipe.literal_symbols(gens) {
    args.push(symbol)
  }
  let result = recipe.call("sympy.polys.polytools.trunc", args)
  recipe.request_polytools_string(result)
}

///|
pub fn poly_from_expr_front(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.poly_from_expr",
    recipe.polytools_expr_args(expr, gens),
  )
  recipe.request_polytools_first(result)
}

///|
pub fn parallel_poly_from_expr_front(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.expression_list(exprs))]
  for symbol in recipe.literal_symbols(gens) {
    args.push(symbol)
  }
  let result = recipe.call(
    "sympy.polys.polytools.parallel_poly_from_expr", args,
  )
  recipe.request_polytools_parallel_first(result)
}

///|
pub fn refine_root(
  expr : @symcore.Expr,
  s_num : Int,
  s_den : Int,
  t_num : Int,
  t_den : Int,
  eps_num? : Int = 0,
  eps_den? : Int = 1,
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [
    Ref(recipe.expr(expr)),
    recipe.polytools_rational_arg(s_num, s_den),
    recipe.polytools_rational_arg(t_num, t_den),
  ]
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if eps_num != 0 {
    kwargs["eps"] = recipe.polytools_rational_arg(eps_num, eps_den)
  }
  let result = recipe.call("sympy.polys.polytools.refine_root", args, kwargs~)
  recipe.request_polytools_string(result)
}

///|
pub fn all_roots(expr : @symcore.Expr) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.polys.polytools.all_roots", [
    Ref(recipe.expr(expr)),
  ])
  recipe.request_polytools_string(result)
}

///|
pub fn ground_roots(expr : @symcore.Expr) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.polys.polytools.ground_roots", [
    Ref(recipe.expr(expr)),
  ])
  recipe.request_polytools_string(result)
}

///|
fn polytools_single_expr_front(
  expr : @symcore.Expr,
  gens : Array[String],
  path : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(path, recipe.polytools_expr_args(expr, gens))
  recipe.request_polytools_string(result)
}

///|
pub fn poly_front(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  polytools_single_expr_front(expr, gens, "sympy.polys.polytools.poly")
}

///|
pub fn sqf(expr : @symcore.Expr, gens? : Array[String] = []) -> String raise {
  polytools_single_expr_front(expr, gens, "sympy.polys.polytools.sqf")
}

///|
pub fn gff_list(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.gff_list",
    recipe.polytools_expr_args(expr, gens),
  )
  recipe.request_polytools_gff(result)
}
