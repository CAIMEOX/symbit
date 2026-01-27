///|
test "check existence of sympy" {
  guard @py.pyimport("sympy") is Some(sympy)
  assert_true(sympy.get_attr("poly") is Some(PyCallable(_)))
}

///|
test "symbols get" {
  guard @py.pyimport("sympy") is Some(sympy)
  guard sympy.get_attr("symbols") is Some(PyCallable(symbols))
  let args = @py.PyTuple::new(1)
  args.set(0, @py.PyString::from("x y z"))
  guard symbols.invoke(args~) is Some(PyTuple(xyz_tuple))
  inspect(xyz_tuple.get(0), content="Some(PyClass(x))")
  inspect(xyz_tuple.get(1), content="Some(PyClass(y))")
  inspect(xyz_tuple.get(2), content="Some(PyClass(z))")
}

///|
test "symbol add interpretation" {
  guard @py.pyimport("sympy") is Some(sympy)
  guard sympy.get_attr("symbols") is Some(PyCallable(symbols))
  guard sympy.get_attr("simplify") is Some(PyCallable(simplify))
  let args = @py.PyTuple::new(1)
  args.set(0, @py.PyString::from("x y z"))
  guard symbols.invoke(args~) is Some(PyTuple(xyz_tuple))
  guard xyz_tuple.get(0) is Some(PyClass(x))
  guard xyz_tuple.get(1) is Some(PyClass(y))
  guard xyz_tuple.get(2) is Some(PyClass(z))
  guard x.get_attr("__add__") is Some(PyCallable(add_mtd))
  let add_args = @py.PyTuple::new(1)
  add_args.set(0, y)
  guard add_mtd.invoke(args=add_args) is Some(PyClass(x_plus_y))
  inspect(x_plus_y, content="x + y")
  guard x_plus_y.get_attr("__mul__") is Some(PyCallable(mul_mtd))
  let mul_args = @py.PyTuple::new(1)
  mul_args.set(0, z)
  guard mul_mtd.invoke(args=mul_args) is Some(PyClass(expr))
  inspect(expr, content="z*(x + y)")
  let s_args = @py.PyTuple::new(1)
  s_args.set(0, expr)
  inspect(simplify.invoke(args=s_args), content="Some(PyClass(z*(x + y)))")
}

///|
test "expr_to_sympy add/mul" {
  let expr = @symcore.add([
    @symcore.mul([@symcore.int(2), @symcore.symbol("x")]),
    @symcore.symbol("y"),
  ])
  let obj = expr_to_sympy(expr)
  inspect(obj, content="2*x + y")
}

///|
test "expr_to_sympy pow" {
  let expr = @symcore.pow(@symcore.symbol("x"), @symcore.int(3))
  let obj = expr_to_sympy(expr)
  inspect(obj, content="x**3")
}

///|
test "expr_to_sympy rational" {
  let expr = @symcore.rational_from_ints(1, 3)
  let obj = expr_to_sympy(expr)
  inspect(obj, content="1/3")
}

///|
test "expr_to_sympy function call" {
  let expr = @symcore.function("sin", [@symcore.symbol("x")])
  let obj = expr_to_sympy(expr)
  inspect(obj, content="sin(x)")
}
