///|
/// Oracle helpers for SymPy tensor.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn sympy_call(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum? raise {
  @sympy.sympy_call(path, args, kwargs~)
}

///|
fn sympy_call_must(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
  match sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
}

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn py_str_enum(obj : @py.PyObjectEnum) -> String {
  py_str_obj(objenum_to_obj(obj))
}

///|
fn sympy_sympify_str(expr_str : String) -> @py.PyObjectEnum raise {
  sympy_call_must("sympy.sympify", [OracleArg::Str(expr_str)])
}

///|
pub fn sympy_str(expr_str : String) -> String raise {
  let expr = sympy_sympify_str(expr_str)
  py_str_enum(expr)
}

///|
pub fn sympy_srepr(expr_str : String) -> String raise {
  let expr = sympy_sympify_str(expr_str)
  let srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(objenum_to_obj(expr))])
  py_str_enum(srepr)
}

///|
pub fn expr_str_eq(a : String, b : String) -> Bool raise {
  sympy_srepr(a) == sympy_srepr(b)
}

///|
fn idx_to_sympy(item : @symtensor_indexed.Idx) -> @py.PyObject raise {
  let name_arg = OracleArg::Str(item.name)
  match item.upper {
    None => objenum_to_obj(sympy_call_must("sympy.Idx", [name_arg]))
    Some(upper) => {
      let lower = item.lower
      if lower == @symcore.int(0) {
        objenum_to_obj(sympy_call_must("sympy.Idx", [
          name_arg,
          OracleArg::PyObj(expr_to_sympy(upper)),
        ]))
      } else {
        let range_tuple = sympy_call_must("sympy.Tuple", [
          OracleArg::PyObj(expr_to_sympy(lower)),
          OracleArg::PyObj(expr_to_sympy(upper)),
        ])
        objenum_to_obj(sympy_call_must("sympy.Idx", [
          name_arg,
          OracleArg::PyObj(objenum_to_obj(range_tuple)),
        ]))
      }
    }
  }
}

///|
fn index_to_sympy(index : @symtensor_indexed.Index) -> @py.PyObject raise {
  match index {
    @symtensor_indexed.Index::Expr(expr) => expr_to_sympy(expr)
    @symtensor_indexed.Index::Idx(item) => idx_to_sympy(item)
  }
}

///|
fn indexed_base_to_sympy(base : @symtensor_indexed.IndexedBase) -> @py.PyObject raise {
  let name_arg = OracleArg::Str(base.name)
  match base.shape {
    None => objenum_to_obj(sympy_call_must("sympy.IndexedBase", [name_arg]))
    Some(shape) => {
      let shape_items : Array[OracleArg] = Array::new()
      for item in shape {
        shape_items.push(OracleArg::PyObj(expr_to_sympy(item)))
      }
      let shape_tuple = sympy_call_must("sympy.Tuple", shape_items)
      let kwargs : Map[String, OracleArg] = { "shape": OracleArg::PyObj(objenum_to_obj(shape_tuple)) }
      objenum_to_obj(sympy_call_must("sympy.IndexedBase", [name_arg], kwargs~))
    }
  }
}

///|
fn indexed_to_sympy(item : @symtensor_indexed.Indexed) -> @py.PyObject raise {
  let base_obj = indexed_base_to_sympy(item.base)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(base_obj))
  for idx in item.indices {
    args.push(OracleArg::PyObj(index_to_sympy(idx)))
  }
  objenum_to_obj(sympy_call_must("sympy.Indexed", args))
}

///|
pub fn indexed_str(item : @symtensor_indexed.Indexed) -> String raise {
  py_str_obj(indexed_to_sympy(item))
}

///|
pub fn indexed_srepr(item : @symtensor_indexed.Indexed) -> String raise {
  let obj = indexed_to_sympy(item)
  let srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(obj)])
  py_str_enum(srepr)
}

///|
fn array_to_sympy(arr : @symtensor_array.NDimArray) -> @py.PyObject raise {
  let body = @symtensor_array.to_string(arr)
  let expr = sympy_sympify_str("Array(" + body + ")")
  objenum_to_obj(expr)
}

///|
pub fn array_str(arr : @symtensor_array.NDimArray) -> String raise {
  py_str_obj(array_to_sympy(arr))
}

///|
pub fn array_srepr(arr : @symtensor_array.NDimArray) -> String raise {
  let obj = array_to_sympy(arr)
  let srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(obj)])
  py_str_enum(srepr)
}

///|
fn call_obj(obj : @py.PyObject, args : Array[@py.PyObject]) -> @py.PyObject raise {
  let callable = @py.PyCallable::create(obj) catch {
    _ => fail("py-callable-create")
  }
  let tup = @sympy.py_tuple_from_objects(args)
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(res) => objenum_to_obj(res)
    None => fail("py-call-none")
  }
}

///|
fn tensor_index_type_to_sympy(
  typ : @symtensor_tensor.TensorIndexType,
  cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  if cache.contains(typ.name) {
    return cache[typ.name]
  }
  let args : Array[OracleArg] = [OracleArg::Str(typ.name)]
  let kwargs : Map[String, OracleArg] = {}
  if typ.dummy_name != "" {
    kwargs["dummy_name"] = OracleArg::Str(typ.dummy_name)
  }
  match typ.dim {
    Some(d) => kwargs["dim"] = OracleArg::PyObj(expr_to_sympy(d))
    None => ()
  }
  let obj = objenum_to_obj(sympy_call_must("sympy.tensor.tensor.TensorIndexType", args, kwargs~))
  cache[typ.name] = obj
  obj
}

///|
fn tensor_index_to_sympy(
  index : @symtensor_tensor.TensorIndex,
  type_cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  let typ_obj = tensor_index_type_to_sympy(index.index_type, type_cache)
  let args : Array[OracleArg] = [
    OracleArg::Str(index.name),
    OracleArg::PyObj(typ_obj),
    OracleArg::Bool(index.is_up),
  ]
  objenum_to_obj(sympy_call_must("sympy.tensor.tensor.TensorIndex", args))
}

///|
fn tensor_head_to_sympy(
  head : @symtensor_tensor.TensorHead,
  type_cache : Map[String, @py.PyObject],
  head_cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  if head_cache.contains(head.name) {
    return head_cache[head.name]
  }
  let type_args : Array[OracleArg] = Array::new()
  for typ in head.index_types {
    let obj = tensor_index_type_to_sympy(typ, type_cache)
    type_args.push(OracleArg::PyObj(obj))
  }
  let args : Array[OracleArg] = [
    OracleArg::Str(head.name),
    OracleArg::List(type_args),
  ]
  let obj = objenum_to_obj(sympy_call_must("sympy.tensor.tensor.TensorHead", args))
  head_cache[head.name] = obj
  obj
}

///|
fn tensor_expr_to_sympy(
  expr : @symtensor_tensor.TensorExpr,
  type_cache : Map[String, @py.PyObject],
  head_cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  match expr {
    @symtensor_tensor.TensorExpr::Scalar(e) => expr_to_sympy(e)
    @symtensor_tensor.TensorExpr::Tensor(head, indices) => {
      let head_obj = tensor_head_to_sympy(head, type_cache, head_cache)
      let args : Array[@py.PyObject] = Array::new()
      for idx in indices {
        args.push(tensor_index_to_sympy(idx, type_cache))
      }
      call_obj(head_obj, args)
    }
    @symtensor_tensor.TensorExpr::Add(items) => {
      let args : Array[OracleArg] = Array::new()
      for item in items {
        let obj = tensor_expr_to_sympy(item, type_cache, head_cache)
        args.push(OracleArg::PyObj(obj))
      }
      objenum_to_obj(sympy_call_must("sympy.Add", args))
    }
    @symtensor_tensor.TensorExpr::Mul(items) => {
      let args : Array[OracleArg] = Array::new()
      for item in items {
        let obj = tensor_expr_to_sympy(item, type_cache, head_cache)
        args.push(OracleArg::PyObj(obj))
      }
      objenum_to_obj(sympy_call_must("sympy.Mul", args))
    }
  }
}

///|
pub fn tensor_str(expr : @symtensor_tensor.TensorExpr) -> String raise {
  let type_cache : Map[String, @py.PyObject] = {}
  let head_cache : Map[String, @py.PyObject] = {}
  py_str_obj(tensor_expr_to_sympy(expr, type_cache, head_cache))
}

///|
pub fn tensor_srepr(expr : @symtensor_tensor.TensorExpr) -> String raise {
  let type_cache : Map[String, @py.PyObject] = {}
  let head_cache : Map[String, @py.PyObject] = {}
  let obj = tensor_expr_to_sympy(expr, type_cache, head_cache)
  let srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(obj)])
  py_str_enum(srepr)
}

///|
fn partial_derivative_to_sympy(
  pd : @symtensor_tensor.PartialDerivative,
) -> @py.PyObject raise {
  let type_cache : Map[String, @py.PyObject] = {}
  let head_cache : Map[String, @py.PyObject] = {}
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(tensor_expr_to_sympy(pd.expr, type_cache, head_cache)))
  for v in pd.variables {
    args.push(OracleArg::PyObj(tensor_expr_to_sympy(v, type_cache, head_cache)))
  }
  objenum_to_obj(sympy_call_must("sympy.tensor.toperators.PartialDerivative", args))
}

///|
pub fn partial_derivative_str(pd : @symtensor_tensor.PartialDerivative) -> String raise {
  py_str_obj(partial_derivative_to_sympy(pd))
}
