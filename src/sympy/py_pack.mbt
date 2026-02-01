///|
fn py_none_obj() -> @py.PyObject {
  @py.PyObject::create(@cpython.py_none())
}

///|
pub fn py_pack(arg : OracleArg) -> @py.PyObject {
  let _ = py_gil_ensure()
  match arg {
    OracleArg::Null => py_none_obj()
    OracleArg::Str(s) => @py.PyString::from(s).obj()
    OracleArg::Int(n) => @py.PyInteger::from(n.to_int64()).obj()
    OracleArg::Bool(b) => @py.PyBool::from(b).obj()
    OracleArg::PyObj(obj) => {
      @cpython.py_incref(obj.obj_ref())
      obj
    }
    OracleArg::StrList(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyString::from(v))
      }
      py_list.obj()
    }
    OracleArg::IntList(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyInteger::from(v.to_int64()))
      }
      py_list.obj()
    }
    OracleArg::List(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyObject::create(py_pack(v).obj_ref()))
      }
      py_list.obj()
    }
    OracleArg::Dict(map) => {
      let py_dict = @py.PyDict::new()
      for k, v in map {
        py_dict.set(k, py_pack(v))
      }
      py_dict.obj()
    }
  }
}

///|
pub fn py_pack_args(args : Array[OracleArg]) -> @py.PyTuple {
  let _ = py_gil_ensure()
  let tup = @py.PyTuple::new(args.length().to_uint64())
  for i in 0..<args.length() {
    tup.set(i, py_pack(args[i]))
  }
  tup
}

///|
pub fn py_pack_kwargs(kwargs : Map[String, OracleArg]) -> @py.PyDict {
  let _ = py_gil_ensure()
  let dict = @py.PyDict::new()
  for k, v in kwargs {
    dict.set(k, py_pack(v))
  }
  dict
}

///|
fn resolve_sympy_module_path(module_path : String) -> @py.PyModule raise {
  let full = if module_path == "" || module_path == "sympy" {
    "sympy"
  } else if module_path.has_prefix("sympy.") {
    module_path
  } else {
    "sympy.\{module_path}"
  }
  match @py.pyimport(full) {
    Some(mod) => mod
    None => fail("sympy-missing:\{full}")
  }
}

///|
fn resolve_sympy_callable(path : String) -> @py.PyCallable raise {
  let trimmed = path.trim()
  guard trimmed.length() > 0 else { fail("sympy-call-empty") }
  let parts : Array[String] = Array::new()
  for part in trimmed.split(".") {
    parts.push(part.to_string())
  }
  if parts.length() == 1 {
    let sympy = resolve_sympy_module_path("sympy")
    match sympy.get_attr(parts[0], print_err=true) {
      Some(PyCallable(callable)) => callable
      Some(PyClass(obj)) =>
        @py.PyCallable::create(obj) catch {
          _ => fail("sympy-callable")
        }
      Some(other) =>
        @py.PyCallable::create(objenum_to_obj(other)) catch {
          _ => fail("sympy-callable")
        }
      None => fail("sympy-callable-missing:\{parts[0]}")
    }
  } else {
    let mut module_path = ""
    for i in 0..<(parts.length() - 1) {
      if i > 0 {
        module_path = module_path + "."
      }
      module_path = module_path + parts[i]
    }
    let attr = parts[parts.length() - 1]
    let mod = resolve_sympy_module_path(module_path)
    match mod.get_attr(attr, print_err=true) {
      Some(PyCallable(callable)) => callable
      Some(PyClass(obj)) =>
        @py.PyCallable::create(obj) catch {
          _ => fail("sympy-callable")
        }
      Some(other) =>
        @py.PyCallable::create(objenum_to_obj(other)) catch {
          _ => fail("sympy-callable")
        }
      None => fail("sympy-callable-missing:\{path}")
    }
  }
}

///|
pub fn sympy_call(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum? raise {
  let callable = resolve_sympy_callable(path)
  let py_args = py_pack_args(args)
  let py_kwargs = py_pack_kwargs(kwargs)
  callable.invoke(args=py_args, kwargs=py_kwargs, print_err=true)
}
