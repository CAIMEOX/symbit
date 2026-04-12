///|
fn plotting_python_string_literal(value : String) -> String {
  "'" +
  value
  .replace(old="\\", new="\\\\")
  .replace(old="'", new="\\'")
  .replace(old="\n", new="\\n") +
  "'"
}

///|
fn plotting_py_callable_from_enum(obj : @py.PyObjectEnum) -> @py.PyCallable raise {
  match obj {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    _ =>
      @py.PyCallable::create(@sympy.objenum_to_obj(obj)) catch {
        _ => fail("py-callable")
      }
  }
}

///|
fn plotting_py_str_obj(obj : @py.PyObject) -> String {
  let state = @sympy.py_gil_ensure()
  let text = obj.to_string()
  @sympy.py_gil_release(state)
  text
}

///|
fn plotting_exec_result_str(script : String) -> String raise {
  let state = @sympy.py_gil_ensure()
  let result = try {
    let builtins = match @py.pyimport("builtins") {
      Some(mod) => mod
      None => fail("py-builtins-missing")
    }
    let exec_obj = match builtins.get_attr("exec", print_err=true) {
      Some(obj) => obj
      None => fail("py-exec-missing")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let globals = @py.PyDict::new()
    globals.set("__builtins__", builtins.obj())
    let sympy_mod = match @py.pyimport("sympy") {
      Some(mod) => mod.obj()
      None => fail("py-sympy-missing")
    }
    globals.set("sympy", sympy_mod)
    let exec_args = @sympy.py_pack_args([
      @sympy.OracleArg::Str(script),
      @sympy.OracleArg::PyObj(globals.obj()),
      @sympy.OracleArg::PyObj(globals.obj()),
    ])
    ignore(@sympy.py_call_object(plotting_py_callable_from_enum(exec_obj), exec_args))
    let eval_args = @sympy.py_pack_args([
      @sympy.OracleArg::Str("__result__"),
      @sympy.OracleArg::PyObj(globals.obj()),
      @sympy.OracleArg::PyObj(globals.obj()),
    ])
    match @sympy.py_call_object(plotting_py_callable_from_enum(eval_obj), eval_args) {
      Some(obj) => plotting_py_str_obj(@sympy.objenum_to_obj(obj))
      None => fail("py-eval-result-none")
    }
  } catch {
    err => {
      @sympy.py_gil_release(state)
      raise err
    }
  }
  @sympy.py_gil_release(state)
  result
}

///|
pub fn oracle_textplot_lines(
  expr_text : String,
  a_text : String,
  b_text : String,
  width : Int,
  height : Int,
) -> Array[String] raise {
  let script = "import warnings\n" +
    "from sympy import sympify\n" +
    "from sympy.plotting.textplot import textplot_str\n" +
    "with warnings.catch_warnings():\n" +
    "    warnings.simplefilter('ignore')\n" +
    "    __result__ = chr(31).join(textplot_str(sympify(" +
    plotting_python_string_literal(expr_text) +
    "), sympify(" +
    plotting_python_string_literal(a_text) +
    "), sympify(" +
    plotting_python_string_literal(b_text) +
    "), " +
    width.to_string() +
    ", " +
    height.to_string() +
    "))\n"
  plotting_exec_result_str(script)
  .split("\u001f")
  .to_array()
  .map(StringView::to_string)
}

///|
pub fn oracle_plot_text_lines(
  expr_text : String,
  var_text : String,
  a_text : String,
  b_text : String,
) -> Array[String] raise {
  let script = "import io\n" +
    "import warnings\n" +
    "from contextlib import redirect_stdout\n" +
    "from sympy import sympify\n" +
    "from sympy.plotting import plot\n" +
    "__buffer__ = io.StringIO()\n" +
    "with warnings.catch_warnings():\n" +
    "    warnings.simplefilter('ignore')\n" +
    "    with redirect_stdout(__buffer__):\n" +
    "        plot(sympify(" +
    plotting_python_string_literal(expr_text) +
    "), (sympify(" +
    plotting_python_string_literal(var_text) +
    "), sympify(" +
    plotting_python_string_literal(a_text) +
    "), sympify(" +
    plotting_python_string_literal(b_text) +
    ")), backend='text')\n" +
    "__result__ = chr(31).join(__buffer__.getvalue().rstrip('\\n').splitlines())\n"
  plotting_exec_result_str(script)
  .split("\u001f")
  .to_array()
  .map(StringView::to_string)
}
