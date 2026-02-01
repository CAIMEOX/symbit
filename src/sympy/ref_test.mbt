///|
fn py_str_obj(obj : @py.PyObject) -> String {
  try! @qc_pyext.py_str(obj)
}

///|
test "sympy ref: import and poly attr" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  guard sympy.get_attr("poly") is Some(PyCallable(_)) else {
    fail("sympy.poly missing")
  }
}

///|
test "sympy ref: symbols get" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  guard sympy.get_attr("symbols") is Some(PyCallable(symbols)) else {
    fail("sympy.symbols missing")
  }
  let args = @py.PyTuple::new(1)
  let pystr = @py.PyString::from("x y z")
  args.set(0, pystr)
  guard py_call_object(symbols, args) is Some(PyTuple(xyz_tuple)) else {
    fail("expected tuple from symbols")
  }
  guard xyz_tuple.get(0) is Some(PyClass(_)) else { fail("x missing") }
  guard xyz_tuple.get(1) is Some(PyClass(_)) else { fail("y missing") }
  guard xyz_tuple.get(2) is Some(PyClass(_)) else { fail("z missing") }
}

///|
test "sympy ref: expr_to_sympy add/mul" {
  let expr = @symcore.int(2) * @symcore.symbol("x") + @symcore.symbol("y")
  let obj = try! expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="2*x + y")
}

///|
test "sympy ref: expr_to_sympy pow" {
  let expr = @symcore.symbol("x") ^ @symcore.int(3)
  let obj = try! expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="x**3")
}

///|
test "sympy ref: expr_to_sympy rational" {
  let expr = @symcore.rational_from_ints(1, 3)
  let obj = try! expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="1/3")
}

///|
test "sympy ref: expr_to_sympy function call" {
  let expr = @symcore.function("sin", [@symcore.symbol("x")])
  let obj = try! expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="sin(x)")
}

///|
test "sympy ref: sympify string" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  guard sympy.get_attr("sympify") is Some(PyCallable(sympify)) else {
    fail("sympy.sympify missing")
  }
  let args = @py.PyTuple::new(1)
  let pystr = @py.PyString::from("z*(x + y)")
  args.set(0, pystr)
  guard py_call_object(sympify, args) is Some(PyClass(expr)) else {
    fail("expected sympify expr")
  }
  inspect(py_str_obj(expr), content="z*(x + y)")
}
