///|
/// Oracle helpers for SymPy functions.

///|
fn sympify_required(
  builder : @recipe.Builder,
  sympify : @recipe.ValueRef,
  expression : String,
) -> @recipe.ValueRef raise {
  let value = builder.call(sympify, [Str(expression)])
  builder.require_non_none(value, message="sympy-call-none:sympy.sympify")
}

///|
/// Sympify an expression and return its Python string representation.
pub fn sympy_str(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let expression = sympify_required(builder, sympify, expr_str)
  builder.request_str(expression)
}

///|
/// Sympify an expression and return its SymPy structural representation.
pub fn sympy_srepr(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let expression = sympify_required(builder, sympify, expr_str)
  builder.request_srepr(expression)
}

///|
/// Compare two expression strings by their independently constructed SymPy
/// structural representations.
pub fn expr_str_eq(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let srepr = builder.getattr(sympy, "srepr")
  let operator = builder.import_module("operator")
  let equal = builder.getattr(operator, "eq")
  let a_expression = sympify_required(builder, sympify, a)
  let b_expression = sympify_required(builder, sympify, b)
  let a_repr = builder.call(srepr, [Ref(a_expression)])
  let b_repr = builder.call(srepr, [Ref(b_expression)])
  let result = builder.call(equal, [Ref(a_repr), Ref(b_repr)])
  builder.request_bool(result)
}
