///|
fn py_str_obj(obj : @py.PyObject) -> String raise {
  @qc_pyext.py_str(obj)
}

///|
fn ref_exact_float_expr(num : Int, den : Int, prec? : Int = 90) -> @symcore.Expr {
  let rat = @symnum.BigRational::from_ints(num, den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.float(
    @symcore.Float::from_exact(rat, prec=prec) catch {
      _ => @symcore.Float::from_int(0, prec=prec)
    },
  )
}

///|
fn ref_exact_complex_float_expr(
  real_num : Int,
  real_den : Int,
  imag_num : Int,
  imag_den : Int,
  prec? : Int = 90,
) -> @symcore.Expr {
  let real = @symnum.BigRational::from_ints(real_num, real_den) catch {
    _ => @symnum.BigRational::zero()
  }
  let imag = @symnum.BigRational::from_ints(imag_num, imag_den) catch {
    _ => @symnum.BigRational::zero()
  }
  @symcore.complex_float(
    @symcore.ComplexFloat::from_exact_parts(real, imag, prec=prec),
  )
}

///|
test "sympy ref: import and poly attr" {
  guard @py.pyimport("sympy") is Some(sympy) else { fail("sympy missing") }
  assert_true(sympy.get_attr("poly") is Some(PyCallable(_)))
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
  assert_true(xyz_tuple.get(0) is Some(PyClass(_)))
  assert_true(xyz_tuple.get(1) is Some(PyClass(_)))
  assert_true(xyz_tuple.get(2) is Some(PyClass(_)))
}

///|
test "sympy ref: expr_to_sympy add/mul" {
  let expr = @symcore.int(2) * @symcore.symbol("x") + @symcore.symbol("y")
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="2*x + y")
}

///|
test "sympy ref: expr_to_sympy pow" {
  let expr = @symcore.symbol("x") ^ @symcore.int(3)
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="x**3")
}

///|
test "sympy ref: expr_to_sympy rational" {
  let expr = @symcore.rational_from_ints(1, 3)
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="1/3")
}

///|
test "sympy ref: expr_to_sympy float" {
  let expr = ref_exact_float_expr(1, 2)
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="0.500000000000000")
}

///|
test "sympy ref: expr_to_sympy complex float" {
  let expr = ref_exact_complex_float_expr(1, 2, 3, 4)
  let obj = expr_to_sympy(expr)
  inspect(py_str_obj(obj), content="0.5 + 0.75*I")
}

///|
test "sympy ref: expr_to_sympy function call" {
  let expr = @symcore.function("sin", [@symcore.symbol("x")])
  let obj = expr_to_sympy(expr)
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
