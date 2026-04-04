///|\
/// Oracle helpers for `sympy.utilities` parity tests.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn py_callable_from_enum(obj : @py.PyObjectEnum) -> @py.PyCallable raise {
  match obj {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    _ =>
      @py.PyCallable::create(objenum_to_obj(obj)) catch {
        _ => fail("py-callable")
      }
  }
}

///|
fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object(callable, args, print_err~)
}

///|
pub fn utilities_eval(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let res = try {
    let builtins = match @py.pyimport("builtins") {
      Some(mod) => mod
      None => fail("py-builtins-missing")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let eval_callable = py_callable_from_enum(eval_obj)
    let globals = @py.PyDict::new()
    globals.set("__builtins__", builtins.obj())
    let sympy_mod = match @py.pyimport("sympy") {
      Some(mod) => mod
      None => fail("py-sympy-missing")
    }
    let json_mod = match @py.pyimport("json") {
      Some(mod) => mod.obj()
      None => fail("py-json-missing")
    }
    globals.set("sympy", sympy_mod.obj())
    globals.set("json", json_mod)
    for name in [
      "Eq",
      "Function",
      "I",
      "Integral",
      "Pow",
      "S",
      "Symbol",
      "acos",
      "cos",
      "cosh",
      "exp",
      "log",
      "sin",
      "sinh",
      "sqrt",
    ] {
      match sympy_mod.get_attr(name, print_err=true) {
        Some(obj) => globals.set(name, objenum_to_obj(obj))
        None => fail("py-sympy-attr-missing: " + name)
      }
    }
    let function_ctor = match sympy_mod.get_attr("Function", print_err=true) {
      Some(obj) => py_callable_from_enum(obj)
      None => fail("py-sympy-attr-missing: Function")
    }
    let symbol_ctor = match sympy_mod.get_attr("Symbol", print_err=true) {
      Some(obj) => py_callable_from_enum(obj)
      None => fail("py-sympy-attr-missing: Symbol")
    }
    for name in ["x", "y", "z", "C1", "C2", "C3", "u2", "_a"] {
      let sym_args = @sympy.py_pack_args([OracleArg::Str(name)])
      match py_call_object(symbol_ctor, sym_args, print_err=true) {
        Some(obj) => globals.set(name, objenum_to_obj(obj))
        None => fail("py-symbol-alias-missing: " + name)
      }
    }
    for name in ["f", "g", "h", "u", "X", "Y"] {
      let fn_args = @sympy.py_pack_args([OracleArg::Str(name)])
      match py_call_object(function_ctor, fn_args, print_err=true) {
        Some(obj) => globals.set(name, objenum_to_obj(obj))
        None => fail("py-function-alias-missing: " + name)
      }
    }
    let args = @sympy.py_pack_args([
      OracleArg::Str(expr),
      OracleArg::PyObj(globals.obj()),
      OracleArg::PyObj(globals.obj()),
    ])
    match py_call_object(eval_callable, args, print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-none")
    }
  } catch {
    err => {
      py_gil_release(state)
      raise err
    }
  }
  py_gil_release(state)
  res
}

///|
pub fn utilities_eval_str(expr : String) -> String raise {
  py_str_obj(objenum_to_obj(utilities_eval(expr)))
}

///|
pub fn utilities_eval_repr(expr : String) -> String raise {
  utilities_eval_str("repr(" + expr + ")")
}
