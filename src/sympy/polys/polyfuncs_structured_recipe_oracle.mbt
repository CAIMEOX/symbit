///|
fn polys_structured_foundation_source() -> String {
  (
    #|def _symbit_polys_p5a5_text(value):
    #|    if value is None:
    #|        raise ValueError("structured result item is None")
    #|    if isinstance(value, sympy.Poly):
    #|        value = value.as_expr()
    #|    return str(value)
    #|
    #|def _symbit_polys_p5a5_sequence(value, label):
    #|    if not isinstance(value, (list, tuple)):
    #|        raise ValueError(label)
    #|    return value
    #|
    #|def _symbit_polys_p5a5_sequence_text(result):
    #|    values = _symbit_polys_p5a5_sequence(
    #|        result, "structured result sequence"
    #|    )
    #|    return " | ".join(_symbit_polys_p5a5_text(value) for value in values)
    #|
    #|def _symbit_polys_p5a5_reduced_text(result):
    #|    values = _symbit_polys_p5a5_sequence(result, "reduced result tuple")
    #|    if len(values) < 2:
    #|        raise ValueError("reduced result tuple")
    #|    quotients = _symbit_polys_p5a5_sequence(
    #|        values[0], "reduced quotient list"
    #|    )
    #|    quotient_text = " | ".join(
    #|        _symbit_polys_p5a5_text(value) for value in quotients
    #|    )
    #|    return quotient_text + "||" + _symbit_polys_p5a5_text(values[1])
    #|
    #|def _symbit_polys_p5a5_fraction_text(result):
    #|    values = _symbit_polys_p5a5_sequence(
    #|        result, "rational_interpolate fraction"
    #|    )
    #|    if len(values) < 2:
    #|        raise ValueError("rational_interpolate fraction")
    #|    return (
    #|        _symbit_polys_p5a5_text(values[0])
    #|        + "||"
    #|        + _symbit_polys_p5a5_text(values[1])
    #|    )
    #|
    #|def _symbit_polys_p5a5_pairs_text(values, label):
    #|    values = _symbit_polys_p5a5_sequence(values, label)
    #|    parts = []
    #|    for pair in values:
    #|        pair = _symbit_polys_p5a5_sequence(pair, label + " pair")
    #|        if len(pair) < 2:
    #|            continue
    #|        parts.append(
    #|            "("
    #|            + _symbit_polys_p5a5_text(pair[0])
    #|            + ", "
    #|            + _symbit_polys_p5a5_text(pair[1])
    #|            + ")"
    #|        )
    #|    return "[" + ", ".join(parts) + "]"
    #|
    #|def _symbit_polys_p5a5_symmetrize_text(result, formal):
    #|    values = _symbit_polys_p5a5_sequence(result, "symmetrize tuple")
    #|    required = 3 if formal else 2
    #|    if len(values) < required:
    #|        raise ValueError("symmetrize tuple")
    #|    text = (
    #|        _symbit_polys_p5a5_text(values[0])
    #|        + "||"
    #|        + _symbit_polys_p5a5_text(values[1])
    #|    )
    #|    if formal:
    #|        text += "||" + _symbit_polys_p5a5_pairs_text(
    #|            values[2], "symmetrize mapping"
    #|        )
    #|    return text
    #|
    #|def _symbit_polys_p5a5_symmetrize_list_text(result, formal):
    #|    if formal:
    #|        values = _symbit_polys_p5a5_sequence(
    #|            result, "symmetrize list tuple"
    #|        )
    #|        if len(values) < 2:
    #|            raise ValueError("symmetrize list tuple")
    #|        return (
    #|            _symbit_polys_p5a5_pairs_text(
    #|                values[0], "symmetrize list values"
    #|            )
    #|            + "||"
    #|            + _symbit_polys_p5a5_pairs_text(
    #|                values[1], "symmetrize list mapping"
    #|            )
    #|        )
    #|    return _symbit_polys_p5a5_pairs_text(
    #|        result, "symmetrize list values"
    #|    )
    #|
    #|def _symbit_polys_p5a5_viete_text(result):
    #|    values = _symbit_polys_p5a5_sequence(result, "viete result list")
    #|    for pair in values:
    #|        pair = _symbit_polys_p5a5_sequence(pair, "viete result pair")
    #|        for value in pair:
    #|            _symbit_polys_p5a5_text(value)
    #|    return str(result)
    #|
  )
}

///|
fn PolysRecipe::structured_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_structured_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::request_structured_render(
  self : PolysRecipe,
  renderer_name : String,
  args : Array[@recipe.RecipeArg],
) -> String raise {
  let renderer = self.structured_callable(renderer_name)
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, args),
    message="sympy-polys-structured-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_structured_scalar(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.structured_callable("_symbit_polys_p5a5_text")
  let printable = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-structured-scalar-none",
  )
  self.builder.request_str(printable)
}

///|
fn PolysRecipe::structured_expr_args(
  self : PolysRecipe,
  expressions : Array[@symcore.Expr],
  gens : Array[String],
) -> Array[@recipe.RecipeArg] raise {
  let args : Array[@recipe.RecipeArg] = []
  for expression in expressions {
    args.push(Ref(self.expr(expression)))
  }
  for generator in self.literal_symbols(gens) {
    args.push(generator)
  }
  args
}

///|
fn structured_polytools_kwargs(
  domain : String,
  modulus : Int,
) -> Map[String, @recipe.RecipeArg] {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = DecimalInt(Show::to_string(modulus))
  }
  kwargs
}

///|
fn structured_polytools_unary(
  expression : @symcore.Expr,
  gens : Array[String],
  domain : String,
  modulus : Int,
  path : String,
  sequence : Bool,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    path,
    recipe.structured_expr_args([expression], gens),
    kwargs=structured_polytools_kwargs(domain, modulus),
  )
  if sequence {
    recipe.request_structured_render("_symbit_polys_p5a5_sequence_text", [
      Ref(result),
    ])
  } else {
    recipe.request_structured_scalar(result)
  }
}

///|
pub fn reduced(
  f : @symcore.Expr,
  divisors : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [
    Ref(recipe.expr(f)),
    Ref(recipe.expression_list(divisors)),
  ]
  for generator in recipe.literal_symbols(gens) {
    args.push(generator)
  }
  let result = recipe.call(
    "sympy.polys.polytools.reduced",
    args,
    kwargs=structured_polytools_kwargs(domain, modulus),
  )
  recipe.request_structured_render("_symbit_polys_p5a5_reduced_text", [
    Ref(result),
  ])
}

///|
pub fn compose(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.compose",
    recipe.structured_expr_args([f, g], gens),
    kwargs=structured_polytools_kwargs(domain, modulus),
  )
  recipe.request_structured_scalar(result)
}

///|
pub fn decompose(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  structured_polytools_unary(
    f, gens, domain, modulus, "sympy.polys.polytools.decompose", true,
  )
}

///|
pub fn sturm(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  structured_polytools_unary(
    f, gens, domain, modulus, "sympy.polys.polytools.sturm", true,
  )
}

///|
pub fn discriminant(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  structured_polytools_unary(
    f, gens, domain, modulus, "sympy.polys.polytools.discriminant", false,
  )
}

///|
pub fn subresultants(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polytools.subresultants",
    recipe.structured_expr_args([p, q], gens),
    kwargs=structured_polytools_kwargs(domain, modulus),
  )
  recipe.request_structured_render("_symbit_polys_p5a5_sequence_text", [
    Ref(result),
  ])
}

///|
fn PolysRecipe::structured_rational(
  self : PolysRecipe,
  value : @symnum.BigRational,
) -> @recipe.ValueRef raise {
  if value.is_integral() {
    self.call("sympy.Integer", [Str(value.numerator().to_string())])
  } else {
    self.call("sympy.Rational", [
      Str(value.numerator().to_string()),
      Str(value.denominator().to_string()),
    ])
  }
}

///|
fn PolysRecipe::structured_points(
  self : PolysRecipe,
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for point in points {
    items.push(
      Ref(
        self.builder.tuple([
          Ref(self.structured_rational(point.0)),
          Ref(self.structured_rational(point.1)),
        ]),
      ),
    )
  }
  self.builder.list(items)
}

///|
fn PolysRecipe::structured_values(
  self : PolysRecipe,
  values : Array[@symnum.BigRational],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(Ref(self.structured_rational(value)))
  }
  self.builder.list(items)
}

///|
pub fn interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  x? : String = "x",
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.interpolate", [
    Ref(recipe.structured_points(points)),
    Ref(recipe.literal_symbol(x)),
  ])
  recipe.request_structured_scalar(result)
}

///|
pub fn interpolate_values(
  values : Array[@symnum.BigRational],
  x? : String = "x",
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.interpolate", [
    Ref(recipe.structured_values(values)),
    Ref(recipe.literal_symbol(x)),
  ])
  recipe.request_structured_scalar(result)
}

///|
pub fn interpolate_dict(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  x? : String = "x",
) -> String raise {
  let recipe = PolysRecipe::new()
  let entries : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for point in points {
    entries.push(
      (
        Ref(recipe.structured_rational(point.0)),
        Ref(recipe.structured_rational(point.1)),
      ),
    )
  }
  let data = recipe.builder.dict(entries)
  let result = recipe.call("sympy.interpolate", [
    Ref(data),
    Ref(recipe.literal_symbol(x)),
  ])
  recipe.request_structured_scalar(result)
}

///|
pub fn rational_interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  x? : String = "x",
) -> String raise {
  let recipe = PolysRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if x != "" {
    kwargs["X"] = Ref(recipe.literal_symbol(x))
  }
  let result = recipe.call(
    "sympy.rational_interpolate",
    [
      Ref(recipe.structured_points(points)),
      DecimalInt(Show::to_string(deg_num)),
    ],
    kwargs~,
  )
  let fraction = recipe.call("sympy.fraction", [Ref(result)])
  recipe.request_structured_render("_symbit_polys_p5a5_fraction_text", [
    Ref(fraction),
  ])
}

///|
fn PolysRecipe::symmetrize_args(
  self : PolysRecipe,
  expressions : Array[@symcore.Expr],
  gens : Array[String],
  as_list : Bool,
) -> Array[@recipe.RecipeArg] raise {
  let args : Array[@recipe.RecipeArg] = if as_list {
    [Ref(self.expression_list(expressions))]
  } else {
    guard expressions is [expression] else {
      fail("sympy-polys-symmetrize-expression")
    }
    [Ref(self.expr(expression))]
  }
  for generator in self.literal_symbols(gens) {
    args.push(generator)
  }
  args
}

///|
fn PolysRecipe::symmetrize_kwargs(
  self : PolysRecipe,
  formal : Bool,
  symbols : Array[String],
) -> Map[String, @recipe.RecipeArg] raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if formal {
    kwargs["formal"] = Bool(true)
  }
  if !symbols.is_empty() {
    kwargs["symbols"] = Ref(self.literal_symbol_list(symbols))
  }
  kwargs
}

///|
pub fn symmetrize(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.symmetrize",
    recipe.symmetrize_args([expr], gens, false),
    kwargs=recipe.symmetrize_kwargs(formal, symbols),
  )
  recipe.request_structured_render("_symbit_polys_p5a5_symmetrize_text", [
    Ref(result),
    Bool(formal),
  ])
}

///|
pub fn symmetrize_list(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.symmetrize",
    recipe.symmetrize_args(exprs, gens, true),
    kwargs=recipe.symmetrize_kwargs(formal, symbols),
  )
  recipe.request_structured_render("_symbit_polys_p5a5_symmetrize_list_text", [
    Ref(result),
    Bool(formal),
  ])
}

///|
pub fn horner(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  wrt? : String = "",
) -> String raise {
  let recipe = PolysRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if wrt != "" {
    kwargs["wrt"] = Ref(recipe.literal_symbol(wrt))
  }
  let result = recipe.call(
    "sympy.horner",
    recipe.structured_expr_args([expr], gens),
    kwargs~,
  )
  recipe.request_structured_scalar(result)
}

///|
pub fn viete(
  expr : @symcore.Expr,
  roots? : Array[String] = [],
  gen? : String = "",
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.expr(expr))]
  if !roots.is_empty() {
    args.push(Ref(recipe.literal_symbol_list(roots)))
  }
  if gen != "" {
    args.push(Ref(recipe.literal_symbol(gen)))
  }
  let result = recipe.call("sympy.viete", args)
  recipe.request_structured_render("_symbit_polys_p5a5_viete_text", [
    Ref(result),
  ])
}

///|
fn PolysRecipe::string_poly(
  self : PolysRecipe,
  expression : String,
  gens : Array[String],
) -> @recipe.ValueRef raise {
  let parsed = self.call("sympy.sympify", [Str(expression)])
  let args : Array[@recipe.RecipeArg] = [Ref(parsed)]
  for generator in self.literal_symbols(gens) {
    args.push(generator)
  }
  self.call("sympy.Poly", args)
}

///|
fn parse_structured_int(value : String) -> Int raise {
  @string.parse_int(value) catch {
    _ => fail("sympy-polys-structured-int:" + value)
  }
}

///|
pub fn poly_degree_list(
  expr : String,
  gens? : Array[String] = [],
) -> Array[Int] raise {
  let recipe = PolysRecipe::new()
  let polynomial = recipe.string_poly(expr, gens)
  let degree_list = recipe.builder.getattr(polynomial, "degree_list")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(degree_list, []),
    message="sympy-call-none:Poly.degree_list",
  )
  let builtins = recipe.builder.import_module("builtins")
  let list_constructor = recipe.builder.getattr(builtins, "list")
  let list_result = recipe.builder.require_non_none(
    recipe.builder.call(list_constructor, [Ref(result)]),
    message="sympy-polys-degree-list-none",
  )
  match recipe.builder.request(list_result, List(Int)) {
    Array(items) => {
      let degrees : Array[Int] = []
      for item in items {
        match item {
          String(value) => degrees.push(parse_structured_int(value))
          other => fail("sympy-polys-degree-item:" + other.stringify())
        }
      }
      degrees
    }
    other => fail("sympy-polys-degree-list:" + other.stringify())
  }
}

///|
fn string_poly_coeff(
  expr : String,
  gens : Array[String],
  method_name : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let polynomial = recipe.string_poly(expr, gens)
  let callable = recipe.builder.getattr(polynomial, method_name)
  let result = recipe.builder.require_non_none(
    recipe.builder.call(callable, []),
    message="sympy-call-none:Poly." + method_name,
  )
  recipe.request_structured_scalar(result)
}

///|
pub fn poly_lc(expr : String, gens? : Array[String] = []) -> String raise {
  string_poly_coeff(expr, gens, "LC")
}

///|
pub fn poly_tc(expr : String, gens? : Array[String] = []) -> String raise {
  string_poly_coeff(expr, gens, "TC")
}
