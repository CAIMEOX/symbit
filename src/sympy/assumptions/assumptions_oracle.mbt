///|
fn call_required(
  builder : @recipe.Builder,
  callable : @recipe.ValueRef,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  message? : String = "sympy-call-none",
) -> @recipe.ValueRef raise {
  builder.require_non_none(builder.call(callable, args, kwargs~), message~)
}

///|
fn put_tri_kw(
  kwargs : Map[String, @recipe.RecipeArg],
  key : String,
  value : @symassume.Tri,
) -> Unit {
  match @symassume.tri_to_bool_option(value) {
    Some(value) => kwargs[key] = Bool(value)
    None => ()
  }
}

///|
fn symbol_with_facts(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  name : String,
  facts : @symassume.SymbolFacts,
) -> @recipe.ValueRef raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  put_tri_kw(kwargs, "zero", facts.is_zero)
  put_tri_kw(kwargs, "nonzero", facts.is_nonzero)
  put_tri_kw(kwargs, "integer", facts.is_integer)
  put_tri_kw(kwargs, "rational", facts.is_rational)
  put_tri_kw(kwargs, "real", facts.is_real)
  put_tri_kw(kwargs, "positive", facts.is_positive)
  put_tri_kw(kwargs, "nonnegative", facts.is_nonnegative)
  let symbol = builder.getattr(sympy, "Symbol")
  call_required(
    builder,
    symbol,
    [Str(name)],
    kwargs~,
    message="sympy-call-none:sympy.Symbol",
  )
}

///|
fn locals_from_env(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  env : Map[String, @symassume.SymbolFacts],
) -> @recipe.ValueRef raise {
  let entries : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for name, facts in env {
    entries.push(
      (Str(name), Ref(symbol_with_facts(builder, sympy, name, facts))),
    )
  }
  builder.dict(entries)
}

///|
fn sympify_with_env(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  expr : @symcore.Expr,
  env : Map[String, @symassume.SymbolFacts],
) -> @recipe.ValueRef raise {
  let sympify = builder.getattr(sympy, "sympify")
  let locals = locals_from_env(builder, sympy, env)
  call_required(
    builder,
    sympify,
    [Str(@symprint.pretty_string(expr))],
    kwargs={ "locals": Ref(locals) },
    message="sympy-call-none:sympy.sympify",
  )
}

///|
pub fn expr_attr(
  expr : @symcore.Expr,
  attr : String,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let value = sympify_with_env(builder, sympy, expr, env)
  let attribute = builder.getattr(value, attr)
  builder.request_str(attribute)
}

///|
pub fn is_zero(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_zero", env~)
}

///|
pub fn is_nonzero(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_nonzero", env~)
}

///|
pub fn is_integer(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_integer", env~)
}

///|
pub fn is_rational(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_rational", env~)
}

///|
pub fn is_real(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_real", env~)
}

///|
pub fn is_positive(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_positive", env~)
}

///|
pub fn is_nonnegative(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_nonnegative", env~)
}

///|
fn ask_query_str_raise(
  proposition : String,
  assumptions : String,
) -> String raise {
  let builder = @recipe.Builder::new()
  let builtins = builder.import_module("builtins")
  let sympy = builder.import_module("sympy")
  let scope = builder.dict([
    (Str("__builtins__"), Ref(builtins)),
    (Str("sympy"), Ref(sympy)),
  ])
  let setup = "for _name in (\n" +
    "    'Q', 'ask', 'Implies', 'Equivalent', 'And', 'Or', 'Not',\n" +
    "    'Eq', 'Ne', 'Gt', 'Ge', 'Lt', 'Le', 'MatrixSymbol',\n" +
    "):\n" +
    "    if hasattr(sympy, _name):\n" +
    "        globals()[_name] = getattr(sympy, _name)\n" +
    "for _name in ('x', 'y', 'z', 'a', 'b', 'c', 'n', 'm', 't', 'u', 'v'):\n" +
    "    globals()[_name] = sympy.Symbol(_name)\n" +
    "for _name in ('oo', 'zoo', 'I', 'E', 'pi'):\n" +
    "    if hasattr(sympy, _name):\n" +
    "        globals()[_name] = getattr(sympy, _name)\n" +
    "del _name\n"
  let scope = builder.exec(scope, setup)
  let expression = "str(ask(\{proposition}, assumptions=(\{assumptions})))"
  let value = builder.eval(scope, expression)
  builder.request_str(value)
}

///|
pub fn ask_query_str(
  proposition : String,
  assumptions? : String = "True",
) -> String {
  let result : Result[String, Error] = try
    ask_query_str_raise(proposition, assumptions) |> Ok
  catch {
    error => Err(error)
  }
  match result {
    Ok(value) => value
    Err(error) => {
      let message = "\{error}"
      if message.contains("inconsistent assumptions") ||
        message.contains("py-eval-none") {
        "InconsistentAssumptions"
      } else {
        "OracleError:\{message}"
      }
    }
  }
}
