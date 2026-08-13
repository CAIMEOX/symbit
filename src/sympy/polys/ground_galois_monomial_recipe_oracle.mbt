///|
priv struct P6eRecipe {
  polys : PolysRecipe
}

///|
fn P6eRecipe::new() -> P6eRecipe raise {
  let polys = PolysRecipe::new()
  { polys, }
}

///|
fn P6eRecipe::call(
  self : P6eRecipe,
  path : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  self.polys.call(path, args)
}

///|
fn P6eRecipe::int_list(
  self : P6eRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.polys.builder.list(items)
}

///|
fn P6eRecipe::request_raw(
  self : P6eRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(value)
}

///|
fn P6eRecipe::request_compact(
  self : P6eRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.request_raw(value).replace_all(old=" ", new="")
}

///|
fn P6eRecipe::request_sorted_text(
  self : P6eRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  let parts = self.polys.request_string_array(value)
  parts.sort()
  parts.join(" | ")
}

///|
fn p6e_ground_binary(path : String, a : Int, b : Int) -> String raise {
  let recipe = P6eRecipe::new()
  let result = recipe.call(path, [
    DecimalInt(Show::to_string(a)),
    DecimalInt(Show::to_string(b)),
  ])
  recipe.request_compact(result)
}

///|
fn p6e_python_gcd(a : Int, b : Int) -> String raise {
  p6e_ground_binary("sympy.polys.domains.groundtypes.python_gcd", a, b)
}

///|
fn p6e_python_lcm(a : Int, b : Int) -> String raise {
  p6e_ground_binary("sympy.polys.domains.groundtypes.python_lcm", a, b)
}

///|
fn p6e_python_gcdex(a : Int, b : Int) -> String raise {
  p6e_ground_binary("sympy.polys.domains.groundtypes.python_gcdex", a, b)
}

///|
fn p6e_linear_congruence(a : Int, b : Int, m : Int) -> String raise {
  let recipe = P6eRecipe::new()
  let result = recipe.call("sympy.polys.galoistools.linear_congruence", [
    DecimalInt(Show::to_string(a)),
    DecimalInt(Show::to_string(b)),
    DecimalInt(Show::to_string(m)),
  ])
  recipe.request_compact(result)
}

///|
fn p6e_csolve_prime(f : Array[Int], p : Int, e : Int) -> String raise {
  let recipe = P6eRecipe::new()
  let coefficients = recipe.int_list(f)
  let result = recipe.call("sympy.polys.galoistools.csolve_prime", [
    Ref(coefficients),
    DecimalInt(Show::to_string(p)),
    DecimalInt(Show::to_string(e)),
  ])
  recipe.request_compact(result)
}

///|
fn p6e_itermonomials_total(
  variables : Array[String],
  max_degree : Int,
  min_degree : Int,
) -> String raise {
  let recipe = P6eRecipe::new()
  let symbols = recipe.polys.literal_symbol_list(variables)
  let result = recipe.call("sympy.polys.monomials.itermonomials", [
    Ref(symbols),
    DecimalInt(Show::to_string(max_degree)),
    DecimalInt(Show::to_string(min_degree)),
  ])
  recipe.request_sorted_text(result)
}

///|
fn p6e_itermonomials_bounded(
  variables : Array[String],
  max_degrees : Array[Int],
  min_degrees : Array[Int],
) -> String raise {
  let recipe = P6eRecipe::new()
  let symbols = recipe.polys.literal_symbol_list(variables)
  let maxima = recipe.int_list(max_degrees)
  let minima = recipe.int_list(min_degrees)
  let result = recipe.call("sympy.polys.monomials.itermonomials", [
    Ref(symbols),
    Ref(maxima),
    Ref(minima),
  ])
  recipe.request_sorted_text(result)
}

///|
fn p6e_monomial_ldiv(a : Array[Int], b : Array[Int]) -> String raise {
  let recipe = P6eRecipe::new()
  let left = recipe.int_list(a)
  let right = recipe.int_list(b)
  let result = recipe.call("sympy.polys.monomials.monomial_ldiv", [
    Ref(left),
    Ref(right),
  ])
  recipe.request_raw(result)
}

///|
fn p6e_monomial_deg(a : Array[Int]) -> String raise {
  let recipe = P6eRecipe::new()
  let monomial = recipe.int_list(a)
  let result = recipe.call("sympy.polys.monomials.monomial_deg", [Ref(monomial)])
  recipe.request_raw(result)
}

///|
fn p6e_term_div_zz(
  a_monom : Array[Int],
  a_coeff : Int,
  b_monom : Array[Int],
  b_coeff : Int,
) -> String raise {
  let recipe = P6eRecipe::new()
  let a_term = recipe.polys.builder.tuple([
    Ref(recipe.int_list(a_monom)),
    DecimalInt(Show::to_string(a_coeff)),
  ])
  let b_term = recipe.polys.builder.tuple([
    Ref(recipe.int_list(b_monom)),
    DecimalInt(Show::to_string(b_coeff)),
  ])
  let domains = recipe.polys.builder.import_module("sympy.polys.domains")
  let zz = recipe.polys.builder.getattr(domains, "ZZ")
  let result = recipe.call("sympy.polys.monomials.term_div", [
    Ref(a_term),
    Ref(b_term),
    Ref(zz),
  ])
  recipe.request_raw(result)
}
