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
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
}

///|
fn sympy_number_obj(n : @symnum.BigRational) -> @py.PyObject raise {
  @sympy.sympy_number_obj(n)
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
fn py_list_from_objects(values : Array[@py.PyObject]) -> @py.PyList {
  let state = py_gil_ensure()
  let list = @py.PyList::new()
  for v in values {
    list.append(v)
  }
  py_gil_release(state)
  list
}

///|
fn py_list_to_pyobjects(value : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let state = py_gil_ensure()
  let out : Array[@py.PyObject] = Array::new()
  let res = try {
    match value {
      PyList(list) => {
        let len = list.len()
        for i in 0..<len {
          match list.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      PyTuple(tup) => {
        let len = tup.len().to_int()
        for i in 0..<len {
          match tup.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      _ => fail("expected list/tuple")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn resolve_method_callable(
  obj : @py.PyObject,
  name : String,
) -> @py.PyCallable raise {
  let state = py_gil_ensure()
  let res = try {
    match obj.get_attr(name, print_err=false) {
      Some(PyCallable(callable)) => callable
      Some(PyClass(obj0)) =>
        @py.PyCallable::create(obj0) catch {
          _ => fail("sympy-oracle-callable")
        }
      Some(other) =>
        @py.PyCallable::create(objenum_to_obj(other)) catch {
          _ => fail("sympy-oracle-callable")
        }
      None => fail("sympy-oracle-missing:\{name}")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  @cpython.py_incref(res.obj_ref())
  py_gil_release(state)
  res
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("sympy-oracle-call-none")
  }
}

///|
fn py_call_noargs(callable : @py.PyCallable) -> @py.PyObjectEnum raise {
  py_call_with_args(callable, [])
}

///|
fn accum_bounds_obj(
  min : @symcore.Expr,
  max : @symcore.Expr,
) -> @py.PyObject raise {
  let res = sympy_call_must("sympy.AccumBounds", [
    OracleArg::PyObj(expr_to_sympy(min)),
    OracleArg::PyObj(expr_to_sympy(max)),
  ])
  objenum_to_obj(res)
}

///|
pub fn sympy_normalize(expr_str : String) -> String raise {
  let expr = sympy_call_must("sympy.sympify", [OracleArg::Str(expr_str)])
  py_str_enum(expr)
}

///|
pub fn accum_add(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let a = accum_bounds_obj(a_min, a_max)
  let b = accum_bounds_obj(b_min, b_max)
  let res = sympy_call_must("sympy.Add", [
    OracleArg::PyObj(a),
    OracleArg::PyObj(b),
  ])
  py_str_enum(res)
}

///|
pub fn accum_sub(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let a = accum_bounds_obj(a_min, a_max)
  let b = accum_bounds_obj(b_min, b_max)
  let neg = sympy_call_must("sympy.Mul", [
    OracleArg::Int(-1),
    OracleArg::PyObj(b),
  ])
  let res = sympy_call_must("sympy.Add", [
    OracleArg::PyObj(a),
    OracleArg::PyObj(objenum_to_obj(neg)),
  ])
  py_str_enum(res)
}

///|
pub fn accum_mul(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let a = accum_bounds_obj(a_min, a_max)
  let b = accum_bounds_obj(b_min, b_max)
  let res = sympy_call_must("sympy.Mul", [
    OracleArg::PyObj(a),
    OracleArg::PyObj(b),
  ])
  py_str_enum(res)
}

///|
pub fn accum_div(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  b_min : @symcore.Expr,
  b_max : @symcore.Expr,
) -> String raise {
  let a = accum_bounds_obj(a_min, a_max)
  let b = accum_bounds_obj(b_min, b_max)
  let inv = sympy_call_must("sympy.Pow", [
    OracleArg::PyObj(b),
    OracleArg::Int(-1),
  ])
  let res = sympy_call_must("sympy.Mul", [
    OracleArg::PyObj(a),
    OracleArg::PyObj(objenum_to_obj(inv)),
  ])
  py_str_enum(res)
}

///|
pub fn accum_pow(
  a_min : @symcore.Expr,
  a_max : @symcore.Expr,
  exp : @symcore.Expr,
) -> String raise {
  let a = accum_bounds_obj(a_min, a_max)
  let e = expr_to_sympy(exp)
  let res = sympy_call_must("sympy.Pow", [
    OracleArg::PyObj(a),
    OracleArg::PyObj(e),
  ])
  py_str_enum(res)
}

///|
pub fn accum_abs(min : @symcore.Expr, max : @symcore.Expr) -> String raise {
  let a = accum_bounds_obj(min, max)
  let abs_call = resolve_method_callable(a, "__abs__")
  let res = py_call_noargs(abs_call)
  py_str_enum(res)
}

///|
pub fn accum_delta(min : @symcore.Expr, max : @symcore.Expr) -> String raise {
  let a = accum_bounds_obj(min, max)
  let state = py_gil_ensure()
  let obj = match a.get_attr("delta", print_err=false) {
    Some(v) => objenum_to_obj(v)
    None => {
      py_gil_release(state)
      fail("accum-delta-missing")
    }
  }
  py_gil_release(state)
  py_str_obj(obj)
}

///|
pub fn accum_mid(min : @symcore.Expr, max : @symcore.Expr) -> String raise {
  let a = accum_bounds_obj(min, max)
  let state = py_gil_ensure()
  let obj = match a.get_attr("mid", print_err=false) {
    Some(v) => objenum_to_obj(v)
    None => {
      py_gil_release(state)
      fail("accum-mid-missing")
    }
  }
  py_gil_release(state)
  py_str_obj(obj)
}

///|
pub fn finite_diff_weights_str(
  order : Int,
  x_list : Array[@symnum.BigRational],
  x0? : @symnum.BigRational = @symnum.BigRational::zero(),
) -> String raise {
  let x_objs : Array[@py.PyObject] = Array::new()
  for x in x_list {
    x_objs.push(sympy_number_obj(x))
  }
  let list = py_list_from_objects(x_objs)
  let x0_obj = sympy_number_obj(x0)
  let res = sympy_call_must("sympy.calculus.finite_diff.finite_diff_weights", [
    OracleArg::Int(order),
    OracleArg::PyObj(list.obj()),
    OracleArg::PyObj(x0_obj),
  ])
  py_str_enum(res)
}

///|
pub fn apply_finite_diff_str(
  order : Int,
  x_list : Array[@symnum.BigRational],
  y_list : Array[@symcore.Expr],
  x0? : @symnum.BigRational = @symnum.BigRational::zero(),
) -> String raise {
  let x_objs : Array[@py.PyObject] = Array::new()
  for x in x_list {
    x_objs.push(sympy_number_obj(x))
  }
  let y_objs : Array[@py.PyObject] = Array::new()
  for y in y_list {
    y_objs.push(expr_to_sympy(y))
  }
  let x_list_obj = py_list_from_objects(x_objs)
  let y_list_obj = py_list_from_objects(y_objs)
  let x0_obj = sympy_number_obj(x0)
  let res = sympy_call_must("sympy.calculus.finite_diff.apply_finite_diff", [
    OracleArg::Int(order),
    OracleArg::PyObj(x_list_obj.obj()),
    OracleArg::PyObj(y_list_obj.obj()),
    OracleArg::PyObj(x0_obj),
  ])
  py_str_enum(res)
}

///|
pub fn euler_equations_str(
  lagrangian : @symcore.Expr,
  funcs : Array[@symcore.Expr],
  vars : Array[@symcore.Expr],
) -> Array[String] raise {
  let l_obj = expr_to_sympy(lagrangian)
  let f_objs : Array[@py.PyObject] = Array::new()
  for f in funcs {
    f_objs.push(expr_to_sympy(f))
  }
  let v_objs : Array[@py.PyObject] = Array::new()
  for v in vars {
    v_objs.push(expr_to_sympy(v))
  }
  let f_list = py_list_from_objects(f_objs)
  let v_list = py_list_from_objects(v_objs)
  let res = sympy_call_must("sympy.calculus.euler.euler_equations", [
    OracleArg::PyObj(l_obj),
    OracleArg::PyObj(f_list.obj()),
    OracleArg::PyObj(v_list.obj()),
  ])
  let items = py_list_to_pyobjects(res)
  let out : Array[String] = Array::new()
  for item in items {
    out.push(py_str_obj(item))
  }
  out
}

///|
pub fn singularities_str(
  expr : @symcore.Expr,
  symbol : @symcore.Expr,
) -> String raise {
  let e_obj = expr_to_sympy(expr)
  let s_obj = expr_to_sympy(symbol)
  let res = sympy_call_must("sympy.calculus.singularities.singularities", [
    OracleArg::PyObj(e_obj),
    OracleArg::PyObj(s_obj),
  ])
  py_str_enum(res)
}

///|
pub fn periodicity_str(
  expr : @symcore.Expr,
  symbol : @symcore.Expr,
) -> String raise {
  let e_obj = expr_to_sympy(expr)
  let s_obj = expr_to_sympy(symbol)
  let res = sympy_call("sympy.calculus.util.periodicity", [
    OracleArg::PyObj(e_obj),
    OracleArg::PyObj(s_obj),
  ])
  match res {
    Some(obj) => py_str_enum(obj)
    None => "None"
  }
}
