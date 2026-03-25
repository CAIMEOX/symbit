///|
/// Convert a MoonBit `Expr` into a live SymPy object by directly
/// constructing SymPy objects (no expression string parsing).
pub fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  match expr {
    @symcore.Expr::Number(n) => sympy_number_obj(n)
    @symcore.Expr::Float(value) => sympy_float_obj(value)
    @symcore.Expr::ComplexFloat(value) => sympy_complex_float_obj(value)
    @symcore.Expr::Symbol(name) => sympy_symbol_or_const_obj(name)
    @symcore.Expr::Boolean(value) => sympy_bool_obj(value)
    @symcore.Expr::Add(args) => sympy_nary_obj("sympy.Add", args, "0")
    @symcore.Expr::Mul(args) => sympy_nary_obj("sympy.Mul", args, "1")
    @symcore.Expr::Pow(base, exp) => {
      let base_obj = expr_to_sympy(base)
      let exp_obj = expr_to_sympy(exp)
      sympy_call_obj("sympy.Pow", [
        OracleArg::PyObj(base_obj),
        OracleArg::PyObj(exp_obj),
      ])
    }
    @symcore.Expr::Tuple(args) => {
      let packed : Array[OracleArg] = []
      for arg in args {
        packed.push(OracleArg::PyObj(expr_to_sympy(arg)))
      }
      sympy_call_obj("sympy.Tuple", packed)
    }
    @symcore.Expr::Relational(op, lhs, rhs) => {
      let path = match op {
        @symcore.RelOp::Eq => "sympy.Eq"
        @symcore.RelOp::Ne => "sympy.Ne"
        @symcore.RelOp::Lt => "sympy.Lt"
        @symcore.RelOp::Le => "sympy.Le"
        @symcore.RelOp::Gt => "sympy.Gt"
        @symcore.RelOp::Ge => "sympy.Ge"
      }
      sympy_call_obj(path, [
        OracleArg::PyObj(expr_to_sympy(lhs)),
        OracleArg::PyObj(expr_to_sympy(rhs)),
      ])
    }
    @symcore.Expr::Derivative(inner, deriv_args) => {
      let packed : Array[OracleArg] = [OracleArg::PyObj(expr_to_sympy(inner))]
      for arg in deriv_args {
        packed.push(OracleArg::PyObj(expr_to_sympy(arg)))
      }
      sympy_call_obj("sympy.Derivative", packed)
    }
    @symcore.Expr::Subs(inner, variable, value) =>
      sympy_call_obj("sympy.Subs", [
        OracleArg::PyObj(expr_to_sympy(inner)),
        OracleArg::PyObj(expr_to_sympy(variable)),
        OracleArg::PyObj(expr_to_sympy(value)),
      ])
    @symcore.Expr::Lambda(vars, body) =>
      sympy_call_obj("sympy.Lambda", [
        OracleArg::PyObj(expr_to_sympy(vars)),
        OracleArg::PyObj(expr_to_sympy(body)),
      ])
    @symcore.Expr::Function(name, args) => sympy_function_obj(name, args)
  }
}

///|
fn ensure_sympy_module() -> @py.PyModule raise {
  match @py.pyimport("sympy") {
    Some(sympy) => sympy
    None => fail("sympy-missing")
  }
}

///|
fn sympy_call_obj(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObject raise {
  match sympy_call(path, args, kwargs~) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-call-none:\{path}")
  }
}

///|
pub fn sympy_number_obj(n : @symnum.BigRational) -> @py.PyObject raise {
  if n.is_integral() {
    let num_str = n.numerator().to_string()
    sympy_call_obj("sympy.Integer", [OracleArg::Str(num_str)])
  } else {
    let num_str = n.numerator().to_string()
    let den_str = n.denominator().to_string()
    sympy_call_obj("sympy.Rational", [
      OracleArg::Str(num_str),
      OracleArg::Str(den_str),
    ])
  }
}

///|
fn sympy_float_obj(value : @symcore.Float) -> @py.PyObject raise {
  sympy_call_obj("sympy.Float", [OracleArg::Str(value.format())])
}

///|
fn sympy_bool_obj(value : Bool) -> @py.PyObject raise {
  if value {
    sympy_call_obj("sympy.sympify", [OracleArg::Str("True")])
  } else {
    sympy_call_obj("sympy.sympify", [OracleArg::Str("False")])
  }
}

///|
fn sympy_complex_float_obj(value : @symcore.ComplexFloat) -> @py.PyObject raise {
  let real = sympy_float_obj(value.real_part())
  let imag = sympy_float_obj(value.imag_part())
  let imag_term = sympy_call_obj("sympy.Mul", [
    OracleArg::PyObj(imag),
    OracleArg::PyObj(sympy_symbol_or_const_obj("I")),
  ])
  if @symnum.is_zero(value.to_mpc().imag) {
    real
  } else if @symnum.is_zero(value.to_mpc().real) {
    imag_term
  } else {
    sympy_call_obj("sympy.Add", [
      OracleArg::PyObj(real),
      OracleArg::PyObj(imag_term),
    ])
  }
}

///|
fn sympy_constant_obj(name : String) -> @py.PyObject? {
  let sympy = try? ensure_sympy_module()
  match sympy {
    Ok(mod) =>
      match mod.get_attr(name, print_err=false) {
        Some(obj) => Some(objenum_to_obj(obj))
        None => None
      }
    Err(_) => None
  }
}

///|
fn sympy_symbol_or_const_obj(name : String) -> @py.PyObject raise {
  match name {
    "I"
    | "E"
    | "pi"
    | "oo"
    | "zoo"
    | "nan"
    | "GoldenRatio"
    | "EulerGamma"
    | "Catalan" =>
      match sympy_constant_obj(name) {
        Some(obj) => obj
        None => sympy_symbol_obj(name)
      }
    _ => sympy_symbol_obj(name)
  }
}

///|
fn sympy_symbol_obj(name : String) -> @py.PyObject raise {
  sympy_call_obj("sympy.symbols", [OracleArg::Str(name)])
}

///|
fn sympy_nary_obj(
  path : String,
  args : Array[@symcore.Expr],
  identity : String,
) -> @py.PyObject raise {
  if args.is_empty() {
    return sympy_call_obj("sympy.Integer", [OracleArg::Str(identity)])
  }
  let packed : Array[OracleArg] = Array::new()
  for arg in args {
    packed.push(OracleArg::PyObj(expr_to_sympy(arg)))
  }
  sympy_call_obj(path, packed)
}

///|
fn call_callable(
  callable : @py.PyCallable,
  args : Array[@py.PyObject],
) -> @py.PyObject raise {
  let tup = py_tuple_from_objects(args)
  let res = py_call_object(callable, tup, print_err=true)
  match res {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-callable-none")
  }
}

///|
fn sympy_attr_callable(name : String) -> @py.PyCallable? {
  let sympy = try? ensure_sympy_module()
  match sympy {
    Ok(mod) =>
      match mod.get_attr(name, print_err=false) {
        Some(PyCallable(callable)) => Some(callable)
        Some(PyClass(obj)) => {
          let callable_res = try? @py.PyCallable::create(obj)
          match callable_res {
            Ok(callable) => Some(callable)
            Err(_) => None
          }
        }
        Some(other) => {
          let callable_res = try? @py.PyCallable::create(objenum_to_obj(other))
          match callable_res {
            Ok(callable) => Some(callable)
            Err(_) => None
          }
        }
        None => None
      }
    Err(_) => None
  }
}

///|
fn sympy_function_obj(
  name : String,
  args : Array[@symcore.Expr],
) -> @py.PyObject raise {
  let arg_objs : Array[@py.PyObject] = Array::new()
  for arg in args {
    arg_objs.push(expr_to_sympy(arg))
  }
  match sympy_attr_callable(name) {
    Some(callable) => call_callable(callable, arg_objs)
    None => {
      let fn_obj = sympy_call_obj("sympy.Function", [OracleArg::Str(name)])
      let fn_callable = @py.PyCallable::create(fn_obj) catch {
        _ => fail("sympy-function-callable")
      }
      call_callable(fn_callable, arg_objs)
    }
  }
}

///|
pub fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  let out = match obj {
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
  let state = py_gil_ensure()
  @cpython.py_incref(out.obj_ref())
  py_gil_release(state)
  out
}
