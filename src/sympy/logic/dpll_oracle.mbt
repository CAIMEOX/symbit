///|
/// Oracles for sympy.logic.algorithms.dpll/dpll2.

///|
pub fn dpll_satisfiable_str(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let result = logic_call(
    builder,
    "sympy.logic.algorithms.dpll",
    "dpll_satisfiable",
    [Ref(expression)],
  )
  builder.request_str(result)
}

///|
pub fn dpll2_satisfiable_str(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let result = logic_call(
    builder,
    "sympy.logic.algorithms.dpll2",
    "dpll_satisfiable",
    [Ref(expression)],
  )
  builder.request_str(result)
}

///|
pub fn dpll2_all_models_str(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = logic_sympy_expr(builder, expr)
  let result = logic_call(
    builder,
    "sympy.logic.algorithms.dpll2",
    "dpll_satisfiable",
    [Ref(expression)],
    kwargs={ "all_models": Bool(true) },
  )
  let result = logic_sorted_list_string(builder, result)
  builder.request_str(result)
}
