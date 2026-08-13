///|
/// Request-serializable values accepted by `sympy_call_string`.
///
/// Unlike the legacy bridge argument, this type deliberately has no live
/// Python-object variant. Nested lists and dictionaries are materialized in
/// the same worker request as the call that consumes them.
pub(all) enum OracleArg {
  Null
  Str(String)
  Int(Int)
  Bool(Bool)
  StrList(Array[String])
  IntList(Array[Int])
  List(Array[OracleArg])
  Dict(Map[String, OracleArg])
}

///|
fn OracleArg::materialize(
  self : OracleArg,
  builder : @recipe.Builder,
) -> @recipe.RecipeArg raise {
  match self {
    Null => Null
    Str(value) => Str(value)
    Int(value) => DecimalInt(Show::to_string(value))
    Bool(value) => Bool(value)
    StrList(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(Str(value))
      }
      Ref(builder.list(items))
    }
    IntList(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(DecimalInt(Show::to_string(value)))
      }
      Ref(builder.list(items))
    }
    List(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(value.materialize(builder))
      }
      Ref(builder.list(items))
    }
    Dict(values) => {
      let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
      for key, value in values {
        items.push((Str(key), value.materialize(builder)))
      }
      Ref(builder.dict(items))
    }
  }
}

///|
priv struct PolysRecipe {
  builder : @recipe.Builder
  encoder : @exprcodec.Encoder
}

///|
fn PolysRecipe::new() -> PolysRecipe raise {
  let builder = @recipe.Builder::new()
  { builder, encoder: @exprcodec.Encoder::new(builder) }
}

///|
fn recipe_sympy_callable(
  builder : @recipe.Builder,
  path : String,
) -> @recipe.ValueRef raise {
  let trimmed = path.trim()
  guard trimmed.length() > 0 else { fail("sympy-call-empty") }
  let parts : Array[String] = []
  for part in trimmed.split(".") {
    parts.push(part.to_owned())
  }
  let module_name = if parts.length() == 1 {
    "sympy"
  } else {
    let requested = parts[0:parts.length() - 1].join(".")
    if requested == "sympy" || requested.has_prefix("sympy.") {
      requested
    } else {
      "sympy." + requested
    }
  }
  let module_object = builder.import_module(module_name)
  builder.getattr(module_object, parts[parts.length() - 1])
}

///|
fn PolysRecipe::call(
  self : PolysRecipe,
  path : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  allow_none? : Bool = false,
) -> @recipe.ValueRef raise {
  let callable = recipe_sympy_callable(self.builder, path)
  let result = self.builder.call(callable, args, kwargs~)
  if allow_none {
    result
  } else {
    self.builder.require_non_none(result, message="sympy-call-none:" + path)
  }
}

///|
fn PolysRecipe::expr(
  self : PolysRecipe,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  self.encoder.encode(expression)
}

///|
fn polys_polyutils_foundation_source() -> String {
  (
    #|import operator as _symbit_polys_operator
    #|
    #|def _symbit_polys_poly_default_gens(expr, domain, modulus, use_domain, use_modulus):
    #|    kwargs = {}
    #|    if use_domain:
    #|        kwargs["domain"] = domain
    #|    if use_modulus:
    #|        kwargs["modulus"] = modulus
    #|    gens = sorted(expr.free_symbols, key=_symbit_polys_operator.attrgetter("name"))
    #|    return sympy.Poly(expr, *gens, **kwargs)
    #|
    #|def _symbit_polys_monomial_text(exponents):
    #|    body = ",".join(str(int(exponent)) for exponent in exponents)
    #|    if len(exponents) == 1:
    #|        body += ","
    #|    return "(" + body + ")"
    #|
    #|def _symbit_polys_dict_text(rep):
    #|    entries = sorted(rep.items(), key=lambda item: tuple(item[0]))
    #|    return "{" + ",".join(
    #|        _symbit_polys_monomial_text(monomial) + ":" + str(coeff)
    #|        for monomial, coeff in entries
    #|    ) + "}"
    #|
    #|def _symbit_polys_gens_text(gens):
    #|    return "[" + ",".join('"' + str(gen) + '"' for gen in gens) + "]"
    #|
    #|def _symbit_polys_dict_result(result):
    #|    rep, gens = result
    #|    return _symbit_polys_dict_text(rep) + "||" + _symbit_polys_gens_text(gens)
    #|
    #|def _symbit_polys_parallel_dict_result(result):
    #|    reps, gens = result
    #|    reps_text = "[" + ",".join(_symbit_polys_dict_text(rep) for rep in reps) + "]"
    #|    return reps_text + "||" + _symbit_polys_gens_text(gens)
  )
}

///|
fn PolysRecipe::foundation_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_polyutils_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::literal_symbol(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.call("sympy.Symbol", [Str(name)])
}

///|
fn PolysRecipe::literal_symbols(
  self : PolysRecipe,
  names : Array[String],
) -> Array[@recipe.RecipeArg] raise {
  let result : Array[@recipe.RecipeArg] = []
  for name in names {
    result.push(Ref(self.literal_symbol(name)))
  }
  result
}

///|
fn PolysRecipe::literal_symbol_list(
  self : PolysRecipe,
  names : Array[String],
) -> @recipe.ValueRef raise {
  self.builder.list(self.literal_symbols(names))
}

///|
fn PolysRecipe::expression_list(
  self : PolysRecipe,
  expressions : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  let result : Array[@recipe.RecipeArg] = []
  for expression in expressions {
    result.push(Ref(self.expr(expression)))
  }
  self.builder.list(result)
}

///|
fn PolysRecipe::request_string_array(
  self : PolysRecipe,
  value : @recipe.ValueRef,
) -> Array[String] raise {
  let builtins = self.builder.import_module("builtins")
  let list_constructor = self.builder.getattr(builtins, "list")
  let list_value = self.builder.require_non_none(
    self.builder.call(list_constructor, [Ref(value)]),
    message="sympy-polys-string-list-none",
  )
  let codec : @recipe.ResultCodec = List(Str)
  match self.builder.request(list_value, codec) {
    Array(items) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(text) => result.push(text)
          other => fail("sympy-polys-string-item:" + other.stringify())
        }
      }
      result
    }
    other => fail("sympy-polys-string-array:" + other.stringify())
  }
}

///|
pub fn poly_expr(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let recipe = PolysRecipe::new()
  let expression = recipe.expr(expr)
  let polynomial = if gens.is_empty() {
    let callable = recipe.foundation_callable("_symbit_polys_poly_default_gens")
    recipe.builder.require_non_none(
      recipe.builder.call(callable, [
        Ref(expression),
        Str(domain),
        DecimalInt(Show::to_string(modulus)),
        Bool(domain != ""),
        Bool(modulus != 0),
      ]),
      message="sympy-call-none:sympy.Poly",
    )
  } else {
    let args : Array[@recipe.RecipeArg] = [Ref(expression)]
    for symbol in recipe.literal_symbols(gens) {
      args.push(symbol)
    }
    let kwargs : Map[String, @recipe.RecipeArg] = Map([])
    if domain != "" {
      kwargs["domain"] = Str(domain)
    }
    if modulus != 0 {
      kwargs["modulus"] = DecimalInt(Show::to_string(modulus))
    }
    recipe.call("sympy.Poly", args, kwargs~)
  }
  let as_expr = recipe.builder.getattr(polynomial, "as_expr")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(as_expr, []),
    message="sympy-polys-poly-as-expr-none",
  )
  recipe.builder.request_str(result)
}

///|
pub fn mod_rational(num : Int, den : Int, p : Int) -> String raise {
  let recipe = PolysRecipe::new()
  let inverse = recipe.call("sympy.mod_inverse", [
    DecimalInt(Show::to_string(den)),
    DecimalInt(Show::to_string(p)),
  ])
  let numerator = recipe.call("sympy.Integer", [
    DecimalInt(Show::to_string(num)),
  ])
  let product = recipe.call("sympy.Mul", [Ref(numerator), Ref(inverse)])
  let result = recipe.call("sympy.Mod", [
    Ref(product),
    DecimalInt(Show::to_string(p)),
  ])
  recipe.builder.request_str(result)
}

///|
pub fn dict_from_expr(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if !gens.is_empty() {
    kwargs["gens"] = Ref(recipe.literal_symbol_list(gens))
  }
  let result = recipe.call(
    "sympy.polys.polyutils.dict_from_expr",
    [Ref(recipe.expr(expr))],
    kwargs~,
  )
  let renderer = recipe.foundation_callable("_symbit_polys_dict_result")
  let rendered = recipe.builder.require_non_none(
    recipe.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-dict-render-none",
  )
  recipe.builder.request_str(rendered)
}

///|
pub fn parallel_dict_from_expr(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = [],
) -> String raise {
  let recipe = PolysRecipe::new()
  let expressions = recipe.expression_list(exprs)
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if !gens.is_empty() {
    kwargs["gens"] = Ref(recipe.literal_symbol_list(gens))
  }
  let result = recipe.call(
    "sympy.polys.polyutils.parallel_dict_from_expr",
    [Ref(expressions)],
    kwargs~,
  )
  let renderer = recipe.foundation_callable(
    "_symbit_polys_parallel_dict_result",
  )
  let rendered = recipe.builder.require_non_none(
    recipe.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-parallel-dict-render-none",
  )
  recipe.builder.request_str(rendered)
}

///|
pub fn expr_from_dict(rep : String, gens : Array[String]) -> String raise {
  let recipe = PolysRecipe::new()
  let representation = recipe.call("sympy.sympify", [Str(rep)])
  let args : Array[@recipe.RecipeArg] = [Ref(representation)]
  for symbol in recipe.literal_symbols(gens) {
    args.push(symbol)
  }
  let result = recipe.call("sympy.polys.polyutils.expr_from_dict", args)
  recipe.builder.request_str(result)
}

///|
pub fn sort_gens(
  gens : Array[String],
  wrt? : Array[String] = [],
  sort? : String = "",
) -> Array[String] raise {
  let recipe = PolysRecipe::new()
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if !wrt.is_empty() {
    kwargs["wrt"] = Ref(recipe.literal_symbol_list(wrt))
  }
  if sort != "" {
    kwargs["sort"] = Str(sort)
  }
  let result = recipe.call(
    "sympy.polys.polyutils._sort_gens",
    [Ref(recipe.literal_symbol_list(gens))],
    kwargs~,
  )
  recipe.request_string_array(result)
}

///|
pub fn unify_gens(a : Array[String], b : Array[String]) -> Array[String] raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.polys.polyutils._unify_gens", [
    Ref(recipe.literal_symbol_list(a)),
    Ref(recipe.literal_symbol_list(b)),
  ])
  recipe.request_string_array(result)
}

///|
pub fn analyze_gens(gens : Array[String]) -> Array[String] raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.polys.polyutils._analyze_gens", [
    Ref(recipe.literal_symbol_list(gens)),
  ])
  recipe.request_string_array(result)
}

///|
pub fn analyze_gens_nested(gens : Array[Array[String]]) -> Array[String] raise {
  let recipe = PolysRecipe::new()
  let groups : Array[@recipe.RecipeArg] = []
  for group in gens {
    groups.push(Ref(recipe.literal_symbol_list(group)))
  }
  let outer = recipe.builder.list(groups)
  let result = recipe.call("sympy.polys.polyutils._analyze_gens", [Ref(outer)])
  recipe.request_string_array(result)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let recipe = PolysRecipe::new()
  let left = recipe.call("sympy.sympify", [Str(lhs)])
  let right = recipe.call("sympy.sympify", [Str(rhs)])
  let negative_one = recipe.call("sympy.Integer", [DecimalInt("-1")])
  let negative_right = recipe.call("sympy.Mul", [Ref(negative_one), Ref(right)])
  let difference = recipe.call("sympy.Add", [Ref(left), Ref(negative_right)])
  let result = recipe.call("sympy.simplify", [Ref(difference)])
  recipe.builder.request_str(result) == "0"
}

///|
fn PolysRecipe::stringify_legacy_call_result(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  // `sympy_call_string` historically printed a Poly through `as_expr()` and
  // used ordinary `str()` for every other result. The source is fixed; only
  // the request-owned result reference is bound as data.
  let scope = self.builder.sympy_scope()
  let scope = self.builder.bind(scope, "__symbit_polys_result", Ref(result))
  self.builder.eval(
    scope,
    (
      #|(__symbit_polys_result.as_expr()
      #| if isinstance(__symbit_polys_result, sympy.Poly)
      #| else __symbit_polys_result)
    ),
  )
}

///|
fn materialize_oracle_args(
  builder : @recipe.Builder,
  values : Array[OracleArg],
) -> Array[@recipe.RecipeArg] raise {
  let result : Array[@recipe.RecipeArg] = []
  for value in values {
    result.push(value.materialize(builder))
  }
  result
}

///|
fn materialize_oracle_kwargs(
  builder : @recipe.Builder,
  values : Map[String, OracleArg],
) -> Map[String, @recipe.RecipeArg] raise {
  let result : Map[String, @recipe.RecipeArg] = Map([])
  for name, value in values {
    result[name] = value.materialize(builder)
  }
  result
}

///|
/// Call the legacy public SymPy path contract in the persistent worker.
///
/// A one-component path resolves on `sympy`; multi-component paths resolve a
/// module, with an implicit `sympy.` prefix when it is omitted. The path is
/// transported as import/attribute data and is never interpolated into Python
/// source.
pub fn sympy_call_string(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    path,
    materialize_oracle_args(recipe.builder, args),
    kwargs=materialize_oracle_kwargs(recipe.builder, kwargs),
  )
  let printable = recipe.stringify_legacy_call_result(result)
  recipe.builder.request_str(printable)
}

///|
pub fn monomial_key(order? : String = "lex") -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.polys.orderings.monomial_key", [Str(order)])
  recipe.builder.request_str(result)
}

///|
pub fn polyconfig_configure() -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polyconfig.configure",
    [],
    allow_none=true,
  )
  recipe.builder.request_str(result)
}

///|
pub fn polyconfig_query(key : String) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polyconfig.query",
    [Str(key)],
    allow_none=true,
  )
  recipe.builder.request_str(result)
}

///|
pub fn polyconfig_setup_default(key : String) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polyconfig.setup",
    [Str(key)],
    allow_none=true,
  )
  recipe.builder.request_str(result)
}

///|
pub fn polyconfig_setup_bool(key : String, value : Bool) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polyconfig.setup",
    [Str(key), Bool(value)],
    allow_none=true,
  )
  recipe.builder.request_str(result)
}

///|
pub fn polyconfig_setup_int(key : String, value : Int) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polyconfig.setup",
    [Str(key), DecimalInt(Show::to_string(value))],
    allow_none=true,
  )
  recipe.builder.request_str(result)
}

///|
pub fn polyconfig_setup_text(key : String, value : String) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call(
    "sympy.polys.polyconfig.setup",
    [Str(key), Str(value)],
    allow_none=true,
  )
  recipe.builder.request_str(result)
}

///|
/// Canonicalise an expression string via `str(sympy.sympify(expr))` so that
/// ordering matches SymPy’s printer (helps when our printer orders constants
/// first).
pub fn sympy_normalize(expr_str : String) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.sympify", [Str(expr_str)])
  recipe.builder.request_str(result)
}

///|
pub fn cancel(p : @symcore.Expr, q : @symcore.Expr) -> String raise {
  let recipe = PolysRecipe::new()
  let p_value = recipe.expr(p)
  let q_value = recipe.expr(q)
  let divide = recipe.builder.getattr(p_value, "__truediv__")
  let quotient = recipe.builder.require_non_none(
    recipe.builder.call(divide, [Ref(q_value)]),
    message="sympy-call-none:Expr.__truediv__",
  )
  let cancelled = recipe.call("sympy.cancel", [Ref(quotient)])
  let fraction = recipe.call("sympy.fraction", [Ref(cancelled)])
  let numerator = recipe.builder.getitem(fraction, DecimalInt("0"))
  let denominator = recipe.builder.getitem(fraction, DecimalInt("1"))
  let builtins = recipe.builder.import_module("builtins")
  let str_callable = recipe.builder.getattr(builtins, "str")
  let numerator_text = recipe.builder.call(str_callable, [Ref(numerator)])
  let denominator_text = recipe.builder.call(str_callable, [Ref(denominator)])
  let operator = recipe.builder.import_module("operator")
  let add = recipe.builder.getattr(operator, "add")
  let prefix = recipe.builder.call(add, [Ref(numerator_text), Str("||")])
  let result = recipe.builder.call(add, [Ref(prefix), Ref(denominator_text)])
  recipe.builder.request_str(result)
}
