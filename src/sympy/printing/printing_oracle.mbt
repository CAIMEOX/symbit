///|
/// Run one named SymPy printer on a structurally encoded expression.
pub fn printing_call(name : String, expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let expression = @exprcodec.encode_expr(builder, expr)
  let path = ("sympy." + name).trim()
  let parts : Array[String] = []
  for part in path.split(".") {
    parts.push(part.to_owned())
  }
  guard parts.length() >= 2 else { fail("sympy-call-empty") }
  let module_name = parts[0:parts.length() - 1].join(".")
  let attribute_name = parts[parts.length() - 1]
  let module_obj = builder.import_module(module_name)
  let printer = builder.getattr(module_obj, attribute_name)
  let result = builder.call(printer, [Ref(expression)])
  let result = builder.require_non_none(
    result,
    message="sympy-call-none:\{path}",
  )
  builder.request_str(result)
}
