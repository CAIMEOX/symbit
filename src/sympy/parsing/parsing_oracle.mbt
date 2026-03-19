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
fn py_callable_from_enum(obj : @py.PyObjectEnum) -> @py.PyCallable raise {
  match obj {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    _ =>
      @py.PyCallable::create(objenum_to_obj(obj)) catch {
        _ => fail("py-callable")
      }
  }
}

///|
fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object(callable, args, print_err~)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn python_string_literal(value : String) -> String {
  let escaped_backslashes = value.replace(old="\\", new="\\\\")
  let escaped_quotes = escaped_backslashes.replace(old="'", new="\\'")
  "'" + escaped_quotes + "'"
}

///|
pub fn parsing_eval(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let res = try {
    let builtins = match @py.pyimport("builtins") {
      Some(mod) => mod
      None => fail("py-builtins-missing")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let eval_callable = py_callable_from_enum(eval_obj)
    let globals = @py.PyDict::new()
    globals.set("__builtins__", builtins.obj())
    let sympy_mod = match @py.pyimport("sympy") {
      Some(mod) => mod.obj()
      None => fail("py-sympy-missing")
    }
    globals.set("sympy", sympy_mod)
    let args = @sympy.py_pack_args([
      @sympy.OracleArg::Str(expr),
      @sympy.OracleArg::PyObj(globals.obj()),
      @sympy.OracleArg::PyObj(globals.obj()),
    ])
    match py_call_object(eval_callable, args, print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-none")
    }
  } catch {
    err => {
      py_gil_release(state)
      raise err
    }
  } noraise {
    v => v
  }
  py_gil_release(state)
  res
}

///|
pub fn parsing_eval_str(expr : String) -> String raise {
  py_str_obj(objenum_to_obj(parsing_eval(expr)))
}

///|
pub fn parse_expr_sstr(src : String, evaluate? : Bool = true) -> String raise {
  let evaluate_text = if evaluate { "True" } else { "False" }
  parsing_eval_str(
    "sympy.sstr(sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(src) +
    ", evaluate=" +
    evaluate_text +
    "))",
  )
}

///|
pub fn parse_expr_equiv(lhs_src : String, rhs_src : String) -> String raise {
  parsing_eval_str(
    "sympy.sstr(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ")))",
  )
}
