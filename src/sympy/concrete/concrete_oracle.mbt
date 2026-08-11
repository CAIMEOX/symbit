///|
/// Oracle helpers for SymPy concrete.

///|
fn sympify_str(
  builder : @recipe.Builder,
  callable : @recipe.ValueRef,
  expr_str : String,
) -> @recipe.ValueRef raise {
  let value = builder.call(callable, [Str(expr_str)])
  builder.require_non_none(value, message="sympy-call-none:sympy.sympify")
}

///|
/// Parse a SymPy expression and return its canonical string form.
pub fn sympy_str(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let expr = sympify_str(builder, sympify, expr_str)
  builder.request_str(expr)
}

///|
/// Parse a SymPy expression and return its structural representation.
pub fn sympy_srepr(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let expr = sympify_str(builder, sympify, expr_str)
  builder.request_srepr(expr)
}

///|
/// Compare the structural representations of two independently parsed expressions.
pub fn expr_str_eq(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify_callable = builder.getattr(sympy, "sympify")
  let a_expr = sympify_str(builder, sympify_callable, a)
  let b_expr = sympify_str(builder, sympify_callable, b)
  let srepr_callable = builder.getattr(sympy, "srepr")
  let a_srepr = builder.call(srepr_callable, [Ref(a_expr)])
  let b_srepr = builder.call(srepr_callable, [Ref(b_expr)])
  let operator = builder.import_module("operator")
  let equal = builder.getattr(operator, "eq")
  let result = builder.call(equal, [Ref(a_srepr), Ref(b_srepr)])
  builder.request_bool(result)
}

///|
/// Return whether simplifying the difference of two expression strings yields zero.
pub fn sympy_equiv_str(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let simplify = builder.getattr(sympy, "simplify")
  let diff = "(\{a}) - (\{b})"
  let simplified = builder.call(simplify, [Str(diff)])
  let required = builder.require_non_none(
    simplified,
    message="sympy-call-none:sympy.simplify",
  )
  builder.request_str(required) == "0"
}
