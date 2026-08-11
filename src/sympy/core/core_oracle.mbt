///|
/// Serializable keyword values accepted by the core printer oracle.
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
    Int(value) => DecimalInt(value.to_string())
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
        items.push(DecimalInt(value.to_string()))
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
fn materialize_kwargs(
  builder : @recipe.Builder,
  kwargs : Map[String, OracleArg],
) -> Map[String, @recipe.RecipeArg] raise {
  let result : Map[String, @recipe.RecipeArg] = Map([])
  for name, value in kwargs {
    result[name] = value.materialize(builder)
  }
  result
}

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
fn sympy_sstr_value(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let sstr = builder.getattr(sympy, "sstr")
  call_required(
    builder,
    sstr,
    [Ref(value)],
    message="sympy-call-none:sympy.sstr",
  )
}

///|
fn sstr_tuple_value(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  iterable : @recipe.ValueRef,
  should_sort? : Bool = false,
) -> @recipe.ValueRef raise {
  let builtins = builder.import_module("builtins")
  let map_fn = builder.getattr(builtins, "map")
  let sstr = builder.getattr(sympy, "sstr")
  let mapped = call_required(builder, map_fn, [Ref(sstr), Ref(iterable)])
  let ordered = if should_sort {
    let sorted_fn = builder.getattr(builtins, "sorted")
    call_required(builder, sorted_fn, [Ref(mapped)])
  } else {
    mapped
  }
  let tuple_fn = builder.getattr(builtins, "tuple")
  call_required(builder, tuple_fn, [Ref(ordered)])
}

///|
pub fn core_expr_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = sympy_sstr_value(builder, sympy, encoder.encode(expr))
  builder.request_str(value)
}

///|
pub fn core_expr_srepr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let srepr = builder.getattr(sympy, "srepr")
  let value = call_required(
    builder,
    srepr,
    [Ref(encoder.encode(expr))],
    message="sympy-call-none:sympy.srepr",
  )
  builder.request_str(value)
}

///|
pub fn core_expr_latex_kwargs(
  expr : @symcore.Expr,
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let latex = builder.getattr(sympy, "latex")
  let value = call_required(
    builder,
    latex,
    [Ref(encoder.encode(expr))],
    kwargs=materialize_kwargs(builder, kwargs),
    message="sympy-call-none:sympy.latex",
  )
  builder.request_str(value)
}

///|
pub fn core_expr_latex(
  expr : @symcore.Expr,
  mode? : String = "plain",
) -> String raise {
  core_expr_latex_kwargs(expr, kwargs={ "mode": Str(mode) })
}

///|
pub fn core_func_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = encoder.encode(expr)
  let function = builder.getattr(value, "func")
  let fallback = sympy_sstr_value(builder, sympy, function)
  let name = builder.getattr_or(function, "__name__", fallback)
  builder.request_str(name)
}

///|
pub fn core_args_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let args = builder.getattr(encoder.encode(expr), "args")
  let value = sstr_tuple_value(builder, sympy, args)
  builder.request_str(value)
}

///|
pub fn core_attr_bool(expr : @symcore.Expr, attr : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = encoder.encode(expr)
  if attr == "is_nan" {
    let operator = builder.import_module("operator")
    let identical = builder.getattr(operator, "is_")
    let nan = builder.getattr(sympy, "nan")
    let result = call_required(builder, identical, [Ref(value), Ref(nan)])
    return builder.request_bool(result)
  }
  if attr == "is_one" {
    let operator = builder.import_module("operator")
    let equal = builder.getattr(operator, "eq")
    let integer = builder.getattr(sympy, "Integer")
    let one = call_required(builder, integer, [DecimalInt("1")])
    let result = call_required(builder, equal, [Ref(value), Ref(one)])
    return builder.request_bool(result)
  }
  let attribute = builder.getattr(value, attr)
  builder.request_str(attribute) == "True"
}

///|
pub fn core_parameters_sstr(
  expr_code : String,
  evaluate? : Bool = true,
  distribute? : Bool = true,
  exp_is_pow? : Bool = false,
) -> String raise {
  let evaluate_text = if evaluate { "True" } else { "False" }
  let distribute_text = if distribute { "True" } else { "False" }
  let exp_is_pow_text = if exp_is_pow { "True" } else { "False" }
  let script = "import contextlib\n" +
    "from sympy.core.parameters import evaluate, distribute, _exp_is_pow\n" +
    "x = sympy.Symbol('x')\n" +
    "y = sympy.Symbol('y')\n" +
    "with contextlib.ExitStack() as _stack:\n" +
    "    _stack.enter_context(evaluate(" +
    evaluate_text +
    "))\n" +
    "    _stack.enter_context(distribute(" +
    distribute_text +
    "))\n" +
    "    _stack.enter_context(_exp_is_pow(" +
    exp_is_pow_text +
    "))\n" +
    "    __result__ = sympy.sstr(" +
    expr_code +
    ")\n"
  let builder = @recipe.Builder::new()
  // Match the deliberately narrow globals dictionary used by the former
  // embedded-Python helper.  In particular, unqualified SymPy names are not
  // injected here: callers must spell them through `sympy` unless the script
  // imports them itself.
  let builtins = builder.import_module("builtins")
  let sympy = builder.import_module("sympy")
  let scope = builder.dict([
    (Str("__builtins__"), Ref(builtins)),
    (Str("sympy"), Ref(sympy)),
  ])
  let executed = builder.exec(scope, script)
  let result = builder.getitem(executed, Str("__result__"))
  builder.request_str(result)
}

///|
pub fn core_free_symbols_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let symbols = builder.getattr(encoder.encode(expr), "free_symbols")
  let value = sstr_tuple_value(builder, sympy, symbols, should_sort=true)
  builder.request_str(value)
}

///|
pub fn core_atoms_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let atoms = builder.getattr(encoder.encode(expr), "atoms")
  let values = call_required(builder, atoms, [])
  let result = sstr_tuple_value(builder, sympy, values, should_sort=true)
  builder.request_str(result)
}

///|
pub fn core_has_bool(
  expr : @symcore.Expr,
  needle : @symcore.Expr,
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let value = encoder.encode(expr)
  let has = builder.getattr(value, "has")
  let result = call_required(builder, has, [Ref(encoder.encode(needle))])
  builder.request_str(result) == "True"
}

///|
pub fn core_xreplace_sstr(
  expr : @symcore.Expr,
  old_expr : @symcore.Expr,
  new_expr : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = encoder.encode(expr)
  let replacements = builder.dict([
    (Ref(encoder.encode(old_expr)), Ref(encoder.encode(new_expr))),
  ])
  let xreplace = builder.getattr(value, "xreplace")
  let replaced = call_required(builder, xreplace, [Ref(replacements)])
  let result = sympy_sstr_value(builder, sympy, replaced)
  builder.request_str(result)
}

///|
pub fn core_replace_sin_with_cos_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let mut scope = builder.sympy_scope()
  scope = builder.bind(scope, "expr", Ref(encoder.encode(expr)))
  let code = "sympy.sstr(expr.replace(lambda e: e.func == sympy.sin, " +
    "lambda e: sympy.cos(*e.args)))"
  let result = builder.require_non_none(
    builder.eval(scope, code),
    message="py-eval-none",
  )
  builder.request_str(result)
}

///|
fn core_subst_sstr(
  expr : @symcore.Expr,
  old_expr : @symcore.Expr,
  new_expr : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = encoder.encode(expr)
  let subs = builder.getattr(value, "subs")
  let replaced = call_required(builder, subs, [
    Ref(encoder.encode(old_expr)),
    Ref(encoder.encode(new_expr)),
  ])
  let result = sympy_sstr_value(builder, sympy, replaced)
  builder.request_str(result)
}

///|
pub fn core_subst_symbol_sstr(
  expr : @symcore.Expr,
  symbol_name : String,
  new_expr : @symcore.Expr,
) -> String raise {
  core_subst_sstr(expr, Symbol(symbol_name), new_expr)
}

///|
pub fn core_subst_expr_sstr(
  expr : @symcore.Expr,
  old_expr : @symcore.Expr,
  new_expr : @symcore.Expr,
) -> String raise {
  core_subst_sstr(expr, old_expr, new_expr)
}

///|
pub fn core_sorted_sstr(exprs : Array[@symcore.Expr]) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let items : Array[@recipe.RecipeArg] = []
  for expr in exprs {
    items.push(Ref(encoder.encode(expr)))
  }
  let values = builder.list(items)
  let builtins = builder.import_module("builtins")
  let sorted_fn = builder.getattr(builtins, "sorted")
  let sort_key = builder.getattr(sympy, "default_sort_key")
  let sorted_values = call_required(builder, sorted_fn, [Ref(values)], kwargs={
    "key": Ref(sort_key),
  })
  let result = sstr_tuple_value(builder, sympy, sorted_values)
  builder.request_str(result)
}

///|
pub fn core_evalf_sstr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let evalf = builder.getattr(encoder.encode(expr), "evalf")
  let value = call_required(builder, evalf, [])
  let result = sympy_sstr_value(builder, sympy, value)
  builder.request_str(result)
}

///|
pub fn core_match_sstr(
  pattern : @symcore.Expr,
  expr : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let mut scope = builder.sympy_scope()
  scope = builder.bind(scope, "pattern", Ref(encoder.encode(pattern)))
  scope = builder.bind(scope, "expr", Ref(encoder.encode(expr)))
  let code = "('None' if pattern.matches(expr) is None else '|'.join(" +
    "f'{sympy.sstr(k)}={sympy.sstr(v)}' " +
    "for k, v in sorted(pattern.matches(expr).items(), " +
    "key=lambda kv: sympy.sstr(kv[0]))))"
  let result = builder.require_non_none(
    builder.eval(scope, code),
    message="py-eval-none",
  )
  builder.request_str(result)
}

///|
fn core_traversal_sstr(
  traversal_name : String,
  expr : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let traversal = builder.getattr(sympy, traversal_name)
  let values = call_required(builder, traversal, [Ref(encoder.encode(expr))])
  let result = sstr_tuple_value(builder, sympy, values)
  builder.request_str(result)
}

///|
pub fn core_preorder_sstr(expr : @symcore.Expr) -> String raise {
  core_traversal_sstr("preorder_traversal", expr)
}

///|
pub fn core_postorder_sstr(expr : @symcore.Expr) -> String raise {
  core_traversal_sstr("postorder_traversal", expr)
}
