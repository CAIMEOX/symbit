///|
/// Oracle helpers for SymPy tensor.

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
fn sympify_value(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  expression : String,
) -> @recipe.ValueRef raise {
  let sympify = builder.getattr(sympy, "sympify")
  call_required(
    builder,
    sympify,
    [Str(expression)],
    message="sympy-call-none:sympy.sympify",
  )
}

///|
fn request_rendered(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  value : @recipe.ValueRef,
  renderer : String,
) -> String raise {
  if renderer == "str" {
    return builder.request_str(value)
  }
  let callable = builder.getattr(sympy, renderer)
  let rendered = call_required(
    builder,
    callable,
    [Ref(value)],
    message="sympy-call-none:sympy.\{renderer}",
  )
  builder.request_str(rendered)
}

///|
pub fn sympy_str(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let value = sympify_value(builder, sympy, expr_str)
  builder.request_str(value)
}

///|
pub fn sympy_srepr(expr_str : String) -> String raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let value = sympify_value(builder, sympy, expr_str)
  request_rendered(builder, sympy, value, "srepr")
}

///|
pub fn expr_str_eq(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let srepr = builder.getattr(sympy, "srepr")
  let lhs = call_required(
    builder,
    srepr,
    [Ref(sympify_value(builder, sympy, a))],
    message="sympy-call-none:sympy.srepr",
  )
  let rhs = call_required(
    builder,
    srepr,
    [Ref(sympify_value(builder, sympy, b))],
    message="sympy-call-none:sympy.srepr",
  )
  let operator = builder.import_module("operator")
  let equal = builder.getattr(operator, "eq")
  let result = call_required(builder, equal, [Ref(lhs), Ref(rhs)])
  builder.request_bool(result)
}

///|
priv struct TensorRecipeEncoder {
  builder : @recipe.Builder
  expressions : @exprcodec.Encoder
  sympy : @recipe.ValueRef
  array_expressions : @recipe.ValueRef
  tensor : @recipe.ValueRef
  type_cache : Map[String, @recipe.ValueRef]
  head_cache : Map[String, @recipe.ValueRef]
}

///|
fn TensorRecipeEncoder::new(
  builder : @recipe.Builder,
) -> TensorRecipeEncoder raise {
  {
    builder,
    expressions: @exprcodec.Encoder::new(builder),
    sympy: builder.import_module("sympy"),
    array_expressions: builder.import_module(
      "sympy.tensor.array.expressions.array_expressions",
    ),
    tensor: builder.import_module("sympy.tensor.tensor"),
    type_cache: Map([]),
    head_cache: Map([]),
  }
}

///|
fn TensorRecipeEncoder::idx(
  self : TensorRecipeEncoder,
  item : @symtensor_indexed.Idx,
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(self.sympy, "Idx")
  match item.upper {
    None =>
      call_required(
        self.builder,
        callable,
        [Str(item.name)],
        message="sympy-call-none:sympy.Idx",
      )
    Some(upper) => {
      let range = if item.lower == @symcore.int(0) {
        self.expressions.encode(upper)
      } else {
        let tuple = self.builder.getattr(self.sympy, "Tuple")
        call_required(
          self.builder,
          tuple,
          [
            Ref(self.expressions.encode(item.lower)),
            Ref(self.expressions.encode(upper)),
          ],
          message="sympy-call-none:sympy.Tuple",
        )
      }
      call_required(
        self.builder,
        callable,
        [Str(item.name), Ref(range)],
        message="sympy-call-none:sympy.Idx",
      )
    }
  }
}

///|
fn TensorRecipeEncoder::index(
  self : TensorRecipeEncoder,
  index : @symtensor_indexed.Index,
) -> @recipe.ValueRef raise {
  match index {
    Expr(expression) => self.expressions.encode(expression)
    Idx(item) => self.idx(item)
  }
}

///|
fn TensorRecipeEncoder::indexed_base(
  self : TensorRecipeEncoder,
  base : @symtensor_indexed.IndexedBase,
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(self.sympy, "IndexedBase")
  match base.shape {
    None =>
      call_required(
        self.builder,
        callable,
        [Str(base.name)],
        message="sympy-call-none:sympy.IndexedBase",
      )
    Some(shape) => {
      let items : Array[@recipe.RecipeArg] = []
      for item in shape {
        items.push(Ref(self.expressions.encode(item)))
      }
      let tuple = self.builder.getattr(self.sympy, "Tuple")
      let shape_value = call_required(
        self.builder,
        tuple,
        items,
        message="sympy-call-none:sympy.Tuple",
      )
      call_required(
        self.builder,
        callable,
        [Str(base.name)],
        kwargs={ "shape": Ref(shape_value) },
        message="sympy-call-none:sympy.IndexedBase",
      )
    }
  }
}

///|
fn TensorRecipeEncoder::indexed(
  self : TensorRecipeEncoder,
  item : @symtensor_indexed.Indexed,
) -> @recipe.ValueRef raise {
  let args : Array[@recipe.RecipeArg] = [Ref(self.indexed_base(item.base))]
  for index in item.indices {
    args.push(Ref(self.index(index)))
  }
  let callable = self.builder.getattr(self.sympy, "Indexed")
  call_required(
    self.builder,
    callable,
    args,
    message="sympy-call-none:sympy.Indexed",
  )
}

///|
fn shape_size(shape : Array[Int]) -> Int {
  let mut size = 1
  for dimension in shape {
    size = size * dimension
  }
  size
}

///|
fn sparse_position(key : String, shape : Array[Int]) -> Int? {
  if shape.is_empty() {
    return if key.is_empty() { Some(0) } else { None }
  }
  let parts = key.split(",").to_array()
  if parts.length() != shape.length() {
    return None
  }
  let mut position = 0
  for i in 0..<shape.length() {
    let coordinate = @string.parse_int(parts[i]) catch { _ => return None }
    if coordinate < 0 || coordinate >= shape[i] {
      return None
    }
    position = position * shape[i] + coordinate
  }
  Some(position)
}

///|
fn ndim_array_parts(
  array : @symtensor_array.NDimArray,
) -> (Array[Int], Array[@symcore.Expr]) {
  match array {
    Dense(dense) => (dense.shape, dense.data)
    Sparse(sparse) => {
      let data : Array[@symcore.Expr] = []
      for _ in 0..<shape_size(sparse.shape) {
        data.push(@symcore.int(0))
      }
      for key, value in sparse.data {
        match sparse_position(key, sparse.shape) {
          Some(position) if position < data.length() => data[position] = value
          _ => ()
        }
      }
      (sparse.shape, data)
    }
  }
}

///|
fn TensorRecipeEncoder::ndim_array(
  self : TensorRecipeEncoder,
  array : @symtensor_array.NDimArray,
) -> @recipe.ValueRef raise {
  let (shape, data) = ndim_array_parts(array)
  let (body, _) = self.ndim_array_body(data, shape, 0, 0)
  let callable = self.builder.getattr(self.sympy, "Array")
  call_required(
    self.builder,
    callable,
    [Ref(body)],
    message="sympy-call-none:sympy.Array",
  )
}

///|
/// Build the same nested value that `NDimArray::to_string` exposed to the old
/// `sympify("Array(...)")` bridge, without converting expressions back into
/// Python source.  Letting `sympy.Array` infer the shape is intentional: once
/// a zero dimension is reached, the legacy representation contains no nested
/// values from which later dimensions could be recovered.
fn TensorRecipeEncoder::ndim_array_body(
  self : TensorRecipeEncoder,
  data : Array[@symcore.Expr],
  shape : Array[Int],
  dimension : Int,
  offset : Int,
) -> (@recipe.ValueRef, Int) raise {
  if dimension == shape.length() {
    return (self.expressions.encode(data[offset]), offset + 1)
  }
  let items : Array[@recipe.RecipeArg] = []
  let mut next_offset = offset
  for _ in 0..<shape[dimension] {
    let (item, following_offset) = self.ndim_array_body(
      data,
      shape,
      dimension + 1,
      next_offset,
    )
    items.push(Ref(item))
    next_offset = following_offset
  }
  (self.builder.list(items), next_offset)
}

///|
fn TensorRecipeEncoder::array_expression(
  self : TensorRecipeEncoder,
  expression : @symtensor_array.ArrayExpr,
) -> @recipe.ValueRef raise {
  match expression {
    Symbol(name, shape) =>
      match shape {
        None => {
          let symbol = self.builder.getattr(self.sympy, "Symbol")
          call_required(
            self.builder,
            symbol,
            [Str(name)],
            message="sympy-call-none:sympy.Symbol",
          )
        }
        Some(items) => {
          let dimensions : Array[@recipe.RecipeArg] = []
          for item in items {
            dimensions.push(Ref(self.expressions.encode(item)))
          }
          let shape_value = self.builder.tuple(dimensions)
          let callable = self.builder.getattr(
            self.array_expressions,
            "ArraySymbol",
          )
          call_required(
            self.builder,
            callable,
            [Str(name), Ref(shape_value)],
            message="sympy-call-none:sympy.tensor.array.ArraySymbol",
          )
        }
      }
    Element(base, indices) => {
      let values : Array[@recipe.RecipeArg] = []
      for index in indices {
        values.push(Ref(self.expressions.encode(index)))
      }
      let index_value = self.builder.tuple(values)
      let callable = self.builder.getattr(
        self.array_expressions,
        "ArrayElement",
      )
      call_required(
        self.builder,
        callable,
        [Ref(self.array_expression(base)), Ref(index_value)],
        message="sympy-call-none:sympy.tensor.array.ArrayElement",
      )
    }
    TensorProduct(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(self.array_expression(item)))
      }
      let callable = self.builder.getattr(
        self.array_expressions,
        "ArrayTensorProduct",
      )
      call_required(
        self.builder,
        callable,
        args,
        message="sympy-call-none:sympy.tensor.array.ArrayTensorProduct",
      )
    }
    Contraction(base, axes) => {
      let args : Array[@recipe.RecipeArg] = [Ref(self.array_expression(base))]
      for axis in axes {
        args.push(
          Ref(
            self.builder.tuple([
              DecimalInt(axis.0.to_string()),
              DecimalInt(axis.1.to_string()),
            ]),
          ),
        )
      }
      let callable = self.builder.getattr(
        self.array_expressions,
        "ArrayContraction",
      )
      call_required(
        self.builder,
        callable,
        args,
        message="sympy-call-none:sympy.tensor.array.ArrayContraction",
      )
    }
    Add(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(self.array_expression(item)))
      }
      let add = self.builder.getattr(self.sympy, "Add")
      call_required(
        self.builder,
        add,
        args,
        message="sympy-call-none:sympy.Add",
      )
    }
    Mul(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(self.array_expression(item)))
      }
      let mul = self.builder.getattr(self.sympy, "Mul")
      call_required(
        self.builder,
        mul,
        args,
        message="sympy-call-none:sympy.Mul",
      )
    }
  }
}

///|
fn TensorRecipeEncoder::tensor_index_type(
  self : TensorRecipeEncoder,
  typ : @symtensor_tensor.TensorIndexType,
) -> @recipe.ValueRef raise {
  match self.type_cache.get(typ.name) {
    Some(value) => value
    None => {
      let kwargs : Map[String, @recipe.RecipeArg] = Map([])
      if typ.dummy_name != "" {
        kwargs["dummy_name"] = Str(typ.dummy_name)
      }
      match typ.dim {
        Some(dimension) =>
          kwargs["dim"] = Ref(self.expressions.encode(dimension))
        None => ()
      }
      let callable = self.builder.getattr(self.tensor, "TensorIndexType")
      let value = call_required(
        self.builder,
        callable,
        [Str(typ.name)],
        kwargs~,
        message="sympy-call-none:sympy.tensor.tensor.TensorIndexType",
      )
      self.type_cache[typ.name] = value
      value
    }
  }
}

///|
fn TensorRecipeEncoder::tensor_index(
  self : TensorRecipeEncoder,
  index : @symtensor_tensor.TensorIndex,
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(self.tensor, "TensorIndex")
  call_required(
    self.builder,
    callable,
    [
      Str(index.name),
      Ref(self.tensor_index_type(index.index_type)),
      Bool(index.is_up),
    ],
    message="sympy-call-none:sympy.tensor.tensor.TensorIndex",
  )
}

///|
fn TensorRecipeEncoder::tensor_head(
  self : TensorRecipeEncoder,
  head : @symtensor_tensor.TensorHead,
) -> @recipe.ValueRef raise {
  match self.head_cache.get(head.name) {
    Some(value) => value
    None => {
      let types : Array[@recipe.RecipeArg] = []
      for typ in head.index_types {
        types.push(Ref(self.tensor_index_type(typ)))
      }
      let type_list = self.builder.list(types)
      let callable = self.builder.getattr(self.tensor, "TensorHead")
      let value = call_required(
        self.builder,
        callable,
        [Str(head.name), Ref(type_list)],
        message="sympy-call-none:sympy.tensor.tensor.TensorHead",
      )
      self.head_cache[head.name] = value
      value
    }
  }
}

///|
fn TensorRecipeEncoder::tensor_expression(
  self : TensorRecipeEncoder,
  expression : @symtensor_tensor.TensorExpr,
) -> @recipe.ValueRef raise {
  match expression {
    Scalar(value) => self.expressions.encode(value)
    Tensor(head, indices) => {
      let args : Array[@recipe.RecipeArg] = []
      for index in indices {
        args.push(Ref(self.tensor_index(index)))
      }
      call_required(
        self.builder,
        self.tensor_head(head),
        args,
        message="py-call-none",
      )
    }
    Add(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(self.tensor_expression(item)))
      }
      let add = self.builder.getattr(self.sympy, "Add")
      call_required(
        self.builder,
        add,
        args,
        message="sympy-call-none:sympy.Add",
      )
    }
    Mul(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(self.tensor_expression(item)))
      }
      let mul = self.builder.getattr(self.sympy, "Mul")
      call_required(
        self.builder,
        mul,
        args,
        message="sympy-call-none:sympy.Mul",
      )
    }
  }
}

///|
fn TensorRecipeEncoder::partial_derivative(
  self : TensorRecipeEncoder,
  derivative : @symtensor_tensor.PartialDerivative,
) -> @recipe.ValueRef raise {
  let args : Array[@recipe.RecipeArg] = [
    Ref(self.tensor_expression(derivative.expr)),
  ]
  for variable in derivative.variables {
    args.push(Ref(self.tensor_expression(variable)))
  }
  let operators = self.builder.import_module("sympy.tensor.toperators")
  let callable = self.builder.getattr(operators, "PartialDerivative")
  call_required(
    self.builder,
    callable,
    args,
    message="sympy-call-none:sympy.tensor.toperators.PartialDerivative",
  )
}

///|
pub fn indexed_str(item : @symtensor_indexed.Indexed) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.indexed(item), "str")
}

///|
pub fn idx_latex(item : @symtensor_indexed.Idx) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.idx(item), "latex")
}

///|
pub fn indexed_base_latex(
  base : @symtensor_indexed.IndexedBase,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.indexed_base(base), "latex")
}

///|
pub fn indexed_latex(item : @symtensor_indexed.Indexed) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.indexed(item), "latex")
}

///|
pub fn indexed_srepr(item : @symtensor_indexed.Indexed) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.indexed(item), "srepr")
}

///|
pub fn array_str(array : @symtensor_array.NDimArray) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.ndim_array(array), "str")
}

///|
pub fn array_latex(array : @symtensor_array.NDimArray) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.ndim_array(array), "latex")
}

///|
pub fn array_srepr(array : @symtensor_array.NDimArray) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(builder, encoder.sympy, encoder.ndim_array(array), "srepr")
}

///|
pub fn array_expr_latex(
  expression : @symtensor_array.ArrayExpr,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(
    builder,
    encoder.sympy,
    encoder.array_expression(expression),
    "latex",
  )
}

///|
pub fn tensor_str(expression : @symtensor_tensor.TensorExpr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(
    builder,
    encoder.sympy,
    encoder.tensor_expression(expression),
    "str",
  )
}

///|
pub fn tensor_latex(expression : @symtensor_tensor.TensorExpr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(
    builder,
    encoder.sympy,
    encoder.tensor_expression(expression),
    "latex",
  )
}

///|
pub fn tensor_srepr(expression : @symtensor_tensor.TensorExpr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(
    builder,
    encoder.sympy,
    encoder.tensor_expression(expression),
    "srepr",
  )
}

///|
pub fn partial_derivative_str(
  derivative : @symtensor_tensor.PartialDerivative,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(
    builder,
    encoder.sympy,
    encoder.partial_derivative(derivative),
    "str",
  )
}

///|
pub fn partial_derivative_latex(
  derivative : @symtensor_tensor.PartialDerivative,
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = TensorRecipeEncoder::new(builder)
  request_rendered(
    builder,
    encoder.sympy,
    encoder.partial_derivative(derivative),
    "latex",
  )
}
