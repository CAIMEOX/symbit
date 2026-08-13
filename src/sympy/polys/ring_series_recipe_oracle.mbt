///|
priv struct RingSeriesRecipe {
  polys : PolysRecipe
  ring_series_module : @recipe.ValueRef
  ring_constructor : @recipe.ValueRef
  qq : @recipe.ValueRef
}

///|
fn RingSeriesRecipe::new() -> RingSeriesRecipe raise {
  let polys = PolysRecipe::new()
  let ring_series_module = polys.builder.import_module(
    "sympy.polys.ring_series",
  )
  let rings = polys.builder.import_module("sympy.polys.rings")
  let ring_constructor = polys.builder.getattr(rings, "ring")
  let domains = polys.builder.import_module("sympy.polys.domains")
  let qq = polys.builder.getattr(domains, "QQ")
  { polys, ring_series_module, ring_constructor, qq }
}

///|
fn RingSeriesRecipe::strict_call(
  self : RingSeriesRecipe,
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
fn RingSeriesRecipe::call(
  self : RingSeriesRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let callable = self.polys.builder.getattr(self.ring_series_module, name)
  self.strict_call(callable, args, "sympy-ring-series-none:" + name)
}

///|
fn RingSeriesRecipe::callable(
  self : RingSeriesRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.getattr(self.ring_series_module, name)
}

///|
fn RingSeriesRecipe::ring(
  self : RingSeriesRecipe,
  names : String,
) -> @recipe.ValueRef raise {
  self.strict_call(
    self.ring_constructor,
    [Str(names), Ref(self.qq)],
    "ring-series-ring-none",
  )
}

///|
fn RingSeriesRecipe::univariate_ring(
  self : RingSeriesRecipe,
) -> (@recipe.ValueRef, @recipe.ValueRef) raise {
  let result = self.ring("x")
  let ring = self.polys.builder.getitem(result, DecimalInt("0"))
  let x = self.polys.builder.getitem(result, DecimalInt("1"))
  (ring, x)
}

///|
fn RingSeriesRecipe::bivariate_ring(
  self : RingSeriesRecipe,
) -> (@recipe.ValueRef, @recipe.ValueRef, @recipe.ValueRef) raise {
  let result = self.ring("x,y")
  let ring = self.polys.builder.getitem(result, DecimalInt("0"))
  let x = self.polys.builder.getitem(result, DecimalInt("1"))
  let y = self.polys.builder.getitem(result, DecimalInt("2"))
  (ring, x, y)
}

///|
fn RingSeriesRecipe::int_list(
  self : RingSeriesRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.polys.builder.list(items)
}

///|
fn RingSeriesRecipe::univariate_poly(
  self : RingSeriesRecipe,
  ring : @recipe.ValueRef,
  coeffs : Array[Int],
) -> @recipe.ValueRef raise {
  let reversed : Array[@recipe.RecipeArg] = []
  for offset in 0..<coeffs.length() {
    let index = coeffs.length() - offset - 1
    reversed.push(DecimalInt(Show::to_string(coeffs[index])))
  }
  let values = self.polys.builder.list(reversed)
  let from_list = self.polys.builder.getattr(ring, "from_list")
  self.strict_call(from_list, [Ref(values)], "ring-series-from-list-none")
}

///|
fn RingSeriesRecipe::bivariate_poly(
  self : RingSeriesRecipe,
  ring : @recipe.ValueRef,
  x : @recipe.ValueRef,
  coeffs : Array[Int],
) -> @recipe.ValueRef raise {
  let ring_call = self.polys.builder.getattr(ring, "__call__")
  let builtins = self.polys.builder.import_module("builtins")
  let pow = self.polys.builder.getattr(builtins, "pow")
  let operator = self.polys.builder.import_module("operator")
  let add = self.polys.builder.getattr(operator, "add")
  let mul = self.polys.builder.getattr(operator, "mul")
  let mut polynomial = self.polys.builder.getattr(ring, "zero")
  for index, coefficient in coeffs {
    if coefficient == 0 {
      continue
    }
    let mut term = self.strict_call(
      ring_call,
      [DecimalInt(Show::to_string(coefficient))],
      "ring-series-coefficient-none",
    )
    if index > 0 {
      let power = self.strict_call(
        pow,
        [Ref(x), DecimalInt(Show::to_string(index))],
        "ring-series-power-none",
      )
      term = self.strict_call(
        mul,
        [Ref(term), Ref(power)],
        "ring-series-term-none",
      )
    }
    polynomial = self.strict_call(
      add,
      [Ref(polynomial), Ref(term)],
      "ring-series-add-none",
    )
  }
  polynomial
}

///|
fn RingSeriesRecipe::request(
  self : RingSeriesRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(result)
}

///|
fn ring_series_unary_prec(
  name : String,
  coeffs : Array[Int],
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call(name, [
    Ref(polynomial),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_mul_ring_series(
  left : Array[Int],
  right : Array[Int],
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let left_poly = recipe.univariate_poly(ring, left)
  let right_poly = recipe.univariate_poly(ring, right)
  let result = recipe.call("rs_mul", [
    Ref(left_poly),
    Ref(right_poly),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_square_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_square", coeffs, prec)
}

///|
pub fn rs_pow_ring_series(
  coeffs : Array[Int],
  n : Int,
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_pow", [
    Ref(polynomial),
    DecimalInt(Show::to_string(n)),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_diff_ring_series(coeffs : Array[Int]) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_diff", [Ref(polynomial), Ref(x)])
  recipe.request(result)
}

///|
pub fn rs_integrate_ring_series(coeffs : Array[Int]) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_integrate", [Ref(polynomial), Ref(x)])
  recipe.request(result)
}

///|
pub fn rs_subs_ring_series(
  coeffs : Array[Int],
  replacement : Array[Int],
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let replacement_poly = recipe.univariate_poly(ring, replacement)
  let rules = recipe.polys.builder.dict([(Ref(x), Ref(replacement_poly))])
  let result = recipe.call("rs_subs", [
    Ref(polynomial),
    Ref(rules),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_series_inversion_ring_series(
  coeffs : Array[Int],
  prec : Int,
) -> String raise {
  ring_series_unary_prec("rs_series_inversion", coeffs, prec)
}

///|
pub fn rs_is_puiseux_ring_series(coeffs : Array[Int]) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_is_puiseux", [Ref(polynomial), Ref(x)])
  recipe.request(result)
}

///|
pub fn rs_nth_root_ring_series(
  coeffs : Array[Int],
  n : Int,
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_nth_root", [
    Ref(polynomial),
    DecimalInt(Show::to_string(n)),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_exp_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_exp", coeffs, prec)
}

///|
pub fn rs_log_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_log", coeffs, prec)
}

///|
pub fn rs_sin_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_sin", coeffs, prec)
}

///|
pub fn rs_cos_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_cos", coeffs, prec)
}

///|
pub fn rs_tan_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_tan", coeffs, prec)
}

///|
pub fn rs_sinh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_sinh", coeffs, prec)
}

///|
pub fn rs_cosh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_cosh", coeffs, prec)
}

///|
pub fn rs_tanh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_tanh", coeffs, prec)
}

///|
pub fn rs_atan_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_atan", coeffs, prec)
}

///|
pub fn rs_atanh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_atanh", coeffs, prec)
}

///|
pub fn rs_asin_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_asin", coeffs, prec)
}

///|
pub fn rs_asinh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_asinh", coeffs, prec)
}

///|
pub fn rs_LambertW_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_LambertW", coeffs, prec)
}

///|
pub fn rs_fun_tan_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_fun", [
    Ref(polynomial),
    Ref(recipe.callable("rs_tan")),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_puiseux_tan_ring_series(
  coeffs : Array[Int],
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_puiseux", [
    Ref(recipe.callable("rs_tan")),
    Ref(polynomial),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_puiseux2_mul_ring_series(
  left : Array[Int],
  right : Array[Int],
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let left_poly = recipe.univariate_poly(ring, left)
  let right_poly = recipe.univariate_poly(ring, right)
  let result = recipe.call("rs_puiseux2", [
    Ref(recipe.callable("rs_mul")),
    Ref(left_poly),
    Ref(right_poly),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_series_expr(
  expr : @symcore.Expr,
  sym : String,
  prec : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let expression = recipe.polys.expr(expr)
  let symbol = recipe.polys.literal_symbol(sym)
  let result = recipe.call("rs_series", [
    Ref(expression),
    Ref(symbol),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn series_pprint_oracle(
  coeffs : Array[Int],
  prec : Int,
  sym? : String = "x",
  ascending? : Bool = true,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let values = recipe.int_list(coeffs)
  let result = recipe.polys.call(
    "sympy.polys.series.base.series_pprint",
    [Ref(values), DecimalInt(Show::to_string(prec))],
    kwargs={ "sym": Str(sym), "ascending": Bool(ascending) },
  )
  recipe.request(result)
}

///|
pub fn rs_hadamard_exp_ring_series(
  coeffs : Array[Int],
  inverse? : Bool = false,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, _) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_hadamard_exp", [Ref(polynomial), Bool(inverse)])
  recipe.request(result)
}

///|
pub fn rs_newton_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("rs_newton", [
    Ref(polynomial),
    Ref(x),
    DecimalInt(Show::to_string(prec)),
  ])
  recipe.request(result)
}

///|
pub fn rs_compose_add_ring_series(
  left : Array[Int],
  right : Array[Int],
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, _) = recipe.univariate_ring()
  let left_poly = recipe.univariate_poly(ring, left)
  let right_poly = recipe.univariate_poly(ring, right)
  let result = recipe.call("rs_compose_add", [Ref(left_poly), Ref(right_poly)])
  recipe.request(result)
}

///|
pub fn rs_series_reversion_ring_series(
  coeffs : Array[Int],
  n : Int,
) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, x, y) = recipe.bivariate_ring()
  let polynomial = recipe.bivariate_poly(ring, x, coeffs)
  let result = recipe.call("rs_series_reversion", [
    Ref(polynomial),
    Ref(x),
    DecimalInt(Show::to_string(n)),
    Ref(y),
  ])
  recipe.request(result)
}

///|
pub fn mul_xin_ring_series(coeffs : Array[Int], n : Int) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, _) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("mul_xin", [
    Ref(polynomial),
    DecimalInt("0"),
    DecimalInt(Show::to_string(n)),
  ])
  recipe.request(result)
}

///|
pub fn pow_xin_ring_series(coeffs : Array[Int], n : Int) -> String raise {
  let recipe = RingSeriesRecipe::new()
  let (ring, _) = recipe.univariate_ring()
  let polynomial = recipe.univariate_poly(ring, coeffs)
  let result = recipe.call("pow_xin", [
    Ref(polynomial),
    DecimalInt("0"),
    DecimalInt(Show::to_string(n)),
  ])
  recipe.request(result)
}
