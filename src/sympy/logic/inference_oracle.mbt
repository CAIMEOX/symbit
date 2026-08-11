///|
/// Oracles for sympy.logic.inference.

///|
fn inference_call(
  builder : @recipe.Builder,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  logic_call(builder, "sympy.logic.inference", name, args, kwargs~)
}

///|
fn inference_model(
  builder : @recipe.Builder,
  names : Array[String],
  values : Array[Bool],
) -> @recipe.ValueRef raise {
  let entries : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for index in 0..<names.length() {
    entries.push((Str(names[index]), Bool(values[index])))
  }
  builder.dict(entries)
}

///|
pub fn inference_literal_symbol(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let result = inference_call(builder, "literal_symbol", [Ref(expression)])
  builder.request_str(result)
}

///|
pub fn inference_satisfiable_str(
  expr : String,
  algorithm? : String = "",
  all_models? : Bool = false,
  minimal? : Bool = false,
  use_lra_theory? : Bool = false,
) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let args : Array[@recipe.RecipeArg] = [Ref(expression)]
  if algorithm != "" {
    args.push(Str(algorithm))
  }
  let result = inference_call(builder, "satisfiable", args, kwargs={
    "all_models": Bool(all_models),
    "minimal": Bool(minimal),
    "use_lra_theory": Bool(use_lra_theory),
  })
  if all_models {
    let result = logic_sorted_list_string(builder, result)
    return builder.request_str(result)
  }
  builder.request_str(result)
}

///|
pub fn inference_valid(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let result = inference_call(builder, "valid", [Ref(expression)])
  builder.request_str(result)
}

///|
pub fn inference_entails(
  expr : String,
  formulas : Array[String],
) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let formulas = logic_expr_list(builder, formulas)
  let result = inference_call(builder, "entails", [
    Ref(expression),
    Ref(formulas),
  ])
  builder.request_str(result)
}

///|
pub fn inference_pl_true(
  expr : String,
  names : Array[String],
  values : Array[Bool],
  deep? : Bool = false,
) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let model = inference_model(builder, names, values)
  let result = inference_call(
    builder,
    "pl_true",
    [Ref(expression), Ref(model)],
    kwargs={ "deep": Bool(deep) },
  )
  builder.request_str(result)
}

///|
pub fn propkb_clauses_str(exprs : Array[String]) -> String raise {
  let builder = @recipe.Builder::new()
  let expressions = logic_string_list(builder, exprs)
  let source = "lambda exprs: sum([list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(e)))) for e in exprs], [])"
  let result = logic_fixed_call(builder, source, [Ref(expressions)])
  let result = logic_sorted_list_string(builder, result)
  builder.request_str(result)
}

///|
pub fn propkb_ask_str(exprs : Array[String], query : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expressions = logic_string_list(builder, exprs)
  let source = "lambda exprs, query: __import__('sympy').logic.inference.entails(__import__('sympy').sympify(query), sum([list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(e)))) for e in exprs], []))"
  let result = logic_fixed_call(builder, source, [Ref(expressions), Str(query)])
  builder.request_str(result)
}

///|
pub fn propkb_retract_clauses_str(
  exprs : Array[String],
  retract_expr : String,
) -> String raise {
  let builder = @recipe.Builder::new()
  let expressions = logic_string_list(builder, exprs)
  let source = "lambda exprs, retract_expr: [c for c in sum([list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(e)))) for e in exprs], []) if c not in list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(retract_expr))))]"
  let result = logic_fixed_call(builder, source, [
    Ref(expressions),
    Str(retract_expr),
  ])
  let result = logic_sorted_list_string(builder, result)
  builder.request_str(result)
}
