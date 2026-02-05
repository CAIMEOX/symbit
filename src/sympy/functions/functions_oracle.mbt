///|
/// Oracle helpers for SymPy functions.

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
  let srepr = sympy_call_must("sympy.srepr", [
    OracleArg::PyObj(objenum_to_obj(expr)),
  ])
  py_str_enum(srepr)
}

///|
pub fn expr_str_eq(a : String, b : String) -> Bool raise {
  sympy_srepr(a) == sympy_srepr(b)
}
