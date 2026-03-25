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
fn sympy_call_must(
  path : String,
  args : Array[@sympy.OracleArg],
  kwargs? : Map[String, @sympy.OracleArg] = {},
) -> @py.PyObjectEnum raise {
  match @sympy.sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
pub fn core_expr_sstr(expr : @symcore.Expr) -> String raise {
  let obj = @sympy.expr_to_sympy(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.sstr", [@sympy.OracleArg::PyObj(obj)]),
    ),
  )
}

///|
pub fn core_expr_srepr(expr : @symcore.Expr) -> String raise {
  let obj = @sympy.expr_to_sympy(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.srepr", [@sympy.OracleArg::PyObj(obj)]),
    ),
  )
}
