///|
/// Oracles for sympy.logic.algorithms.dpll/dpll2.

///|
pub fn dpll_satisfiable_str(expr : String) -> String raise {
  let expr_obj = sympy_expr(expr)
  let res = sympy_call_must(
    "sympy.logic.algorithms.dpll.dpll_satisfiable",
    [OracleArg::PyObj(objenum_to_obj(expr_obj))],
  )
  py_str_enum(res)
}

///|
pub fn dpll2_satisfiable_str(expr : String) -> String raise {
  let expr_obj = sympy_expr(expr)
  let res = sympy_call_must(
    "sympy.logic.algorithms.dpll2.dpll_satisfiable",
    [OracleArg::PyObj(objenum_to_obj(expr_obj))],
  )
  py_str_enum(res)
}

///|
pub fn dpll2_all_models_str(expr : String) -> String raise {
  let expr_obj = sympy_expr(expr)
  let kwargs : Map[String, OracleArg] = { "all_models": OracleArg::Bool(true) }
  let res = sympy_call_must(
    "sympy.logic.algorithms.dpll2.dpll_satisfiable",
    [OracleArg::PyObj(objenum_to_obj(expr_obj))],
    kwargs~,
  )
  let res_str = py_str_enum(res)
  if res_str == "False" {
    return "[False]"
  }
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  let items = py_list_to_strings(list_res)
  items.sort()
  list_string(items)
}
