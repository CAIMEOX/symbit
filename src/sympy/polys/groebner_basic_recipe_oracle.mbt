///|
fn polys_groebner_basic_foundation_source() -> String {
  (
    #|def _symbit_polys_p5a6_groebner(expressions, order, use_order):
    #|    symbols = set()
    #|    for expression in expressions:
    #|        symbols.update(expression.free_symbols)
    #|    generators = sorted(symbols, key=lambda symbol: symbol.name)
    #|    kwargs = {"order": order} if use_order else {}
    #|    return sympy.groebner(expressions, *generators, **kwargs)
    #|
    #|def _symbit_polys_p5a6_basis_text(result, monic):
    #|    if result is None:
    #|        raise ValueError("groebner result is None")
    #|    values = result.polys if monic else result
    #|    if not isinstance(values, (list, tuple)):
    #|        raise ValueError("groebner basis sequence")
    #|    parts = []
    #|    for value in values:
    #|        if value is None:
    #|            raise ValueError("groebner basis item is None")
    #|        if monic:
    #|            value = value.monic()
    #|            if value is None:
    #|                raise ValueError("groebner monic item is None")
    #|            value = value.as_expr()
    #|            if value is None:
    #|                raise ValueError("groebner expression item is None")
    #|        parts.append(str(value))
    #|    parts.sort()
    #|    return " | ".join(parts)
    #|
    #|def _symbit_polys_p5a6_text(value):
    #|    if value is None:
    #|        raise ValueError("groebner result is None")
    #|    return str(value)
    #|
  )
}

///|
fn PolysRecipe::groebner_basic_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_groebner_basic_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::request_groebner_basis(
  self : PolysRecipe,
  result : @recipe.ValueRef,
  monic : Bool,
) -> String raise {
  let renderer = self.groebner_basic_callable("_symbit_polys_p5a6_basis_text")
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result), Bool(monic)]),
    message="sympy-polys-groebner-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_groebner_text(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.groebner_basic_callable("_symbit_polys_p5a6_text")
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-groebner-text-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::groebner_basic_ring_polys(
  self : PolysRecipe,
  expressions : Array[@symcore.Expr],
  gens : Array[String],
  order : String,
) -> (@recipe.ValueRef, Array[@recipe.ValueRef]) raise {
  let expression_values : Array[@recipe.ValueRef] = []
  for expression in expressions {
    expression_values.push(self.expr(expression))
  }
  let sympy = self.builder.import_module("sympy")
  let qq = self.builder.getattr(sympy, "QQ")
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if order != "" {
    let order_object = self.call("sympy.polys.orderings.monomial_key", [
      Str(order),
    ])
    kwargs["order"] = Ref(order_object)
  }
  let ring_result = self.call(
    "sympy.polys.rings.ring",
    [Ref(self.literal_symbol_list(gens)), Ref(qq)],
    kwargs~,
  )
  let ring = self.builder.getitem(ring_result, DecimalInt("0"))
  let from_expr = self.builder.getattr(ring, "from_expr")
  let polynomials : Array[@recipe.ValueRef] = []
  for expression in expression_values {
    polynomials.push(
      self.builder.require_non_none(
        self.builder.call(from_expr, [Ref(expression)]),
        message="sympy-call-none:PolyRing.from_expr",
      ),
    )
  }
  (ring, polynomials)
}

///|
pub fn groebner(
  exprs : Array[@symcore.Expr],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let callable = recipe.groebner_basic_callable("_symbit_polys_p5a6_groebner")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(callable, [
      Ref(recipe.expression_list(exprs)),
      Str(order),
      Bool(order != ""),
    ]),
    message="sympy-call-none:sympy.groebner",
  )
  recipe.request_groebner_basis(result, true)
}

///|
pub fn groebnertools_gcd(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = ["x"],
  order? : String = "lex",
) -> String raise {
  groebner_basic_binary_ring_front(
    f, g, gens, order, "sympy.polys.groebnertools.groebner_gcd",
  )
}

///|
fn groebner_basic_binary_ring_front(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens : Array[String],
  order : String,
  path : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let (_, polynomials) = recipe.groebner_basic_ring_polys([f, g], gens, order)
  guard polynomials is [f_poly, g_poly] else {
    fail("groebner-ring-polynomials")
  }
  let result = recipe.call(path, [Ref(f_poly), Ref(g_poly)])
  recipe.request_groebner_text(result)
}

///|
pub fn groebnertools_lcm(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = ["x"],
  order? : String = "lex",
) -> String raise {
  groebner_basic_binary_ring_front(
    f, g, gens, order, "sympy.polys.groebnertools.groebner_lcm",
  )
}

///|
pub fn groebnertools_spoly(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, polynomials) = recipe.groebner_basic_ring_polys(
    [f, g],
    gens,
    order,
  )
  guard polynomials is [f_poly, g_poly] else {
    fail("groebner-ring-polynomials")
  }
  let result = recipe.call("sympy.polys.groebnertools.spoly", [
    Ref(f_poly),
    Ref(g_poly),
    Ref(ring),
  ])
  recipe.request_groebner_text(result)
}

///|
pub fn red_groebner(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, polynomials) = recipe.groebner_basic_ring_polys(exprs, gens, order)
  let items : Array[@recipe.RecipeArg] = []
  for polynomial in polynomials {
    items.push(Ref(polynomial))
  }
  let result = recipe.call("sympy.polys.groebnertools.red_groebner", [
    Ref(recipe.builder.list(items)),
    Ref(ring),
  ])
  recipe.request_groebner_basis(result, false)
}

///|
fn groebner_basic_predicate_front(
  exprs : Array[@symcore.Expr],
  gens : Array[String],
  order : String,
  path : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, polynomials) = recipe.groebner_basic_ring_polys(exprs, gens, order)
  let items : Array[@recipe.RecipeArg] = []
  for polynomial in polynomials {
    items.push(Ref(polynomial))
  }
  let result = recipe.call(path, [Ref(recipe.builder.list(items)), Ref(ring)])
  if recipe.builder.request_bool(result) {
    "true"
  } else {
    "false"
  }
}

///|
pub fn is_groebner(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  groebner_basic_predicate_front(
    exprs, gens, order, "sympy.polys.groebnertools.is_groebner",
  )
}

///|
pub fn is_minimal(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  groebner_basic_predicate_front(
    exprs, gens, order, "sympy.polys.groebnertools.is_minimal",
  )
}

///|
pub fn is_reduced(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  groebner_basic_predicate_front(
    exprs, gens, order, "sympy.polys.groebnertools.is_reduced",
  )
}
