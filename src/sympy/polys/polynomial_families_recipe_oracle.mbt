///|
fn polynomial_families_recipe_source() -> String {
  (
    #|def _symbit_polynomial_family_scalar(value):
    #|    if isinstance(value, sympy.Poly):
    #|        value = value.as_expr()
    #|    return str(value)
    #|
    #|def _symbit_polynomial_family_sequence(value):
    #|    if not isinstance(value, (list, tuple)):
    #|        raise ValueError("polynomial-family-sequence-shape")
    #|    return [_symbit_polynomial_family_scalar(item) for item in value]
  )
}

///|
priv struct PolynomialFamiliesRecipe {
  polys : PolysRecipe
  scalar_renderer : @recipe.ValueRef
  sequence_renderer : @recipe.ValueRef
}

///|
fn PolynomialFamiliesRecipe::new() -> PolynomialFamiliesRecipe raise {
  let polys = PolysRecipe::new()
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    polynomial_families_recipe_source(),
  )
  {
    polys,
    scalar_renderer: polys.builder.getitem(
      scope,
      Str("_symbit_polynomial_family_scalar"),
    ),
    sequence_renderer: polys.builder.getitem(
      scope,
      Str("_symbit_polynomial_family_sequence"),
    ),
  }
}

///|
fn PolynomialFamiliesRecipe::strict_call(
  self : PolynomialFamiliesRecipe,
  callable : @recipe.ValueRef,
  args : Array[@recipe.RecipeArg],
  message : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.require_non_none(
    self.polys.builder.call(callable, args),
    message~,
  )
}

///|
fn PolynomialFamiliesRecipe::call_path(
  self : PolynomialFamiliesRecipe,
  path : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  self.polys.call(path, args)
}

///|
fn PolynomialFamiliesRecipe::named_unary(
  self : PolynomialFamiliesRecipe,
  path : String,
  n : Int,
  x : String,
) -> @recipe.ValueRef raise {
  let symbol = self.polys.literal_symbol(x)
  self.call_path(path, [DecimalInt(Show::to_string(n)), Ref(symbol)])
}

///|
fn PolynomialFamiliesRecipe::exact_number(
  self : PolynomialFamiliesRecipe,
  value : @symnum.BigRational,
) -> @recipe.ValueRef raise {
  if value.is_integral() {
    self.call_path("sympy.Integer", [Str(value.numerator().to_string())])
  } else {
    self.call_path("sympy.Rational", [
      Str(value.numerator().to_string()),
      Str(value.denominator().to_string()),
    ])
  }
}

///|
fn PolynomialFamiliesRecipe::int_list(
  self : PolynomialFamiliesRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.polys.builder.list(items)
}

///|
fn PolynomialFamiliesRecipe::request_scalar(
  self : PolynomialFamiliesRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let result = self.polys.builder.require_non_none(
    result,
    message="sympy-polys-polynomial-family-result-none",
  )
  let rendered = self.strict_call(
    self.scalar_renderer,
    [Ref(result)],
    "sympy-polys-polynomial-family-render-none",
  )
  self.polys.builder.request_str(rendered)
}

///|
fn PolynomialFamiliesRecipe::request_sequence(
  self : PolynomialFamiliesRecipe,
  result : @recipe.ValueRef,
) -> Array[String] raise {
  let rendered = self.strict_call(
    self.sequence_renderer,
    [Ref(result)],
    "sympy-polys-polynomial-family-sequence-none",
  )
  self.polys.request_string_array(rendered)
}

///|
fn polynomial_family_named_unary(
  path : String,
  n : Int,
  x : String,
) -> String raise {
  let recipe = PolynomialFamiliesRecipe::new()
  recipe.request_scalar(recipe.named_unary(path, n, x))
}

///|
fn polynomial_family_int_sequence(
  path : String,
  n : Int,
) -> Array[String] raise {
  let recipe = PolynomialFamiliesRecipe::new()
  let result = recipe.call_path(path, [DecimalInt(Show::to_string(n))])
  recipe.request_sequence(result)
}

///|
fn polynomial_family_sequence(path : String) -> Array[String] raise {
  let recipe = PolynomialFamiliesRecipe::new()
  recipe.request_sequence(recipe.call_path(path, []))
}

///|
pub fn cyclotomic_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary(
    "sympy.polys.specialpolys.cyclotomic_poly", n, x,
  )
}

///|
pub fn swinnerton_dyer_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary(
    "sympy.polys.specialpolys.swinnerton_dyer_poly", n, x,
  )
}

///|
pub fn symmetric_poly(n : Int, gens : Array[String]) -> String raise {
  let recipe = PolynomialFamiliesRecipe::new()
  let args : Array[@recipe.RecipeArg] = [DecimalInt(Show::to_string(n))]
  for symbol in recipe.polys.literal_symbols(gens) {
    args.push(symbol)
  }
  let result = recipe.call_path("sympy.polys.specialpolys.symmetric_poly", args)
  recipe.request_scalar(result)
}

///|
pub fn interpolating_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary(
    "sympy.polys.specialpolys.interpolating_poly", n, x,
  )
}

///|
pub fn interpolating_poly_values(
  n : Int,
  x : String,
  xs : Array[Int],
  ys : Array[Int],
) -> String raise {
  let recipe = PolynomialFamiliesRecipe::new()
  let symbol = recipe.polys.literal_symbol(x)
  let x_values = recipe.int_list(xs)
  let y_values = recipe.int_list(ys)
  let result = recipe.call_path("sympy.polys.specialpolys.interpolating_poly", [
    DecimalInt(Show::to_string(n)),
    Ref(symbol),
    Ref(x_values),
    Ref(y_values),
  ])
  recipe.request_scalar(result)
}

///|
pub fn fateman_poly_F_1(n : Int) -> Array[String] raise {
  polynomial_family_int_sequence("sympy.polys.specialpolys.fateman_poly_F_1", n)
}

///|
pub fn fateman_poly_F_2(n : Int) -> Array[String] raise {
  polynomial_family_int_sequence("sympy.polys.specialpolys.fateman_poly_F_2", n)
}

///|
pub fn fateman_poly_F_3(n : Int) -> Array[String] raise {
  polynomial_family_int_sequence("sympy.polys.specialpolys.fateman_poly_F_3", n)
}

///|
pub fn f_polys() -> Array[String] raise {
  polynomial_family_sequence("sympy.polys.specialpolys.f_polys")
}

///|
pub fn w_polys() -> Array[String] raise {
  polynomial_family_sequence("sympy.polys.specialpolys.w_polys")
}

///|
pub fn chebyshevt_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.orthopolys.chebyshevt_poly", n, x)
}

///|
pub fn chebyshevu_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.orthopolys.chebyshevu_poly", n, x)
}

///|
pub fn hermite_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.orthopolys.hermite_poly", n, x)
}

///|
pub fn hermite_prob_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary(
    "sympy.polys.orthopolys.hermite_prob_poly", n, x,
  )
}

///|
pub fn legendre_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.orthopolys.legendre_poly", n, x)
}

///|
pub fn laguerre_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.orthopolys.laguerre_poly", n, x)
}

///|
pub fn gegenbauer_poly(
  n : Int,
  a : @symnum.BigRational,
  x? : String = "x",
) -> String raise {
  let recipe = PolynomialFamiliesRecipe::new()
  let parameter = recipe.exact_number(a)
  let symbol = recipe.polys.literal_symbol(x)
  let result = recipe.call_path("sympy.polys.orthopolys.gegenbauer_poly", [
    DecimalInt(Show::to_string(n)),
    Ref(parameter),
    Ref(symbol),
  ])
  recipe.request_scalar(result)
}

///|
pub fn spherical_bessel_fn(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary(
    "sympy.polys.orthopolys.spherical_bessel_fn", n, x,
  )
}

///|
pub fn jacobi_poly(
  n : Int,
  a : Int,
  b : Int,
  x? : String = "x",
) -> String raise {
  let recipe = PolynomialFamiliesRecipe::new()
  let symbol = recipe.polys.literal_symbol(x)
  let result = recipe.call_path("sympy.polys.orthopolys.jacobi_poly", [
    DecimalInt(Show::to_string(n)),
    DecimalInt(Show::to_string(a)),
    DecimalInt(Show::to_string(b)),
    Ref(symbol),
  ])
  recipe.request_scalar(result)
}

///|
pub fn bernoulli_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.appellseqs.bernoulli_poly", n, x)
}

///|
pub fn bernoulli_c_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.appellseqs.bernoulli_c_poly", n, x)
}

///|
pub fn genocchi_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.appellseqs.genocchi_poly", n, x)
}

///|
pub fn euler_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.appellseqs.euler_poly", n, x)
}

///|
pub fn andre_poly(n : Int, x? : String = "x") -> String raise {
  polynomial_family_named_unary("sympy.polys.appellseqs.andre_poly", n, x)
}
