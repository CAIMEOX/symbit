///|
pub fn dimacs_load_str(source : String) -> String raise {
  let builder = @recipe.Builder::new()
  let result = logic_call(builder, "sympy.logic.utilities.dimacs", "load", [
    Str(source),
  ])
  builder.request_str(result)
}
