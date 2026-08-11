///|
pub type OracleArg = @sympy.OracleArg

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
fn py_str_enum(obj : @py.PyObjectEnum) -> String {
  let state = py_gil_ensure()
  let text = objenum_to_obj(obj).to_string()
  py_gil_release(state)
  text
}

///|
fn geometry_globals() -> @py.PyDict raise {
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let sympy_mod = match @py.pyimport("sympy") {
    Some(v) => v
    None => fail("python-missing:sympy")
  }
  let geometry_mod = match @py.pyimport("sympy.geometry") {
    Some(v) => v
    None => fail("python-missing:sympy.geometry")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", sympy_mod.obj())
  for
    name in [
      "Point", "Point2D", "Point3D", "Line", "Line2D", "Line3D", "Ray", "Ray2D",
      "Ray3D", "Segment", "Segment2D", "Segment3D", "Plane", "intersection", "are_coplanar",
      "centroid", "Ellipse", "Circle", "Polygon", "RegularPolygon", "Triangle", "Parabola",
      "Curve", "convex_hull", "closest_points", "farthest_points",
    ] {
    match geometry_mod.get_attr(name, print_err=false) {
      Some(obj) => globals.set(name, objenum_to_obj(obj))
      None => ()
    }
  }
  for name in ["pi", "oo", "E", "I"] {
    match sympy_mod.get_attr(name, print_err=false) {
      Some(obj) => globals.set(name, objenum_to_obj(obj))
      None => ()
    }
  }
  let symbols_fn = match sympy_mod.get_attr("symbols", print_err=false) {
    Some(obj) =>
      @py.PyCallable::create(objenum_to_obj(obj)) catch {
        _ => fail("python-missing:sympy.symbols")
      }
    None => fail("python-missing:sympy.symbols")
  }
  for name in ["a", "b", "c", "x", "y", "z", "t", "u", "v"] {
    match
      symbols_fn.invoke(
        args=@sympy.py_pack_args([Str(name)]),
        kwargs=@sympy.py_pack_kwargs({}),
        print_err=true,
      ) {
      Some(obj) => globals.set(name, objenum_to_obj(obj))
      None => ()
    }
  }
  globals
}

///|
fn py_eval_geometry(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let result : @py.PyObjectEnum = try {
    let builtins = match @py.pyimport("builtins") {
      Some(v) => v
      None => fail("python-missing:builtins")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=false) {
      Some(obj) => obj
      None => fail("python-missing:eval")
    }
    let eval_callable = @py.PyCallable::create(objenum_to_obj(eval_obj)) catch {
      _ => fail("python-missing:eval-callable")
    }
    let globals = geometry_globals()
    let args = @sympy.py_pack_args([
      Str(expr),
      PyObj(globals.obj()),
      PyObj(globals.obj()),
    ])
    match @sympy.py_call_object(eval_callable, args, print_err=true) {
      Some(obj) => obj
      None => fail("python-eval-none")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  result
}

///|
pub fn geometry_eval_str(expr : String) -> String raise {
  py_str_enum(py_eval_geometry(expr))
}

///|
pub fn geometry_eval_repr(expr : String) -> String raise {
  let state = py_gil_ensure()
  let result : String = try {
    let builtins = match @py.pyimport("builtins") {
      Some(v) => v
      None => fail("python-missing:builtins")
    }
    let repr_obj = match builtins.get_attr("repr", print_err=false) {
      Some(obj) => obj
      None => fail("python-missing:repr")
    }
    let repr_callable = @py.PyCallable::create(objenum_to_obj(repr_obj)) catch {
      _ => fail("python-missing:repr-callable")
    }
    let obj = objenum_to_obj(py_eval_geometry(expr))
    match
      repr_callable.invoke(
        args=@sympy.py_pack_args([PyObj(obj)]),
        kwargs=@sympy.py_pack_kwargs({}),
        print_err=true,
      ) {
      Some(v) => py_str_enum(v)
      None => fail("python-repr-none")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  result
}

///|
pub fn geometry_summary(expr : String) -> String raise {
  let state = py_gil_ensure()
  let result : String = try {
    let builtins = match @py.pyimport("builtins") {
      Some(v) => v
      None => fail("python-missing:builtins")
    }
    let exec_obj = match builtins.get_attr("exec", print_err=false) {
      Some(obj) => obj
      None => fail("python-missing:exec")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=false) {
      Some(obj) => obj
      None => fail("python-missing:eval")
    }
    let exec_callable = @py.PyCallable::create(objenum_to_obj(exec_obj)) catch {
      _ => fail("python-missing:exec-callable")
    }
    let eval_callable = @py.PyCallable::create(objenum_to_obj(eval_obj)) catch {
      _ => fail("python-missing:eval-callable")
    }
    let globals = geometry_globals()
    let script = [
      "def _symbit_geometry_summary(obj):\n", "    if isinstance(obj, list):\n",
      "        return '[' + ', '.join(_symbit_geometry_summary(x) for x in obj) + ']'\n",
      "    if isinstance(obj, tuple):\n", "        return '(' + ', '.join(_symbit_geometry_summary(x) for x in obj) + ')'\n",
      "    if isinstance(obj, (set, frozenset)):\n", "        parts = sorted((_symbit_geometry_summary(x) for x in obj))\n",
      "        return '{' + ', '.join(parts) + '}'\n", "    return repr(obj)\n",
    ].join("")
    ignore(
      match
        exec_callable.invoke(
          args=@sympy.py_pack_args([
            Str(script),
            PyObj(globals.obj()),
            PyObj(globals.obj()),
          ]),
          kwargs=@sympy.py_pack_kwargs({}),
          print_err=true,
        ) {
        Some(v) => v
        None => fail("python-exec-none")
      },
    )
    let value = match
      eval_callable.invoke(
        args=@sympy.py_pack_args([
          Str("_symbit_geometry_summary(" + expr + ")"),
          PyObj(globals.obj()),
          PyObj(globals.obj()),
        ]),
        kwargs=@sympy.py_pack_kwargs({}),
        print_err=true,
      ) {
      Some(v) => v
      None => fail("python-eval-none")
    }
    py_str_enum(value)
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  result
}

///|
pub fn geometry_expr_equal(lhs : String, rhs : String) -> Bool raise {
  let kwargs : Map[String, OracleArg] = {
    "locals": PyObj(geometry_globals().obj()),
  }
  let lhs_obj = objenum_to_obj(
    match @sympy.sympy_call("sympy.sympify", [Str(lhs)], kwargs~) {
      Some(v) => v
      None => fail("sympy-call-none:sympy.sympify")
    },
  )
  let rhs_obj = objenum_to_obj(
    match @sympy.sympy_call("sympy.sympify", [Str(rhs)], kwargs~) {
      Some(v) => v
      None => fail("sympy-call-none:sympy.sympify")
    },
  )
  let eq_obj = match
    @sympy.sympy_call("sympy.Eq", [PyObj(lhs_obj), PyObj(rhs_obj)]) {
    Some(v) => v
    None => fail("sympy-call-none:sympy.Eq")
  }
  let simplified = match
    @sympy.sympy_call("sympy.simplify", [PyObj(objenum_to_obj(eq_obj))]) {
    Some(v) => py_str_enum(v)
    None => fail("sympy-call-none:sympy.simplify")
  }
  simplified == "True"
}
