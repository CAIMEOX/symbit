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
