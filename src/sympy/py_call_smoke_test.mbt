///|
test "py_call smoke: builtins str" {
  guard @py.pyimport("builtins") is Some(builtins) else {
    fail("builtins missing")
  }
  guard builtins.get_attr("str", print_err=false) is Some(PyCallable(str_fn)) else {
    fail("builtins.str missing")
  }
  let args = @py.PyTuple::new(1)
  let pystr = @py.PyString::from("hello")
  args.set(0, pystr)
  let res = py_call_object(str_fn, args, print_err=true)
  inspect(res, content="Some(PyString(hello))")
}

///|
test "py_call smoke: sympy import" {
  guard @py.pyimport("sympy") is Some(_sympy) else { fail("sympy missing") }
}

///|
test "py_call smoke: sympy version" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  guard sympy.get_attr("__version__", print_err=true) is Some(PyString(ver)) else {
    fail("sympy.__version__ missing")
  }
  let ver_str = @py.PyString::to_string(ver)
  assert_true(ver_str.length() > 0)
}

///|
test "py_call smoke: sympy sympify" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  guard sympy.get_attr("sympify", print_err=true) is Some(PyCallable(sympify)) else {
    fail("sympy.sympify missing")
  }
  let args = @py.PyTuple::new(1)
  let pystr = @py.PyString::from("x")
  args.set(0, pystr)
  let res : Result[@py.PyObjectEnum?, @py.PyRuntimeError] = try? sympify.invoke(
    args~,
  )
  match res {
    Ok(Some(_)) => ()
    Ok(None) => fail("sympify returned None")
    Err(_) => fail("sympify raised")
  }
}

///|
test "py_call smoke: sympy constructors" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  guard sympy.get_attr("Symbol", print_err=true) is Some(PyCallable(symbol_fn)) else {
    fail("sympy.Symbol missing")
  }
  guard sympy.get_attr("Pow", print_err=true) is Some(PyCallable(pow_fn)) else {
    fail("sympy.Pow missing")
  }
  guard sympy.get_attr("Add", print_err=true) is Some(PyCallable(add_fn)) else {
    fail("sympy.Add missing")
  }
  let sym_args = @py.PyTuple::new(1)
  sym_args.set(0, @py.PyString::from("x"))
  let x = match symbol_fn.invoke(args=sym_args) {
    Some(PyClass(obj)) => obj
    Some(other) => objenum_to_obj_smoke(other)
    None => fail("Symbol returned None")
  }
  let pow_args = @py.PyTuple::new(2)
  pow_args.set(0, x)
  pow_args.set(1, @py.PyInteger::from(2))
  let x2 = match pow_fn.invoke(args=pow_args, print_err=true) {
    Some(PyClass(obj)) => obj
    Some(other) => objenum_to_obj_smoke(other)
    None => fail("Pow returned None")
  }
  let add_args = @py.PyTuple::new(2)
  add_args.set(0, x2)
  add_args.set(1, @py.PyInteger::from(1))
  let _expr = add_fn.invoke(args=add_args, print_err=true)

}

///|
fn objenum_to_obj_smoke(obj : @py.PyObjectEnum) -> @py.PyObject {
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
