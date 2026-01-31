///|
const ORACLE_PY_PATH : String =
  "/Users/caimeo/code/learning/sym-workspace/symbit/src/sympy"

///|
fn ensure_python() -> Unit {
  if !@cpython.py_is_initialized() {
    @py.init_py()
  }
}

///|
fn add_oracle_to_syspath() -> Unit {
  match @py.pyimport("sys") {
    Some(sys) =>
      match sys.get_attr("path", print_err=false) {
        Some(PyList(path_list)) =>
          path_list.append(@py.PyString::from(ORACLE_PY_PATH))
        _ => ()
      }
    None => ()
  }
}

///|
fn ensure_oracle_module() -> @py.PyModule raise {
  ensure_python()
  add_oracle_to_syspath()
  match @py.pyimport("sympy_oracle") {
    Some(mod) => mod
    None => fail("sympy-oracle-missing")
  }
}

///|
let oracle_lock : Ref[Bool] = { val: false }

///|
fn[T] with_oracle_lock(f : () -> T raise) -> T raise {
  while oracle_lock.val {
    ()
  }
  oracle_lock.val = true
  try f() catch {
    e => {
      oracle_lock.val = false
      raise e
    }
  } noraise {
    v => {
      oracle_lock.val = false
      v
    }
  }
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  match obj {
    PyBool(v) => v.obj()
    PyCallable(v) => v.obj()
    PyClass(v) => v
    PyDict(v) => v.obj()
    PyFloat(v) => v.obj()
    PyInteger(v) => v.obj()
    PyList(v) => v.obj()
    PyModule(v) => v.obj()
    PyString(v) => v.obj()
    PyTuple(v) => v.obj()
  }
}

///|
fn resolve_callable(mod : @py.PyModule, name : String) -> @py.PyCallable raise {
  match mod.get_attr(name, print_err=false) {
    Some(PyCallable(callable)) => callable
    Some(PyClass(obj)) =>
      @py.PyCallable::create(obj) catch { _ => fail("sympy-oracle-callable") }
    Some(other) =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("sympy-oracle-callable")
      }
    None => fail("sympy-oracle-missing:\{name}")
  }
}

///|
///|
fn tuple_set_arg(
  tup : @py.PyTuple,
  idx : Int,
  arg : @sympy.OracleArg,
) -> Unit {
  match arg {
    @sympy.OracleArg::Str(s) =>
      @sympy.tuple_set_borrowed(tup, idx, @py.PyString::from(s))
    @sympy.OracleArg::Int(n) =>
      @sympy.tuple_set_borrowed(
        tup,
        idx,
        @py.PyInteger::from(n.to_int64()),
      )
    @sympy.OracleArg::Bool(b) =>
      @sympy.tuple_set_borrowed(tup, idx, @py.PyBool::from(b))
    @sympy.OracleArg::StrList(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyString::from(v))
      }
      @sympy.tuple_set_borrowed(tup, idx, py_list)
    }
    @sympy.OracleArg::IntList(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyInteger::from(v.to_int64()))
      }
      @sympy.tuple_set_borrowed(tup, idx, py_list)
    }
    @sympy.OracleArg::List(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        let tmp = @py.PyTuple::new(1)
        tuple_set_arg(tmp, 0, v)
        match tmp.get(0) {
          Some(obj) => py_list.append(objenum_to_obj(obj))
          None => ()
        }
      }
      @sympy.tuple_set_borrowed(tup, idx, py_list)
    }
    @sympy.OracleArg::Dict(map) => {
      let py_dict = @sympy.py_dict_from_oracle_args(map)
      @sympy.tuple_set_borrowed(tup, idx, py_dict)
    }
    @sympy.OracleArg::Null =>
      @sympy.tuple_set_borrowed(tup, idx, @py.PyString::from("None"))
  }
}

///|
fn py_tuple_from_args(values : Array[@sympy.OracleArg]) -> @py.PyTuple {
  let tup = @py.PyTuple::new(values.length().to_uint64())
  for i in 0..<values.length() {
    tuple_set_arg(tup, i, values[i])
  }
  tup
}

///|
fn py_obj_to_string(obj : @py.PyObjectEnum) -> String {
  let state = py_gil_ensure()
  match obj {
    PyString(v) => {
      let s = v.to_string()
      py_gil_release(state)
      s
    }
    PyClass(v) => {
      let s = v.to_string()
      py_gil_release(state)
      s
    }
    _ => {
      let s = obj.to_string()
      py_gil_release(state)
      s
    }
  }
}

///|
extern "C" fn py_gil_ensure() -> Int = "PyGILState_Ensure"

///|
extern "C" fn py_gil_release(state : Int) -> Unit = "PyGILState_Release"

///|
fn call_oracle(
  func : String,
  args : Array[@sympy.OracleArg],
  kwargs : Map[String, @sympy.OracleArg],
) -> @py.PyObjectEnum raise {
  with_oracle_lock(fn() raise {
    ensure_python()
    let state = py_gil_ensure()
    let mod = ensure_oracle_module()
    let callable = resolve_callable(mod, func)
    let tup = py_tuple_from_args(args)
    let res =
      if kwargs.is_empty() {
        match @sympy.py_call_object(callable, tup, print_err=true) {
          Some(obj) => obj
          None => {
            py_gil_release(state)
            fail("sympy-oracle-call-none")
          }
        }
      } else {
        let kwargs_dict = @sympy.py_dict_from_oracle_args(kwargs)
        match @sympy.py_call_object_kwargs(
          callable,
          tup,
          kwargs=kwargs_dict,
          print_err=true,
        ) {
          Some(obj) => obj
          None => {
            py_gil_release(state)
            fail("sympy-oracle-call-none")
          }
        }
      }
    py_gil_release(state)
    res
  })
}

///|
fn call_oracle_str(
  func : String,
  args : Array[@sympy.OracleArg],
  kwargs : Map[String, @sympy.OracleArg],
) -> String raise {
  py_obj_to_string(call_oracle(func, args, kwargs))
}

///|
fn build_kwargs_base(
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> Map[String, @sympy.OracleArg] {
  let kwargs : Map[String, @sympy.OracleArg] = {}
  if !gens.is_empty() {
    kwargs["gens"] = @sympy.OracleArg::StrList(gens)
  }
  if domain != "" {
    kwargs["domain"] = @sympy.OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = @sympy.OracleArg::Int(modulus)
  }
  kwargs
}

///|
fn build_kwargs_order(
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  order? : String = "",
) -> Map[String, @sympy.OracleArg] {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  if order != "" {
    kwargs["order"] = @sympy.OracleArg::Str(order)
  }
  kwargs
}

///|
fn build_kwargs_var(
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  var_name? : String = "",
) -> Map[String, @sympy.OracleArg] {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  if var_name != "" {
    kwargs["var"] = @sympy.OracleArg::Str(var_name)
  }
  kwargs
}

///|
pub fn gcd(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  let args = [
    @sympy.OracleArg::Str("gcd"),
    @sympy.OracleArg::Str(p),
    @sympy.OracleArg::Str(q),
  ]
  call_oracle_str("polys_call_json", args, kwargs)
}

///|
pub fn resultant(
  p : String,
  q : String,
  var_name? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let kwargs = build_kwargs_var(
    gens=gens,
    domain=domain,
    modulus=modulus,
    var_name=var_name,
  )
  let args = [
    @sympy.OracleArg::Str("resultant"),
    @sympy.OracleArg::Str(p),
    @sympy.OracleArg::Str(q),
  ]
  call_oracle_str("polys_call_json", args, kwargs)
}

///|
pub fn groebner_list(
  exprs : Array[String],
  gens? : Array[String] = [],
  order? : String = "",
  domain? : String = "",
  modulus? : Int = 0,
) -> Array[String] raise {
  let kwargs = build_kwargs_order(
    gens=gens,
    domain=domain,
    modulus=modulus,
    order=order,
  )
  let args = [
    @sympy.OracleArg::Str("groebner"),
    @sympy.OracleArg::StrList(exprs),
  ]
  let obj = call_oracle("polys_call_json", args, kwargs)
  match obj {
    PyList(list) => {
      let out : Array[String] = Array::make(list.len(), "")
      for i in 0..<list.len() {
        match list.get(i) {
          Some(item) => out.set(i, py_obj_to_string(item))
          None => out.set(i, "")
        }
      }
      out
    }
    _ => fail("expected groebner list")
  }
}

///|
pub fn div_pair_str(
  p : String,
  q : String,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let kwargs = build_kwargs_base(gens=gens, domain=domain, modulus=modulus)
  let args = [
    @sympy.OracleArg::Str("div"),
    @sympy.OracleArg::Str(p),
    @sympy.OracleArg::Str(q),
  ]
  let obj = call_oracle("polys_call_json", args, kwargs)
  match obj {
    PyTuple(items) =>
      if items.len().to_int() == 2 {
        let a = match items.get(0) {
          Some(v) => py_obj_to_string(v)
          None => ""
        }
        let b = match items.get(1) {
          Some(v) => py_obj_to_string(v)
          None => ""
        }
        "\{a}||\{b}"
      } else {
        fail("expected div result tuple")
      }
    PyList(items) =>
      if items.len() == 2 {
        let a = match items.get(0) {
          Some(v) => py_obj_to_string(v)
          None => ""
        }
        let b = match items.get(1) {
          Some(v) => py_obj_to_string(v)
          None => ""
        }
        "\{a}||\{b}"
      } else {
        fail("expected div result list")
      }
    _ => fail("expected div result")
  }
}

///|
pub fn monic_expr_str(expr : String, modulus? : Int = 0) -> String raise {
  let args =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [
        @sympy.OracleArg::Str(expr),
        @sympy.OracleArg::Int(modulus),
      ]
    }
  @sympy.sympy_oracle_call("monic_expr_str", args)
}

///|
pub fn factor_list_str(expr : String, modulus? : Int = 0) -> String raise {
  let args =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [
        @sympy.OracleArg::Str(expr),
        @sympy.OracleArg::Int(modulus),
      ]
    }
  @sympy.sympy_oracle_call("factor_list_str", args)
}

///|
pub fn sqf_list_str(expr : String, modulus? : Int = 0) -> String raise {
  let args =
    if modulus == 0 {
      [@sympy.OracleArg::Str(expr)]
    } else {
      [
        @sympy.OracleArg::Str(expr),
        @sympy.OracleArg::Int(modulus),
      ]
    }
  @sympy.sympy_oracle_call("sqf_list_str", args)
}

///|
pub fn groebner_str(exprs : Array[String], ord? : String = "lex") -> String raise {
  let args = [
    @sympy.OracleArg::StrList(exprs),
    @sympy.OracleArg::Str(ord),
  ]
  @sympy.sympy_oracle_call("groebner_str", args)
}

///|
pub fn sort_factor_repr(repr_str : String) -> String raise {
  let args = [@sympy.OracleArg::Str(repr_str)]
  @sympy.sympy_oracle_call("sort_factor_repr", args)
}

///|
pub fn sqf_part_str(expr : String) -> String raise {
  let args = [@sympy.OracleArg::Str(expr)]
  @sympy.sympy_oracle_call("sqf_part_str", args)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let args = [
    @sympy.OracleArg::Str(lhs),
    @sympy.OracleArg::Str(rhs),
  ]
  @sympy.sympy_oracle_call("expr_equal", args) == "True"
}

///|
pub fn normalize_spaces(s : String) -> String {
  @sympy.normalize_spaces(s)
}

///|
pub fn sympy_normalize(expr_str : String) -> String raise {
  @sympy.sympy_normalize(expr_str)
}

///|
pub fn canonical_cmp(s : String) -> String {
  @sympy.canonical_cmp(s)
}
