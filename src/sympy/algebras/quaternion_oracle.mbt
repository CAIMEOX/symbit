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
fn ensure_sympy_module() -> @py.PyModule raise {
  match @py.pyimport("sympy") {
    Some(mod) => mod
    None => fail("sympy-missing:sympy")
  }
}

///|
fn sympy_attr_obj(name : String) -> @py.PyObject raise {
  let sympy = ensure_sympy_module()
  match sympy.get_attr(name, print_err=false) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-missing:sympy.\{name}")
  }
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
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
fn py_call_one(
  callable : @py.PyCallable,
  arg : @py.PyObject,
) -> @py.PyObjectEnum raise {
  py_call_with_args(callable, [OracleArg::PyObj(arg)])
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
fn quat_obj(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> @py.PyObject raise {
  let res = sympy_call_must("sympy.Quaternion", [
    OracleArg::PyObj(expr_to_sympy(a)),
    OracleArg::PyObj(expr_to_sympy(b)),
    OracleArg::PyObj(expr_to_sympy(c)),
    OracleArg::PyObj(expr_to_sympy(d)),
  ])
  objenum_to_obj(res)
}

///|
fn quat_components(obj : @py.PyObject) -> Array[String] raise {
  let names = ["a", "b", "c", "d"]
  let out : Array[String] = Array::new()
  for name in names {
    match obj.get_attr(name, print_err=false) {
      Some(v) => out.push(py_str_enum(v))
      None => fail("quat-attr-missing:\{name}")
    }
  }
  out
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let diff = sympy_call_must("sympy.sympify", [
    OracleArg::Str("(\{lhs}) - (\{rhs})"),
  ])
  let res = sympy_call_must("sympy.simplify", [
    OracleArg::PyObj(objenum_to_obj(diff)),
  ])
  py_str_enum(res) == "0"
}

///|
pub fn quat_add(
  a1 : @symcore.Expr,
  b1 : @symcore.Expr,
  c1 : @symcore.Expr,
  d1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b2 : @symcore.Expr,
  c2 : @symcore.Expr,
  d2 : @symcore.Expr,
) -> Array[String] raise {
  let q1 = quat_obj(a1, b1, c1, d1)
  let q2 = quat_obj(a2, b2, c2, d2)
  let add = resolve_method_callable(q1, "add")
  let res = py_call_one(add, q2)
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_mul(
  a1 : @symcore.Expr,
  b1 : @symcore.Expr,
  c1 : @symcore.Expr,
  d1 : @symcore.Expr,
  a2 : @symcore.Expr,
  b2 : @symcore.Expr,
  c2 : @symcore.Expr,
  d2 : @symcore.Expr,
) -> Array[String] raise {
  let q1 = quat_obj(a1, b1, c1, d1)
  let q2 = quat_obj(a2, b2, c2, d2)
  let mul = resolve_method_callable(q1, "mul")
  let res = py_call_one(mul, q2)
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_conjugate(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let res = sympy_call_must("sympy.conjugate", [OracleArg::PyObj(q)])
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_norm(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> String raise {
  let q = quat_obj(a, b, c, d)
  let norm = resolve_method_callable(q, "norm")
  let res = py_call_noargs(norm)
  py_str_enum(res)
}

///|
pub fn quat_inverse(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let inv = resolve_method_callable(q, "inverse")
  let res = py_call_noargs(inv)
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_pow(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
  p : Int,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let pow = resolve_method_callable(q, "pow")
  let p_obj = @sympy.py_pack(OracleArg::Int(p))
  let res = py_call_one(pow, p_obj)
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_exp(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let exp = resolve_method_callable(q, "exp")
  let res = py_call_noargs(exp)
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_log(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let log = resolve_method_callable(q, "log")
  let res = py_call_noargs(log)
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_from_axis_angle(
  x : @symcore.Expr,
  y : @symcore.Expr,
  z : @symcore.Expr,
  angle : @symcore.Expr,
) -> Array[String] raise {
  let qcls = sympy_attr_obj("Quaternion")
  let from_axis = resolve_method_callable(qcls, "from_axis_angle")
  let vec = @sympy.py_pack(
    OracleArg::List([
      OracleArg::PyObj(expr_to_sympy(x)),
      OracleArg::PyObj(expr_to_sympy(y)),
      OracleArg::PyObj(expr_to_sympy(z)),
    ]),
  )
  let res = py_call_with_args(from_axis, [
    OracleArg::PyObj(vec),
    OracleArg::PyObj(expr_to_sympy(angle)),
  ])
  quat_components(objenum_to_obj(res))
}

///|
pub fn quat_to_axis_angle(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let call = resolve_method_callable(q, "to_axis_angle")
  let res = py_call_noargs(call)
  let items = py_list_to_pyobjects(res)
  guard items.length() == 2 else { fail("axis-angle-arity") }
  let axis_items = py_list_to_pyobjects(@py.PyObjectEnum::create(items[0]))
  guard axis_items.length() == 3 else { fail("axis-angle-axis") }
  [
    py_str_obj(axis_items[0]),
    py_str_obj(axis_items[1]),
    py_str_obj(axis_items[2]),
    py_str_obj(items[1]),
  ]
}

///|
fn matrix_to_strings(mat : @py.PyObject) -> Array[String] raise {
  let tolist = resolve_method_callable(mat, "tolist")
  let list_enum = py_call_noargs(tolist)
  let rows = py_list_to_pyobjects(list_enum)
  let out : Array[String] = Array::new()
  for row in rows {
    let row_items = py_list_to_pyobjects(@py.PyObjectEnum::create(row))
    for item in row_items {
      out.push(py_str_obj(item))
    }
  }
  out
}

///|
pub fn quat_to_rotation_matrix(
  a : @symcore.Expr,
  b : @symcore.Expr,
  c : @symcore.Expr,
  d : @symcore.Expr,
) -> Array[String] raise {
  let q = quat_obj(a, b, c, d)
  let call = resolve_method_callable(q, "to_rotation_matrix")
  let res = py_call_noargs(call)
  matrix_to_strings(objenum_to_obj(res))
}
