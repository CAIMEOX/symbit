///|
fn polys_prefix_recipe_call(
  module_name : String,
  function_name : String,
  args : Array[DenseCallArg],
  domain : String,
  kwargs? : Map[String, DenseCallArg] = {},
  result_kind? : DenseResultKind = DenseResult,
) -> String raise {
  dense_recipe_call(
    "sympy.polys." + module_name + "." + function_name,
    args,
    domain,
    kwargs~,
    result_kind~,
  )
}
