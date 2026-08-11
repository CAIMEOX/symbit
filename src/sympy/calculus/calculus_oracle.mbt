///|
/// Request-scoped oracle helpers for SymPy calculus.

///|
fn required_call(
  builder : @recipe.Builder,
  callable : @recipe.ValueRef,
  arguments : Array[@recipe.RecipeArg],
  message : String,
) -> @recipe.ValueRef raise {
  builder.require_non_none(builder.call(callable, arguments), message~)
}

///|
fn sympy_callable(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  name : String,
) -> @recipe.ValueRef raise {
  builder.getattr(sympy, name)
}

///|
fn module_callable(
  builder : @recipe.Builder,
  module_name : String,
  name : String,
) -> @recipe.ValueRef raise {
  let module_value = builder.import_module(module_name)
  builder.getattr(module_value, name)
}

///|
fn encode_expr_list(
  builder : @recipe.Builder,
  encoder : @exprcodec.Encoder,
  values : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(Ref(encoder.encode(value)))
  }
  builder.list(items)
}

///|
fn encode_rational(
  encoder : @exprcodec.Encoder,
  value : @symnum.BigRational,
) -> @recipe.ValueRef raise {
  encoder.encode(Number(value))
}

///|
fn encode_rational_list(
  builder : @recipe.Builder,
  encoder : @exprcodec.Encoder,
  values : Array[@symnum.BigRational],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(Ref(encode_rational(encoder, value)))
  }
  builder.list(items)
}

///|
fn accum_bounds_value(
  builder : @recipe.Builder,
  encoder : @exprcodec.Encoder,
  sympy : @recipe.ValueRef,
  minimum : @symcore.Expr,
  maximum : @symcore.Expr,
) -> @recipe.ValueRef raise {
  required_call(
    builder,
    sympy_callable(builder, sympy, "AccumBounds"),
    [Ref(encoder.encode(minimum)), Ref(encoder.encode(maximum))],
    "sympy-call-none:sympy.AccumBounds",
  )
}

///|
fn request_string_array(
  builder : @recipe.Builder,
  value : @recipe.ValueRef,
) -> Array[String] raise {
  match builder.request(value, List(Str)) {
    Array(items) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(text) => result.push(text)
          other =>
            fail("expected string array item, received " + other.stringify())
        }
      }
      result
    }
    other => fail("expected string array, received " + other.stringify())
  }
}

///|
pub fn sympy_normalize(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let result = required_call(
    builder,
    sympy_callable(builder, sympy, "sympify"),
    [Str(expr_str)],
    "sympy-call-none:sympy.sympify",
  )
  builder.request_str(result)
}

///|
pub fn accum_add(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let lhs = accum_bounds_value(builder, encoder, sympy, a_min, a_max)
  let rhs = accum_bounds_value(builder, encoder, sympy, b_min, b_max)
  let result = required_call(
    builder,
    sympy_callable(builder, sympy, "Add"),
    [Ref(lhs), Ref(rhs)],
    "sympy-call-none:sympy.Add",
  )
  builder.request_str(result)
}

///|
pub fn accum_sub(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let lhs = accum_bounds_value(builder, encoder, sympy, a_min, a_max)
  let rhs = accum_bounds_value(builder, encoder, sympy, b_min, b_max)
  let negative_rhs = required_call(
    builder,
    sympy_callable(builder, sympy, "Mul"),
    [DecimalInt("-1"), Ref(rhs)],
    "sympy-call-none:sympy.Mul",
  )
  let result = required_call(
    builder,
    sympy_callable(builder, sympy, "Add"),
    [Ref(lhs), Ref(negative_rhs)],
    "sympy-call-none:sympy.Add",
  )
  builder.request_str(result)
}

///|
pub fn accum_mul(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let lhs = accum_bounds_value(builder, encoder, sympy, a_min, a_max)
  let rhs = accum_bounds_value(builder, encoder, sympy, b_min, b_max)
  let result = required_call(
    builder,
    sympy_callable(builder, sympy, "Mul"),
    [Ref(lhs), Ref(rhs)],
    "sympy-call-none:sympy.Mul",
  )
  builder.request_str(result)
}

///|
pub fn accum_div(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let lhs = accum_bounds_value(builder, encoder, sympy, a_min, a_max)
  let rhs = accum_bounds_value(builder, encoder, sympy, b_min, b_max)
  let reciprocal = required_call(
    builder,
    sympy_callable(builder, sympy, "Pow"),
    [Ref(rhs), DecimalInt("-1")],
    "sympy-call-none:sympy.Pow",
  )
  let result = required_call(
    builder,
    sympy_callable(builder, sympy, "Mul"),
    [Ref(lhs), Ref(reciprocal)],
    "sympy-call-none:sympy.Mul",
  )
  builder.request_str(result)
}

///|
pub fn accum_pow(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  exp : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let base = accum_bounds_value(builder, encoder, sympy, a_min, a_max)
  let result = required_call(
    builder,
    sympy_callable(builder, sympy, "Pow"),
    [Ref(base), Ref(encoder.encode(exp))],
    "sympy-call-none:sympy.Pow",
  )
  builder.request_str(result)
}

///|
pub fn accum_abs(min : @symcore.Expr, max : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let bounds = accum_bounds_value(builder, encoder, sympy, min, max)
  let result = required_call(
    builder,
    builder.getattr(bounds, "__abs__"),
    [],
    "sympy-oracle-call-none",
  )
  builder.request_str(result)
}

///|
pub fn accum_delta(min : @symcore.Expr, max : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let bounds = accum_bounds_value(builder, encoder, sympy, min, max)
  builder.request_str(builder.getattr(bounds, "delta"))
}

///|
pub fn accum_mid(min : @symcore.Expr, max : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let bounds = accum_bounds_value(builder, encoder, sympy, min, max)
  builder.request_str(builder.getattr(bounds, "mid"))
}

///|
pub fn finite_diff_weights_str(
  order : Int,
  x_list : Array[@symnum.BigRational],
  x0? : @symnum.BigRational = @symnum.BigRational::zero(),
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let result = required_call(
    builder,
    module_callable(
      builder, "sympy.calculus.finite_diff", "finite_diff_weights",
    ),
    [
      DecimalInt(Show::to_string(order)),
      Ref(encode_rational_list(builder, encoder, x_list)),
      Ref(encode_rational(encoder, x0)),
    ],
    "sympy-call-none:sympy.calculus.finite_diff.finite_diff_weights",
  )
  builder.request_str(result)
}

///|
pub fn apply_finite_diff_str(
  order : Int,
  x_list : Array[@symnum.BigRational],
  y_list : Array[@symcore.Expr],
  x0? : @symnum.BigRational = @symnum.BigRational::zero(),
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let result = required_call(
    builder,
    module_callable(builder, "sympy.calculus.finite_diff", "apply_finite_diff"),
    [
      DecimalInt(Show::to_string(order)),
      Ref(encode_rational_list(builder, encoder, x_list)),
      Ref(encode_expr_list(builder, encoder, y_list)),
      Ref(encode_rational(encoder, x0)),
    ],
    "sympy-call-none:sympy.calculus.finite_diff.apply_finite_diff",
  )
  builder.request_str(result)
}

///|
pub fn euler_equations_str(
  lagrangian : @symcore.Expr,
  funcs : Array[@symcore.Expr],
  vars : Array[@symcore.Expr],
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let result = required_call(
    builder,
    module_callable(builder, "sympy.calculus.euler", "euler_equations"),
    [
      Ref(encoder.encode(lagrangian)),
      Ref(encode_expr_list(builder, encoder, funcs)),
      Ref(encode_expr_list(builder, encoder, vars)),
    ],
    "sympy-call-none:sympy.calculus.euler.euler_equations",
  )
  request_string_array(builder, result)
}

///|
pub fn singularities_str(
  expr : @symcore.Expr,
  symbol : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let result = required_call(
    builder,
    module_callable(builder, "sympy.calculus.singularities", "singularities"),
    [Ref(encoder.encode(expr)), Ref(encoder.encode(symbol))],
    "sympy-call-none:sympy.calculus.singularities.singularities",
  )
  builder.request_str(result)
}

///|
pub fn periodicity_str(
  expr : @symcore.Expr,
  symbol : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let result = builder.call(
    module_callable(builder, "sympy.calculus.util", "periodicity"),
    [Ref(encoder.encode(expr)), Ref(encoder.encode(symbol))],
  )
  builder.request_str(result)
}
