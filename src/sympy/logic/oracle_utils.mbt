///|
/// Request-local recipe helpers shared by the logic oracles.

///|
fn logic_call(
  builder : @recipe.Builder,
  module_name : String,
  callable_name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let module_obj = builder.import_module(module_name)
  let callable = builder.getattr(module_obj, callable_name)
  let result = builder.call(callable, args, kwargs~)
  builder.require_non_none(
    result,
    message="sympy-call-none:\{module_name}.\{callable_name}",
  )
}

///|
fn logic_sympy_expr(
  builder : @recipe.Builder,
  expression : String,
) -> @recipe.ValueRef raise {
  logic_call(builder, "sympy", "sympify", [Str(expression)])
}

///|
fn logic_string_list(
  builder : @recipe.Builder,
  values : Array[String],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = values.map(value => Str(value))
  builder.list(items)
}

///|
fn logic_int_list(
  builder : @recipe.Builder,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = values.map(value => {
    DecimalInt(Show::to_string(value))
  })
  builder.list(items)
}

///|
fn logic_expr_list(
  builder : @recipe.Builder,
  expressions : Array[String],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for expression in expressions {
    items.push(Ref(logic_sympy_expr(builder, expression)))
  }
  builder.list(items)
}

///|
fn logic_fixed_call(
  builder : @recipe.Builder,
  callable_source : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let callable = builder.eval(scope, callable_source)
  let result = builder.call(callable, args)
  builder.require_non_none(result, message="py-call-none")
}

///|
fn logic_sorted_list_string(
  builder : @recipe.Builder,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let source =
    #|def _symbit_logic_sorted_list(value):
    #|    if value is False:
    #|        return '[False]'
    #|    return '[' + ', '.join(sorted(str(item) for item in list(value))) + ']'
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let scope = builder.exec(scope, source)
  let format = builder.getitem(scope, Str("_symbit_logic_sorted_list"))
  builder.call(format, [Ref(value)])
}
