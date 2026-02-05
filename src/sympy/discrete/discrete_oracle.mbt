///|
/// Oracle helpers for SymPy discrete algorithms.

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
fn py_list_from_objects(values : Array[@py.PyObject]) -> @py.PyList {
  let state = py_gil_ensure()
  let list = @py.PyList::new()
  for v in values {
    list.append(v)
  }
  py_gil_release(state)
  list
}

///|
fn py_list_to_pyobjects(value : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let state = py_gil_ensure()
  let res = try {
    let out : Array[@py.PyObject] = Array::new()
    match value {
      PyList(list) => {
        let len = list.len()
        for i in 0..<len {
          match list.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      PyTuple(tup) => {
        let len = tup.len().to_int()
        for i in 0..<len {
          match tup.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      _ => fail("expected list/tuple")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn resolve_method_callable(
  obj : @py.PyObject,
  name : String,
) -> @py.PyCallable raise {
  let state = py_gil_ensure()
  let res = try {
    match obj.get_attr(name, print_err=false) {
      Some(PyCallable(callable)) => callable
      Some(PyClass(obj0)) =>
        @py.PyCallable::create(obj0) catch {
          _ => fail("py-callable")
        }
      Some(other) =>
        @py.PyCallable::create(objenum_to_obj(other)) catch {
          _ => fail("py-callable")
        }
      None => fail("py-callable-missing")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("py-call-none")
  }
}

///|
fn sympy_call_obj(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObject raise {
  objenum_to_obj(sympy_call_must(path, args, kwargs~))
}

///|
fn sympy_sub_obj(a : @py.PyObject, b : @py.PyObject) -> @py.PyObject raise {
  let neg = sympy_call_obj("sympy.Mul", [
    OracleArg::Int(-1),
    OracleArg::PyObj(b),
  ])
  sympy_call_obj("sympy.Add", [OracleArg::PyObj(a), OracleArg::PyObj(neg)])
}

///|
fn sympy_is_zero(obj : @py.PyObject) -> Bool raise {
  let simp = sympy_call_obj("sympy.simplify", [OracleArg::PyObj(obj)])
  let eq = resolve_method_callable(simp, "equals")
  let zero = sympy_call_obj("sympy.Integer", [OracleArg::Str("0")])
  let res = py_call_with_args(eq, [OracleArg::PyObj(zero)])
  py_str_enum(res) == "True"
}

///|
fn sympy_is_zero_tol(obj : @py.PyObject, dps : Int) -> Bool raise {
  let abs_obj = sympy_call_obj("sympy.Abs", [OracleArg::PyObj(obj)])
  let abs_eval = sympy_call_obj("sympy.N", [
    OracleArg::PyObj(abs_obj),
    OracleArg::Int(dps),
  ])
  let exp = -dps + 2
  let thresh_str = "1e\{exp}"
  let thresh = sympy_call_obj("sympy.Float", [OracleArg::Str(thresh_str)])
  let lt = sympy_call_obj("sympy.Lt", [
    OracleArg::PyObj(abs_eval),
    OracleArg::PyObj(thresh),
  ])
  py_str_obj(lt) == "True"
}

///|
fn expr_equiv_pyobj(
  expr : @symcore.Expr,
  other : @py.PyObject,
  dps? : Int,
) -> Bool raise {
  match dps {
    Some(v) => {
      let a_obj = expr_to_sympy(expr)
      let a_eval = sympy_call_obj("sympy.N", [
        OracleArg::PyObj(a_obj),
        OracleArg::Int(v),
      ])
      let b_eval = sympy_call_obj("sympy.N", [
        OracleArg::PyObj(other),
        OracleArg::Int(v),
      ])
      let diff = sympy_sub_obj(a_eval, b_eval)
      sympy_is_zero_tol(diff, v)
    }
    None => {
      let a_obj = expr_to_sympy(expr)
      let diff = sympy_sub_obj(a_obj, other)
      sympy_is_zero(diff)
    }
  }
}

///|
fn list_equiv(
  ours : Array[@symcore.Expr],
  sympy_items : Array[@py.PyObject],
  dps? : Int,
) -> Bool raise {
  if ours.length() != sympy_items.length() {
    return false
  }
  match dps {
    Some(v) =>
      for i in 0..<ours.length() {
        if !expr_equiv_pyobj(ours[i], sympy_items[i], dps=v) {
          return false
        }
      }
    None =>
      for i in 0..<ours.length() {
        if !expr_equiv_pyobj(ours[i], sympy_items[i]) {
          return false
        }
      }
  }
  true
}

///|
fn py_list_from_exprs(exprs : Array[@symcore.Expr]) -> @py.PyList raise {
  let items : Array[@py.PyObject] = Array::new()
  for expr in exprs {
    items.push(expr_to_sympy(expr))
  }
  py_list_from_objects(items)
}

///|
fn sympy_list_call(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> Array[@py.PyObject] raise {
  let res = sympy_call_must(path, args, kwargs~)
  py_list_to_pyobjects(res)
}

///|
pub fn fft_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  dps? : Int,
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [OracleArg::PyObj(list_obj.obj())]
  let kwargs : Map[String, OracleArg] = Map::new()
  match dps {
    Some(v) => kwargs["dps"] = OracleArg::Int(v)
    None => ()
  }
  let items = sympy_list_call("sympy.discrete.transforms.fft", args, kwargs~)
  match dps {
    Some(v) => list_equiv(ours, items, dps=v)
    None => list_equiv(ours, items)
  }
}

///|
pub fn ifft_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  dps? : Int,
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [OracleArg::PyObj(list_obj.obj())]
  let kwargs : Map[String, OracleArg] = Map::new()
  match dps {
    Some(v) => kwargs["dps"] = OracleArg::Int(v)
    None => ()
  }
  let items = sympy_list_call("sympy.discrete.transforms.ifft", args, kwargs~)
  match dps {
    Some(v) => list_equiv(ours, items, dps=v)
    None => list_equiv(ours, items)
  }
}

///|
pub fn ntt_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  prime : Int,
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(list_obj.obj()),
    OracleArg::Int(prime),
  ]
  let items = sympy_list_call("sympy.discrete.transforms.ntt", args)
  list_equiv(ours, items)
}

///|
pub fn intt_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  prime : Int,
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(list_obj.obj()),
    OracleArg::Int(prime),
  ]
  let items = sympy_list_call("sympy.discrete.transforms.intt", args)
  list_equiv(ours, items)
}

///|
pub fn fwht_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [OracleArg::PyObj(list_obj.obj())]
  let items = sympy_list_call("sympy.discrete.transforms.fwht", args)
  list_equiv(ours, items)
}

///|
pub fn ifwht_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [OracleArg::PyObj(list_obj.obj())]
  let items = sympy_list_call("sympy.discrete.transforms.ifwht", args)
  list_equiv(ours, items)
}

///|
pub fn mobius_transform_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  subset? : Bool = true,
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [OracleArg::PyObj(list_obj.obj())]
  let kwargs : Map[String, OracleArg] = Map::new()
  kwargs["subset"] = OracleArg::Bool(subset)
  let items = sympy_list_call(
    "sympy.discrete.transforms.mobius_transform",
    args,
    kwargs~,
  )
  list_equiv(ours, items)
}

///|
pub fn inverse_mobius_transform_equiv(
  seq : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  subset? : Bool = true,
) -> Bool raise {
  let list_obj = py_list_from_exprs(seq)
  let args : Array[OracleArg] = [OracleArg::PyObj(list_obj.obj())]
  let kwargs : Map[String, OracleArg] = Map::new()
  kwargs["subset"] = OracleArg::Bool(subset)
  let items = sympy_list_call(
    "sympy.discrete.transforms.inverse_mobius_transform",
    args,
    kwargs~,
  )
  list_equiv(ours, items)
}

///|
pub fn convolution_fft_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  dps? : Int,
) -> Bool raise {
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
  ]
  let kwargs : Map[String, OracleArg] = Map::new()
  match dps {
    Some(v) => kwargs["dps"] = OracleArg::Int(v)
    None => ()
  }
  let items = sympy_list_call(
    "sympy.discrete.convolutions.convolution_fft",
    args,
    kwargs~,
  )
  match dps {
    Some(v) => list_equiv(ours, items, dps=v)
    None => list_equiv(ours, items)
  }
}

///|
pub fn convolution_ntt_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
  prime : Int,
) -> Bool raise {
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
    OracleArg::Int(prime),
  ]
  let items = sympy_list_call(
    "sympy.discrete.convolutions.convolution_ntt", args,
  )
  list_equiv(ours, items)
}

///|
pub fn convolution_fwht_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
  ]
  let items = sympy_list_call(
    "sympy.discrete.convolutions.convolution_fwht", args,
  )
  list_equiv(ours, items)
}

///|
pub fn convolution_subset_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
  ]
  let items = sympy_list_call(
    "sympy.discrete.convolutions.convolution_subset", args,
  )
  list_equiv(ours, items)
}

///|
pub fn covering_product_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
  ]
  let items = sympy_list_call(
    "sympy.discrete.convolutions.covering_product", args,
  )
  list_equiv(ours, items)
}

///|
pub fn intersecting_product_equiv(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
  ours : Array[@symcore.Expr],
) -> Bool raise {
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
  ]
  let items = sympy_list_call(
    "sympy.discrete.convolutions.intersecting_product", args,
  )
  list_equiv(ours, items)
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
  let a_obj = py_list_from_exprs(a)
  let b_obj = py_list_from_exprs(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(a_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
  ]
  let kwargs : Map[String, OracleArg] = Map::new()
  if cycle != 0 {
    kwargs["cycle"] = OracleArg::Int(cycle)
  }
  match dps {
    Some(v) => kwargs["dps"] = OracleArg::Int(v)
    None => ()
  }
  match prime {
    Some(p) => kwargs["prime"] = OracleArg::Int(p)
    None => ()
  }
  match dyadic {
    Some(v) => kwargs["dyadic"] = OracleArg::Bool(v)
    None => ()
  }
  match subset {
    Some(v) => kwargs["subset"] = OracleArg::Bool(v)
    None => ()
  }
  let items = sympy_list_call(
    "sympy.discrete.convolutions.convolution",
    args,
    kwargs~,
  )
  match dps {
    Some(v) => list_equiv(ours, items, dps=v)
    None => list_equiv(ours, items)
  }
}

///|
pub fn convolution_int_equiv(
  a : Array[Int],
  b : Array[Int],
  ours : Array[Int],
) -> Bool raise {
  let args : Array[OracleArg] = [OracleArg::IntList(a), OracleArg::IntList(b)]
  let items = sympy_list_call(
    "sympy.discrete.convolutions.convolution_int", args,
  )
  let strs : Array[String] = Array::new()
  for item in items {
    strs.push(py_str_obj(item))
  }
  if ours.length() != strs.length() {
    return false
  }
  for i in 0..<ours.length() {
    if strs[i] != ours[i].to_string() {
      return false
    }
  }
  true
}

///|
pub fn linrec_equiv(
  coeffs : Array[@symcore.Expr],
  init : Array[@symcore.Expr],
  n : Int,
  ours : @symcore.Expr,
) -> Bool raise {
  let c_obj = py_list_from_exprs(coeffs)
  let b_obj = py_list_from_exprs(init)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(c_obj.obj()),
    OracleArg::PyObj(b_obj.obj()),
    OracleArg::Int(n),
  ]
  let sympy_obj = sympy_call_obj("sympy.discrete.recurrences.linrec", args)
  expr_equiv_pyobj(ours, sympy_obj)
}
