///|
fn sympy_call_required(
  builder : @recipe.Builder,
  callable : @recipe.ValueRef,
  args : Array[@recipe.RecipeArg],
  message : String,
) -> @recipe.ValueRef raise {
  builder.require_non_none(builder.call(callable, args), message~)
}

///|
fn quaternion_value(
  builder : @recipe.Builder,
  encoder : @exprcodec.Encoder,
  sympy : @recipe.ValueRef,
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> @recipe.ValueRef raise {
  let quaternion = builder.getattr(sympy, "Quaternion")
  sympy_call_required(
    builder,
    quaternion,
    [
      Ref(encoder.encode(a)),
      Ref(encoder.encode(b)),
      Ref(encoder.encode(c)),
      Ref(encoder.encode(d)),
    ],
    "sympy-call-none:sympy.Quaternion",
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
fn quaternion_components(
  builder : @recipe.Builder,
  quaternion : @recipe.ValueRef,
) -> Array[String] raise {
  let components = builder.list([
    Ref(builder.getattr(quaternion, "a")),
    Ref(builder.getattr(quaternion, "b")),
    Ref(builder.getattr(quaternion, "c")),
    Ref(builder.getattr(quaternion, "d")),
  ])
  request_string_array(builder, components)
}

///|
fn quaternion_unary_components(
  method_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = quaternion_value(builder, encoder, sympy, a, b, c, d)
  let callable = builder.getattr(quaternion, method_name)
  let result = sympy_call_required(
    builder,
    callable,
    [],
    "sympy-oracle-call-none",
  )
  quaternion_components(builder, result)
}

///|
fn quaternion_binary_components(
  method_name : String,
  a1 : @symcore.Expr,
  b1 : @symcore.Expr,
  c1 : @symcore.Expr,
  d1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b2 : @symcore.Expr,
  c2 : @symcore.Expr,
  d2 : @symcore.Expr,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let lhs = quaternion_value(builder, encoder, sympy, a1, b1, c1, d1)
  let rhs = quaternion_value(builder, encoder, sympy, a2, b2, c2, d2)
  let callable = builder.getattr(lhs, method_name)
  let result = sympy_call_required(
    builder,
    callable,
    [Ref(rhs)],
    "sympy-oracle-call-none",
  )
  quaternion_components(builder, result)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let difference = sympy_call_required(
    builder,
    sympify,
    [Str("(\{lhs}) - (\{rhs})")],
    "sympy-call-none:sympy.sympify",
  )
  let simplify = builder.getattr(sympy, "simplify")
  let result = sympy_call_required(
    builder,
    simplify,
    [Ref(difference)],
    "sympy-call-none:sympy.simplify",
  )
  builder.request_str(result) == "0"
}

///|
pub fn quat_add(
  a1 : @symcore.Expr,
  b1 : @symcore.Expr,
  c1 : @symcore.Expr,
  d1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b2 : @symcore.Expr,
  c2 : @symcore.Expr,
  d2 : @symcore.Expr,
) -> Array[String] raise {
  quaternion_binary_components("add", a1, b1, c1, d1, a2, b2, c2, d2)
}

///|
pub fn quat_mul(
  a1 : @symcore.Expr,
  b1 : @symcore.Expr,
  c1 : @symcore.Expr,
  d1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b2 : @symcore.Expr,
  c2 : @symcore.Expr,
  d2 : @symcore.Expr,
) -> Array[String] raise {
  quaternion_binary_components("mul", a1, b1, c1, d1, a2, b2, c2, d2)
}

///|
pub fn quat_conjugate(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = quaternion_value(builder, encoder, sympy, a, b, c, d)
  let conjugate = builder.getattr(sympy, "conjugate")
  let result = sympy_call_required(
    builder,
    conjugate,
    [Ref(quaternion)],
    "sympy-call-none:sympy.conjugate",
  )
  quaternion_components(builder, result)
}

///|
pub fn quat_norm(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = quaternion_value(builder, encoder, sympy, a, b, c, d)
  let norm = builder.getattr(quaternion, "norm")
  let result = sympy_call_required(builder, norm, [], "sympy-oracle-call-none")
  builder.request_str(result)
}

///|
pub fn quat_inverse(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  quaternion_unary_components("inverse", a, b, c, d)
}

///|
pub fn quat_pow(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
  p : Int,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = quaternion_value(builder, encoder, sympy, a, b, c, d)
  let pow = builder.getattr(quaternion, "pow")
  let result = sympy_call_required(
    builder,
    pow,
    [DecimalInt(p.to_string())],
    "sympy-oracle-call-none",
  )
  quaternion_components(builder, result)
}

///|
pub fn quat_exp(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  quaternion_unary_components("exp", a, b, c, d)
}

///|
pub fn quat_log(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  quaternion_unary_components("log", a, b, c, d)
}

///|
pub fn quat_from_axis_angle(
  x : @symcore.Expr,
  y : @symcore.Expr,
  z : @symcore.Expr,
  angle : @symcore.Expr,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = builder.getattr(sympy, "Quaternion")
  let from_axis_angle = builder.getattr(quaternion, "from_axis_angle")
  let axis = builder.list([
    Ref(encoder.encode(x)),
    Ref(encoder.encode(y)),
    Ref(encoder.encode(z)),
  ])
  let result = sympy_call_required(
    builder,
    from_axis_angle,
    [Ref(axis), Ref(encoder.encode(angle))],
    "sympy-oracle-call-none",
  )
  quaternion_components(builder, result)
}

///|
pub fn quat_to_axis_angle(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = quaternion_value(builder, encoder, sympy, a, b, c, d)
  let to_axis_angle = builder.getattr(quaternion, "to_axis_angle")
  let result = sympy_call_required(
    builder,
    to_axis_angle,
    [],
    "sympy-oracle-call-none",
  )
  let axis = builder.getitem(result, DecimalInt("0"))
  let values = builder.list([
    Ref(builder.getitem(axis, DecimalInt("0"))),
    Ref(builder.getitem(axis, DecimalInt("1"))),
    Ref(builder.getitem(axis, DecimalInt("2"))),
    Ref(builder.getitem(result, DecimalInt("1"))),
  ])
  request_string_array(builder, values)
}

///|
pub fn quat_to_rotation_matrix(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let quaternion = quaternion_value(builder, encoder, sympy, a, b, c, d)
  let to_rotation_matrix = builder.getattr(quaternion, "to_rotation_matrix")
  let matrix = sympy_call_required(
    builder,
    to_rotation_matrix,
    [],
    "sympy-oracle-call-none",
  )
  let tolist = builder.getattr(matrix, "tolist")
  let rows = sympy_call_required(builder, tolist, [], "sympy-oracle-call-none")
  let builtins = builder.import_module("builtins")
  let sum = builder.getattr(builtins, "sum")
  let empty = builder.list([])
  let flattened = sympy_call_required(
    builder,
    sum,
    [Ref(rows), Ref(empty)],
    "sympy-oracle-call-none",
  )
  request_string_array(builder, flattened)
}
