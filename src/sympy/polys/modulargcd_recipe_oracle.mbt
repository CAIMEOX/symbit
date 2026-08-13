///|
fn modular_gcd_recipe_source() -> String {
  (
    #|def _symbit_modgcd_result(value, elements_as_expr):
    #|    try:
    #|        parts = list(value)
    #|    except TypeError as error:
    #|        raise ValueError("modgcd-result-shape") from error
    #|    if len(parts) != 3:
    #|        raise ValueError("modgcd-result-shape")
    #|    rendered = []
    #|    for part in parts:
    #|        if part is None:
    #|            raise ValueError("modgcd-result-none")
    #|        if elements_as_expr:
    #|            part = part.as_expr()
    #|            if part is None:
    #|                raise ValueError("modgcd-result-none")
    #|        part = sympy.sympify(str(part))
    #|        rendered.append(str(part).replace(" ", ""))
    #|    return "(" + ",".join(rendered) + ")"
  )
}

///|
priv struct ModularGcdRecipe {
  polys : PolysRecipe
  module_object : @recipe.ValueRef
  domain : @recipe.ValueRef
  ring_constructor : @recipe.ValueRef
  result_renderer : @recipe.ValueRef
}

///|
fn ModularGcdRecipe::new(domain_spec : String) -> ModularGcdRecipe raise {
  let polys = PolysRecipe::new()
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    domain_foundation_source(),
  )
  let scope = polys.builder.exec(scope, modular_gcd_recipe_source())
  let parse_domain = polys.builder.getitem(scope, Str("_symbit_domain_spec"))
  let domain = polys.builder.require_non_none(
    polys.builder.call(parse_domain, [Str(domain_spec)]),
    message="sympy-polys-modgcd-domain-none",
  )
  let rings = polys.builder.import_module("sympy.polys.rings")
  {
    polys,
    module_object: polys.builder.import_module("sympy.polys.modulargcd"),
    domain,
    ring_constructor: polys.builder.getattr(rings, "ring"),
    result_renderer: polys.builder.getitem(scope, Str("_symbit_modgcd_result")),
  }
}

///|
fn ModularGcdRecipe::strict_call(
  self : ModularGcdRecipe,
  callable : @recipe.ValueRef,
  args : Array[@recipe.RecipeArg],
  message : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.require_non_none(
    self.polys.builder.call(callable, args),
    message~,
  )
}

///|
fn ModularGcdRecipe::ring(
  self : ModularGcdRecipe,
  gens : String,
) -> @recipe.ValueRef raise {
  let result = self.strict_call(
    self.ring_constructor,
    [Str(gens), Ref(self.domain)],
    "ring-result-none",
  )
  self.polys.builder.getitem(result, DecimalInt("0"))
}

///|
fn ModularGcdRecipe::ring_element(
  self : ModularGcdRecipe,
  ring : @recipe.ValueRef,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  let from_expr = self.polys.builder.getattr(ring, "from_expr")
  let value = self.polys.expr(expression)
  self.strict_call(from_expr, [Ref(value)], "sympy-polys-modgcd-from-expr-none")
}

///|
fn ModularGcdRecipe::call(
  self : ModularGcdRecipe,
  name : String,
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens : String,
) -> @recipe.ValueRef raise {
  let ring = self.ring(gens)
  let left = self.ring_element(ring, f)
  let right = self.ring_element(ring, g)
  let callable = self.polys.builder.getattr(self.module_object, name)
  self.strict_call(
    callable,
    [Ref(left), Ref(right)],
    "sympy-call-none:sympy.polys.modulargcd." + name,
  )
}

///|
fn ModularGcdRecipe::request_result(
  self : ModularGcdRecipe,
  result : @recipe.ValueRef,
  elements_as_expr~ : Bool,
) -> String raise {
  let rendered = self.strict_call(
    self.result_renderer,
    [Ref(result), Bool(elements_as_expr)],
    "sympy-polys-modgcd-render-none",
  )
  self.polys.builder.request_str(rendered)
}

///|
pub fn sympify_pythonrational(num : Int, den : Int) -> String raise {
  let recipe = PolysRecipe::new()
  let module_object = recipe.builder.import_module(
    "sympy.polys.domains.pythonrational",
  )
  let python_rational_type = recipe.builder.getattr(
    module_object, "PythonRational",
  )
  let rational = recipe.builder.require_non_none(
    recipe.builder.call(python_rational_type, [
      DecimalInt(Show::to_string(num)),
      DecimalInt(Show::to_string(den)),
    ]),
    message="sympy-polys-pythonrational-none",
  )
  let sympify = recipe.builder.getattr(module_object, "sympify_pythonrational")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(sympify, [Ref(rational)]),
    message="sympy-call-none:sympy.polys.domains.pythonrational.sympify_pythonrational",
  )
  recipe.builder.request_str(result)
}

///|
fn modular_gcd_call(
  name : String,
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens : String,
  domain_spec : String,
  elements_as_expr : Bool,
) -> String raise {
  let recipe = ModularGcdRecipe::new(domain_spec)
  let result = recipe.call(name, f, g, gens)
  recipe.request_result(result, elements_as_expr~)
}

///|
pub fn modgcd_univariate(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gen? : String = "x",
) -> String raise {
  modular_gcd_call("modgcd_univariate", f, g, gen, "ZZ", false)
}

///|
pub fn modgcd_bivariate(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : String = "x,y",
) -> String raise {
  modular_gcd_call("modgcd_bivariate", f, g, gens, "ZZ", false)
}

///|
pub fn modgcd_multivariate(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : String = "x,y,z",
) -> String raise {
  modular_gcd_call("modgcd_multivariate", f, g, gens, "ZZ", false)
}

///|
pub fn func_field_modgcd_sqrt2(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : String = "x",
) -> String raise {
  modular_gcd_call("func_field_modgcd", f, g, gens, "QQ<sqrt(2)>", true)
}
