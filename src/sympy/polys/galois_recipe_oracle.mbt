///|
fn galois_recipe_path(name : String) -> String {
  "sympy.polys.galoistools." + name
}

///|
fn galois_recipe_string_call(
  name : String,
  args : Array[DenseCallArg],
  raw? : Bool = false,
) -> String raise {
  let recipe = DenseRecipe::new("ZZ")
  let result = recipe.call(galois_recipe_path(name), args)
  if raw {
    recipe.builder.request_str(result)
  } else {
    recipe.request_dense(result)
  }
}

///|
fn galois_recipe_int_call(
  name : String,
  args : Array[DenseCallArg],
) -> Int raise {
  let recipe = DenseRecipe::new("ZZ")
  let result = recipe.call(galois_recipe_path(name), args)
  parse_domain_int(recipe.builder.request_int(result))
}

///|
fn galois_recipe_bool_call(
  name : String,
  args : Array[DenseCallArg],
) -> Bool raise {
  let recipe = DenseRecipe::new("ZZ")
  let result = recipe.call(galois_recipe_path(name), args)
  recipe.builder.request_bool(result)
}
