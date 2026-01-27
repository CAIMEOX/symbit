///|
/// Convert a MoonBit `Expr` into a live SymPy object by calling
/// `sympy.sympify` on the stable human printer from `symprint`.
/// This keeps the conversion logic small while relying on SymPy's
/// parser for canonical construction (and avoids reproducing its
/// dispatch rules in MoonBit).
pub fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise PolyError {
  guard @py.pyimport("sympy") is Some(sympy) else {
    raise PolyError::NotImplemented("sympy-missing")
  }
  guard sympy.get_attr("sympify") is Some(PyCallable(sympify)) else {
    raise PolyError::NotImplemented("sympy-sympify-missing")
  }
  let args = @py.PyTuple::new(1)
  // The printer already applies a deterministic parenthesisation and
  // uses '^' for powers; SymPy's `sympify` accepts that form.
  let rendered = @symprint.to_string(expr)
  args.set(0, @py.PyString::from(rendered))
  let res = sympify.invoke(args~).unwrap() catch {
      _e => raise PolyError::NotImplemented("sympy-sympify-failed")
    }
  @qc_pyext.PyObjectInto::to_py_object(res)
}
