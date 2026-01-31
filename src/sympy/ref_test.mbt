///|
fn ref_check_existence() -> Unit raise {
  guard @py.pyimport("sympy") is Some(sympy)
  assert_true(sympy.get_attr("poly") is Some(PyCallable(_)))
}

///|
fn py_str_enum(obj : @py.PyObjectEnum) -> String raise {
  guard @py.pyimport("builtins") is Some(builtins) else {
    fail("builtins missing")
  }
  guard builtins.get_attr("str", print_err=false) is Some(PyCallable(str_fn)) else {
    fail("builtins.str missing")
  }
  let args = @py.PyTuple::new(1)
  let target = match obj {
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
  tuple_set_borrowed(args, 0, target)
  match py_call_object(str_fn, args, print_err=true) {
    Some(PyString(s)) => @cpython.py_unicode_as_moonbit_string(s.obj_ref())
    Some(_) => fail("str() did not return PyString")
    None => fail("str() returned None")
  }
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  try! @qc_pyext.py_str(obj)
}

///|
fn ref_symbols_get() -> Unit raise {
  guard @py.pyimport("sympy") is Some(sympy)
  guard sympy.get_attr("symbols") is Some(PyCallable(symbols))
  let args = @py.PyTuple::new(1)
  let pystr = @py.PyString::from("x y z")
  tuple_set_borrowed(args, 0, pystr)
  guard py_call_object(symbols, args) is Some(PyTuple(xyz_tuple))
  guard xyz_tuple.get(0) is Some(PyClass(_))
  guard xyz_tuple.get(1) is Some(PyClass(_))
  guard xyz_tuple.get(2) is Some(PyClass(_))
}

///|
fn ref_expr_to_sympy_add_mul() -> Unit raise {
  let expr = @symcore.add([
    @symcore.mul([@symcore.int(2), @symcore.symbol("x")]),
    @symcore.symbol("y"),
  ])
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="2*x + y")
}

///|
fn ref_expr_to_sympy_pow() -> Unit raise {
  let expr = @symcore.pow(@symcore.symbol("x"), @symcore.int(3))
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="x**3")
}

///|
fn ref_expr_to_sympy_rational() -> Unit raise {
  let expr = @symcore.rational_from_ints(1, 3)
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="1/3")
}

///|
fn ref_expr_to_sympy_function_call() -> Unit raise {
  let expr = @symcore.function("sin", [@symcore.symbol("x")])
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="sin(x)")
}

///|
fn ref_symbol_add_interpretation() -> Unit raise {
  guard @py.pyimport("sympy") is Some(sympy)
  guard sympy.get_attr("sympify") is Some(PyCallable(sympify))
  let args = @py.PyTuple::new(1)
  let pystr = @py.PyString::from("z*(x + y)")
  tuple_set_borrowed(args, 0, pystr)
  guard py_call_object(sympify, args) is Some(PyClass(expr))
  inspect(py_str_obj(expr), content="z*(x + y)")
}
