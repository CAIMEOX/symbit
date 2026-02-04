///|
/// Oracles for sympy.logic.inference.

///|
fn sympy_expr_list(exprs : Array[String]) -> Array[OracleArg] raise {
  let out : Array[OracleArg] = Array::new()
  for expr in exprs {
    let obj = sympy_expr(expr)
    out.push(OracleArg::PyObj(objenum_to_obj(obj)))
  }
  out
}

///|
fn model_arg_from_names(
  names : Array[String],
  values : Array[Bool],
) -> OracleArg {
  let dict : Map[String, OracleArg] = Map::new()
  let n = names.length()
  for i in 0..<n {
    dict[names[i]] = OracleArg::Bool(values[i])
  }
  OracleArg::Dict(dict)
}

///|
pub fn inference_literal_symbol(expr : String) -> String raise {
  let expr_obj = sympy_expr(expr)
  let res = sympy_call_must("sympy.logic.inference.literal_symbol", [
    OracleArg::PyObj(objenum_to_obj(expr_obj)),
  ])
  py_str_enum(res)
}

///|
pub fn inference_satisfiable_str(
  expr : String,
  algorithm? : String = "",
  all_models? : Bool = false,
  minimal? : Bool = false,
  use_lra_theory? : Bool = false,
) -> String raise {
  let expr_obj = sympy_expr(expr)
  let args : Array[OracleArg] = [OracleArg::PyObj(objenum_to_obj(expr_obj))]
  if algorithm != "" {
    args.push(OracleArg::Str(algorithm))
  }
  let kwargs : Map[String, OracleArg] = {
    "all_models": OracleArg::Bool(all_models),
    "minimal": OracleArg::Bool(minimal),
    "use_lra_theory": OracleArg::Bool(use_lra_theory),
  }
  let res = sympy_call_must("sympy.logic.inference.satisfiable", args, kwargs~)
  if !all_models {
    return py_str_enum(res)
  }
  let res_str = py_str_enum(res)
  if res_str == "False" {
    return "[False]"
  }
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [
    OracleArg::PyObj(objenum_to_obj(res)),
  ])
  let items = py_list_to_strings(list_res)
  items.sort()
  list_string(items)
}

///|
pub fn inference_valid(expr : String) -> String raise {
  let expr_obj = sympy_expr(expr)
  let res = sympy_call_must("sympy.logic.inference.valid", [
    OracleArg::PyObj(objenum_to_obj(expr_obj)),
  ])
  py_str_enum(res)
}

///|
pub fn inference_entails(
  expr : String,
  formulas : Array[String],
) -> String raise {
  let expr_obj = sympy_expr(expr)
  let list_arg = OracleArg::List(sympy_expr_list(formulas))
  let res = sympy_call_must("sympy.logic.inference.entails", [
    OracleArg::PyObj(objenum_to_obj(expr_obj)),
    list_arg,
  ])
  py_str_enum(res)
}

///|
pub fn inference_pl_true(
  expr : String,
  names : Array[String],
  values : Array[Bool],
  deep? : Bool = false,
) -> String raise {
  let expr_obj = sympy_expr(expr)
  let model = model_arg_from_names(names, values)
  let kwargs : Map[String, OracleArg] = { "deep": OracleArg::Bool(deep) }
  let res = sympy_call_must(
    "sympy.logic.inference.pl_true",
    [OracleArg::PyObj(objenum_to_obj(expr_obj)), model],
    kwargs~,
  )
  py_str_enum(res)
}

///|
pub fn propkb_clauses_str(exprs : Array[String]) -> String raise {
  let clause_fn = py_eval_callable(
    "lambda exprs: sum([list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(e)))) for e in exprs], [])",
  )
  let list_res = py_call_with_args(clause_fn, [OracleArg::StrList(exprs)])
  let items = py_list_to_strings(list_res)
  items.sort()
  list_string(items)
}

///|
pub fn propkb_ask_str(exprs : Array[String], query : String) -> String raise {
  let ask_fn = py_eval_callable(
    "lambda exprs, query: __import__('sympy').logic.inference.entails(__import__('sympy').sympify(query), sum([list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(e)))) for e in exprs], []))",
  )
  let res = py_call_with_args(ask_fn, [
    OracleArg::StrList(exprs),
    OracleArg::Str(query),
  ])
  py_str_enum(res)
}

///|
pub fn propkb_retract_clauses_str(
  exprs : Array[String],
  retract_expr : String,
) -> String raise {
  let clause_fn = py_eval_callable(
    "lambda exprs, retract_expr: [c for c in sum([list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(e)))) for e in exprs], []) if c not in list(__import__('sympy').logic.boolalg.conjuncts(__import__('sympy').logic.boolalg.to_cnf(__import__('sympy').sympify(retract_expr))))]",
  )
  let list_res = py_call_with_args(clause_fn, [
    OracleArg::StrList(exprs),
    OracleArg::Str(retract_expr),
  ])
  let items = py_list_to_strings(list_res)
  items.sort()
  list_string(items)
}
