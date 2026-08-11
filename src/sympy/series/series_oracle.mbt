///|
/// Oracle helpers for SymPy series.

///|
fn call_required(
  builder : @recipe.Builder,
  callable : @recipe.ValueRef,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  message? : String = "sympy-call-none",
) -> @recipe.ValueRef raise {
  builder.require_non_none(builder.call(callable, args, kwargs~), message~)
}

///|
priv struct SeriesRecipe {
  builder : @recipe.Builder
  expressions : @exprcodec.Encoder
  sympy : @recipe.ValueRef
}

///|
fn SeriesRecipe::new(builder : @recipe.Builder) -> SeriesRecipe raise {
  {
    builder,
    expressions: @exprcodec.Encoder::new(builder),
    sympy: builder.import_module("sympy"),
  }
}

///|
fn SeriesRecipe::symbol(
  self : SeriesRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let symbol = self.builder.getattr(self.sympy, "Symbol")
  call_required(
    self.builder,
    symbol,
    [Str(name)],
    message="sympy-call-none:sympy.Symbol",
  )
}

///|
fn SeriesRecipe::call(
  self : SeriesRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(self.sympy, name)
  call_required(
    self.builder,
    callable,
    args,
    message="sympy-call-none:sympy.\{name}",
  )
}

///|
fn SeriesRecipe::module_call(
  self : SeriesRecipe,
  module_name : String,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let imported = self.builder.import_module(module_name)
  let callable = self.builder.getattr(imported, name)
  call_required(
    self.builder,
    callable,
    args,
    message="sympy-call-none:\{module_name}.\{name}",
  )
}

///|
fn SeriesRecipe::fps(
  self : SeriesRecipe,
  expression : @symcore.Expr,
  variable_name : String,
  x0 : @symcore.Expr,
) -> @recipe.ValueRef raise {
  self.call("fps", [
    Ref(self.expressions.encode(expression)),
    Ref(self.symbol(variable_name)),
    Ref(self.expressions.encode(x0)),
  ])
}

///|
fn SeriesRecipe::fourier_series(
  self : SeriesRecipe,
  expression : @symcore.Expr,
  variable_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> @recipe.ValueRef raise {
  let limits = self.builder.tuple([
    Ref(self.symbol(variable_name)),
    Ref(self.expressions.encode(a)),
    Ref(self.expressions.encode(b)),
  ])
  self.call("fourier_series", [
    Ref(self.expressions.encode(expression)),
    Ref(limits),
  ])
}

///|
fn SeriesRecipe::request_method_str(
  self : SeriesRecipe,
  object : @recipe.ValueRef,
  method_name : String,
  args : Array[@recipe.RecipeArg],
) -> String raise {
  let callable = self.builder.getattr(object, method_name)
  let value = call_required(
    self.builder,
    callable,
    args,
    message="py-call-none",
  )
  self.builder.request_str(value)
}

///|
pub fn series_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  n : Int,
  dir? : String = "+",
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("series", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(var_name)),
    Ref(recipe.expressions.encode(x0)),
    DecimalInt(n.to_string()),
    Str(dir),
  ])
  builder.request_str(value)
}

///|
pub fn sympy_normalize_str(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("sympify", [Str(expr_str)])
  builder.request_str(value)
}

///|
pub fn sympy_simplify_str(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let expression = recipe.call("sympify", [Str(expr_str)])
  let value = recipe.call("simplify", [Ref(expression)])
  builder.request_str(value)
}

///|
pub fn sympy_equiv_str(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let difference = recipe.call("sympify", [Str("(\{a})- (\{b})")])
  let value = recipe.call("simplify", [Ref(difference)])
  builder.request_str(value) == "0"
}

///|
pub fn limit_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("limit", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(var_name)),
    Ref(recipe.expressions.encode(x0)),
    Str(dir),
  ])
  builder.request_str(value)
}

///|
pub fn fps_truncate_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  n : Int,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  recipe.request_method_str(recipe.fps(expr, var_name, x0), "truncate", [
    DecimalInt(n.to_string()),
  ])
}

///|
pub fn pade_approximant_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  m : Int,
  n? : Int = -1,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let n_arg : @recipe.RecipeArg = if n < 0 {
    Null
  } else {
    DecimalInt(n.to_string())
  }
  let value = recipe.module_call(
    "sympy.series.approximants",
    "pade_approximant",
    [
      Ref(recipe.expressions.encode(expr)),
      Ref(recipe.symbol(var_name)),
      Ref(recipe.expressions.encode(x0)),
      DecimalInt(m.to_string()),
      n_arg,
    ],
  )
  builder.request_str(value)
}

///|
pub fn approximants_str(coeffs : Array[Int], var_name : String) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let coefficient_args : Array[@recipe.RecipeArg] = []
  for coefficient in coeffs {
    coefficient_args.push(DecimalInt(coefficient.to_string()))
  }
  let coefficients = builder.list(coefficient_args)
  let generator = recipe.module_call(
    "sympy.series.approximants",
    "approximants",
    [Ref(coefficients), Ref(recipe.symbol(var_name))],
  )
  let builtins = builder.import_module("builtins")
  let list = builder.getattr(builtins, "list")
  let value = call_required(
    builder,
    list,
    [Ref(generator)],
    message="py-call-none",
  )
  builder.request_str(value)
}

///|
pub fn gruntz_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("gruntz", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(var_name)),
    Ref(recipe.expressions.encode(x0)),
    Str(dir),
  ])
  builder.request_str(value)
}

///|
pub fn residue_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("residue", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(var_name)),
    Ref(recipe.expressions.encode(x0)),
  ])
  builder.request_str(value)
}

///|
pub fn richardson_str(
  expr : @symcore.Expr,
  k_name : String,
  n : Int,
  m : Int,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.module_call("sympy.series.acceleration", "richardson", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(k_name)),
    DecimalInt(n.to_string()),
    DecimalInt(m.to_string()),
  ])
  builder.request_str(value)
}

///|
pub fn shanks_str(
  expr : @symcore.Expr,
  k_name : String,
  n : Int,
  m? : Int = 1,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.module_call("sympy.series.acceleration", "shanks", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(k_name)),
    DecimalInt(n.to_string()),
    DecimalInt(m.to_string()),
  ])
  builder.request_str(value)
}

///|
pub fn difference_delta_str(
  expr : @symcore.Expr,
  n_name : String,
  step? : Int = 1,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("difference_delta", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(n_name)),
    DecimalInt(step.to_string()),
  ])
  builder.request_str(value)
}

///|
pub fn limit_seq_str(expr : @symcore.Expr, n_name : String) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let value = recipe.call("limit_seq", [
    Ref(recipe.expressions.encode(expr)),
    Ref(recipe.symbol(n_name)),
  ])
  builder.request_str(value)
}

///|
pub fn fps_coeff_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  n : Int,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  recipe.request_method_str(recipe.fps(expr, var_name, x0), "__getitem__", [
    DecimalInt(n.to_string()),
  ])
}

///|
pub fn fps_slice_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  start : Int,
  stop : Int,
  step? : Int = 1,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  let builtins = builder.import_module("builtins")
  let slice = builder.getattr(builtins, "slice")
  let slice_value = call_required(
    builder,
    slice,
    [
      DecimalInt(start.to_string()),
      DecimalInt(stop.to_string()),
      DecimalInt(step.to_string()),
    ],
    message="py-call-none",
  )
  recipe.request_method_str(recipe.fps(expr, var_name, x0), "__getitem__", [
    Ref(slice_value),
  ])
}

///|
fn fourier_method_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
  method_name : String,
) -> String raise {
  let builder = @recipe.Builder::new()
  let recipe = SeriesRecipe::new(builder)
  recipe.request_method_str(
    recipe.fourier_series(expr, var_name, a, b),
    method_name,
    [DecimalInt(n.to_string())],
  )
}

///|
pub fn fourier_truncate_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
) -> String raise {
  fourier_method_str(expr, var_name, a, b, n, "truncate")
}

///|
pub fn fourier_term_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
) -> String raise {
  fourier_method_str(expr, var_name, a, b, n, "term")
}

///|
pub fn fourier_sigma_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
) -> String raise {
  fourier_method_str(expr, var_name, a, b, n, "sigma_approximation")
}
