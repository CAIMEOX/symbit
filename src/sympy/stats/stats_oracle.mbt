///|
/// Oracle helpers for SymPy stats.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object(callable, args, print_err~)
}

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
  let out = obj.to_string()
  py_gil_release(state)
  out
}

///|
fn py_str_enum(obj : @py.PyObjectEnum) -> String {
  py_str_obj(objenum_to_obj(obj))
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
fn import_module(name : String) -> @py.PyModule raise {
  match @py.pyimport(name) {
    Some(mod) => mod
    None => fail("py-import-missing:\{name}")
  }
}

///|
fn try_bind_name(globals : @py.PyDict, mod : @py.PyModule, name : String) -> Unit {
  match mod.get_attr(name, print_err=false) {
    Some(obj) => globals.set(name, objenum_to_obj(obj))
    None => ()
  }
}

///|
fn sympy_names() -> Array[String] {
  [
    "symbols",
    "Symbol",
    "Integer",
    "Rational",
    "Eq",
    "Ne",
    "Lt",
    "Le",
    "Gt",
    "Ge",
    "And",
    "Or",
    "Not",
    "exp",
    "log",
    "sqrt",
    "sin",
    "cos",
    "tan",
    "Lambda",
    "Product",
    "Sum",
    "Indexed",
    "IndexedBase",
    "pi",
    "I",
    "E",
    "erf",
    "erfc",
    "erfinv",
    "erfcinv",
    "atan",
    "Abs",
    "besseli",
    "besselk",
    "betaincinv",
    "gammaincinv",
    "gamma",
    "beta",
    "lowergamma",
    "EulerGamma",
    "factorial",
    "binomial",
    "simplify",
    "srepr",
    "oo",
    "S",
    "Matrix",
    "MatrixSymbol",
    "Trace",
    "Integral",
    "Piecewise",
    "Tuple",
  ]
}

///|
fn sympy_stats_names() -> Array[String] {
  [
    "P",
    "E",
    "H",
    "Probability",
    "Expectation",
    "Variance",
    "Covariance",
    "variance",
    "covariance",
    "density",
    "cdf",
    "characteristic_function",
    "moment_generating_function",
    "quantile",
    "median",
    "skewness",
    "kurtosis",
    "entropy",
    "factorial_moment",
    "cmoment",
    "smoment",
    "Die",
    "Coin",
    "Bernoulli",
    "DiscreteUniform",
    "Binomial",
    "Poisson",
    "Geometric",
    "NegativeBinomial",
    "Normal",
    "Exponential",
    "Gamma",
    "PoissonProcess",
    "WienerProcess",
    "Wishart",
    "MatrixNormal",
  ]
}

///|
fn bind_symbol(globals : @py.PyDict, name : String) -> Unit raise {
  let sym = sympy_call_must("sympy.Symbol", [OracleArg::Str(name)])
  globals.set(name, objenum_to_obj(sym))
}

///|
fn stats_globals() -> @py.PyDict raise {
  let builtins = import_module("builtins")
  let sympy_mod = import_module("sympy")
  let stats_mod = import_module("sympy.stats")
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", sympy_mod.obj())
  globals.set("stats", stats_mod.obj())
  for name in sympy_names() {
    try_bind_name(globals, sympy_mod, name)
  }
  for name in sympy_stats_names() {
    try_bind_name(globals, stats_mod, name)
  }
  for sym_name in [
    "x",
    "y",
    "z",
    "t",
    "l",
    "k",
    "n",
    "m",
    "A",
    "B",
    "C",
    "D",
    "E0",
    "F",
    "G",
    "H0",
    "I0",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P0",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "_H",
    "_i",
    "_j",
    "_k",
    "_s",
  ] {
    ignore(try? bind_symbol(globals, sym_name))
  }
  globals
}

///|
fn py_eval_stats(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let result = try {
    let builtins = import_module("builtins")
    let eval_obj = match builtins.get_attr("eval", print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let eval_callable = py_callable_from_enum(eval_obj)
    let globals = stats_globals()
    let args = @sympy.py_pack_args([
      OracleArg::Str(expr),
      OracleArg::PyObj(globals.obj()),
      OracleArg::PyObj(globals.obj()),
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
  result
}

///|
pub fn stats_eval_str(expr : String) -> String raise {
  py_str_enum(py_eval_stats(expr))
}

///|
pub fn stats_eval_srepr(expr : String) -> String raise {
  let obj = objenum_to_obj(py_eval_stats(expr))
  let srepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(obj)])
  py_str_enum(srepr)
}

///|
pub fn stats_expr_equiv(a : String, b : String) -> Bool raise {
  let locals = stats_globals()
  let kwargs : Map[String, OracleArg] = {
    "locals": OracleArg::PyObj(locals.obj()),
  }
  let a_obj = objenum_to_obj(sympy_call_must("sympy.sympify", [OracleArg::Str(a)], kwargs~))
  let b_obj = objenum_to_obj(sympy_call_must("sympy.sympify", [OracleArg::Str(b)], kwargs~))
  match sympy_call("sympy.Eq", [OracleArg::PyObj(a_obj), OracleArg::PyObj(b_obj)]) {
    Some(eq_obj) => {
      let simp = sympy_call_must("sympy.simplify", [OracleArg::PyObj(objenum_to_obj(eq_obj))])
      let txt = py_str_enum(simp)
      if txt == "True" {
        return true
      }
      if txt == "False" {
        return false
      }
    }
    None => ()
  }
  let arepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(a_obj)])
  let brepr = sympy_call_must("sympy.srepr", [OracleArg::PyObj(b_obj)])
  py_str_enum(arepr) == py_str_enum(brepr)
}

///|
pub fn stats_srepr_eq(a : String, b : String) -> Bool raise {
  stats_eval_srepr(a) == stats_eval_srepr(b)
}
