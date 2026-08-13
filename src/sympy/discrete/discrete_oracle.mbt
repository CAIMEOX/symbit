///|
/// Request-scoped oracle helpers for SymPy discrete algorithms.

///|
fn required_module_call(
  builder : @recipe.Builder,
  module_name : String,
  function_name : String,
  arguments : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let module_value = builder.import_module(module_name)
  let callable = builder.getattr(module_value, function_name)
  builder.require_non_none(
    builder.call(callable, arguments, kwargs~),
    message="sympy-call-none:\{module_name}.\{function_name}",
  )
}

///|
fn encode_expr_list(
  builder : @recipe.Builder,
  encoder : @exprcodec.Encoder,
  values : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for value in values {
    encoded.push(Ref(encoder.encode(value)))
  }
  builder.list(encoded)
}

///|
fn request_expr_list_equiv(
  builder : @recipe.Builder,
  actual : @recipe.ValueRef,
  expected : @recipe.ValueRef,
  dps? : Int,
) -> Bool raise {
  let scope = builder.sympy_scope()
  let comparator = match dps {
    Some(_) =>
      builder.eval(
        scope, "lambda actual, expected, dps: len(actual) == len(expected) and all(str(sympy.Lt(sympy.N(sympy.Abs(sympy.Add(sympy.N(a, dps), sympy.Mul(-1, sympy.N(b, dps)))), dps), sympy.Float('1e' + str(-dps + 2)))) == 'True' for a, b in zip(actual, expected))",
      )
    None =>
      builder.eval(
        scope, "lambda actual, expected: len(actual) == len(expected) and all(str(sympy.simplify(sympy.Add(a, sympy.Mul(-1, b))).equals(sympy.Integer(0))) == 'True' for a, b in zip(actual, expected))",
      )
  }
  let result = match dps {
    Some(value) =>
      builder.call(comparator, [
        Ref(actual),
        Ref(expected),
        DecimalInt(Show::to_string(value)),
      ])
    None => builder.call(comparator, [Ref(actual), Ref(expected)])
  }
  builder.request_bool(result)
}

///|
fn unary_transform_equiv(
  function_name : String,
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  positional_tail? : Array[@recipe.RecipeArg] = [],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  dps? : Int,
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let arguments : Array[@recipe.RecipeArg] = [
    Ref(encode_expr_list(builder, encoder, seq)),
  ]
  arguments.append(positional_tail)
  let expected = required_module_call(
    builder,
    "sympy.discrete.transforms",
    function_name,
    arguments,
    kwargs~,
  )
  let actual = encode_expr_list(builder, encoder, ours)
  match dps {
    Some(value) => request_expr_list_equiv(builder, actual, expected, dps=value)
    None => request_expr_list_equiv(builder, actual, expected)
  }
}

///|
fn binary_convolution_equiv(
  function_name : String,
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  positional_tail? : Array[@recipe.RecipeArg] = [],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  dps? : Int,
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let arguments : Array[@recipe.RecipeArg] = [
    Ref(encode_expr_list(builder, encoder, a)),
    Ref(encode_expr_list(builder, encoder, b)),
  ]
  arguments.append(positional_tail)
  let expected = required_module_call(
    builder,
    "sympy.discrete.convolutions",
    function_name,
    arguments,
    kwargs~,
  )
  let actual = encode_expr_list(builder, encoder, ours)
  match dps {
    Some(value) => request_expr_list_equiv(builder, actual, expected, dps=value)
    None => request_expr_list_equiv(builder, actual, expected)
  }
}

///|
pub fn fft_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  dps? : Int,
) -> Bool raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  match dps {
    Some(value) => kwargs["dps"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  match dps {
    Some(value) => unary_transform_equiv("fft", seq, ours, kwargs~, dps=value)
    None => unary_transform_equiv("fft", seq, ours, kwargs~)
  }
}

///|
pub fn ifft_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  dps? : Int,
) -> Bool raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  match dps {
    Some(value) => kwargs["dps"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  match dps {
    Some(value) => unary_transform_equiv("ifft", seq, ours, kwargs~, dps=value)
    None => unary_transform_equiv("ifft", seq, ours, kwargs~)
  }
}

///|
pub fn ntt_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  prime : Int,
) -> Bool raise {
  unary_transform_equiv("ntt", seq, ours, positional_tail=[
    DecimalInt(Show::to_string(prime)),
  ])
}

///|
pub fn intt_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  prime : Int,
) -> Bool raise {
  unary_transform_equiv("intt", seq, ours, positional_tail=[
    DecimalInt(Show::to_string(prime)),
  ])
}

///|
pub fn fwht_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  unary_transform_equiv("fwht", seq, ours)
}

///|
pub fn ifwht_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  unary_transform_equiv("ifwht", seq, ours)
}

///|
pub fn mobius_transform_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  subset? : Bool = true,
) -> Bool raise {
  unary_transform_equiv("mobius_transform", seq, ours, kwargs={
    "subset": Bool(subset),
  })
}

///|
pub fn inverse_mobius_transform_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  subset? : Bool = true,
) -> Bool raise {
  unary_transform_equiv("inverse_mobius_transform", seq, ours, kwargs={
    "subset": Bool(subset),
  })
}

///|
pub fn convolution_fft_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  dps? : Int,
) -> Bool raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  match dps {
    Some(value) => kwargs["dps"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  match dps {
    Some(value) =>
      binary_convolution_equiv(
        "convolution_fft",
        a,
        b,
        ours,
        kwargs~,
        dps=value,
      )
    None => binary_convolution_equiv("convolution_fft", a, b, ours, kwargs~)
  }
}

///|
pub fn convolution_ntt_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  prime : Int,
) -> Bool raise {
  binary_convolution_equiv("convolution_ntt", a, b, ours, positional_tail=[
    DecimalInt(Show::to_string(prime)),
  ])
}

///|
pub fn convolution_fwht_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  binary_convolution_equiv("convolution_fwht", a, b, ours)
}

///|
pub fn convolution_subset_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  binary_convolution_equiv("convolution_subset", a, b, ours)
}

///|
pub fn covering_product_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  binary_convolution_equiv("covering_product", a, b, ours)
}

///|
pub fn intersecting_product_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  binary_convolution_equiv("intersecting_product", a, b, ours)
}

///|
pub fn convolution_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  cycle? : Int = 0,
  dps? : Int,
  prime? : Int,
  dyadic? : Bool,
  subset? : Bool,
) -> Bool raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if cycle != 0 {
    kwargs["cycle"] = DecimalInt(Show::to_string(cycle))
  }
  match dps {
    Some(value) => kwargs["dps"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  match prime {
    Some(value) => kwargs["prime"] = DecimalInt(Show::to_string(value))
    None => ()
  }
  match dyadic {
    Some(value) => kwargs["dyadic"] = Bool(value)
    None => ()
  }
  match subset {
    Some(value) => kwargs["subset"] = Bool(value)
    None => ()
  }
  match dps {
    Some(value) =>
      binary_convolution_equiv("convolution", a, b, ours, kwargs~, dps=value)
    None => binary_convolution_equiv("convolution", a, b, ours, kwargs~)
  }
}

///|
pub fn convolution_int_equiv(
  a : Array[Int],
  b : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encode_ints = fn(values : Array[Int]) -> @recipe.ValueRef raise {
    let items : Array[@recipe.RecipeArg] = []
    for value in values {
      items.push(DecimalInt(Show::to_string(value)))
    }
    builder.list(items)
  }
  let expected = required_module_call(
    builder,
    "sympy.discrete.convolutions",
    "convolution_int",
    [Ref(encode_ints(a)), Ref(encode_ints(b))],
  )
  let actual = encode_ints(ours)
  let comparator = builder.eval(
    builder.sympy_scope(),
    "lambda actual, expected: actual == expected",
  )
  builder.request_bool(builder.call(comparator, [Ref(actual), Ref(expected)]))
}

///|
pub fn linrec_equiv(
  coeffs : Array[@symcore.Expr],
  init : Array[@symcore.Expr],
  n : Int,
  ours : @symcore.Expr,
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let expected = required_module_call(
    builder,
    "sympy.discrete.recurrences",
    "linrec",
    [
      Ref(encode_expr_list(builder, encoder, coeffs)),
      Ref(encode_expr_list(builder, encoder, init)),
      DecimalInt(Show::to_string(n)),
    ],
  )
  let actual = encoder.encode(ours)
  let comparator = builder.eval(
    builder.sympy_scope(),
    "lambda actual, expected: str(sympy.simplify(sympy.Add(actual, sympy.Mul(-1, expected))).equals(sympy.Integer(0))) == 'True'",
  )
  builder.request_bool(builder.call(comparator, [Ref(actual), Ref(expected)]))
}
