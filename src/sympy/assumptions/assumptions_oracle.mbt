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
fn put_tri_kw(kwargs : Map[String, OracleArg], key : String, value : @symassume.Tri) -> Unit {
  match @symassume.tri_to_bool_option(value) {
    Some(v) => kwargs[key] = OracleArg::Bool(v)
    None => ()
  }
}

///|
fn symbol_obj_with_facts(
  name : String,
  facts : @symassume.SymbolFacts,
) -> @py.PyObject raise {
  let kwargs : Map[String, OracleArg] = {}
  put_tri_kw(kwargs, "zero", facts.is_zero)
  put_tri_kw(kwargs, "nonzero", facts.is_nonzero)
  put_tri_kw(kwargs, "integer", facts.is_integer)
  put_tri_kw(kwargs, "rational", facts.is_rational)
  put_tri_kw(kwargs, "real", facts.is_real)
  put_tri_kw(kwargs, "positive", facts.is_positive)
  put_tri_kw(kwargs, "nonnegative", facts.is_nonnegative)
  objenum_to_obj(sympy_call_must("sympy.Symbol", [OracleArg::Str(name)], kwargs~))
}

///|
fn locals_from_env(
  env : Map[String, @symassume.SymbolFacts],
) -> Map[String, OracleArg] raise {
  let locals : Map[String, OracleArg] = {}
  for name, facts in env {
    locals[name] = OracleArg::PyObj(symbol_obj_with_facts(name, facts))
  }
  locals
}

///|
fn sympify_with_env(
  expr : @symcore.Expr,
  env : Map[String, @symassume.SymbolFacts],
) -> @py.PyObjectEnum raise {
  let kwargs : Map[String, OracleArg] = {
    "locals": OracleArg::Dict(locals_from_env(env)),
  }
  let expr_str = @symprint.to_string(expr)
  sympy_call_must("sympy.sympify", [OracleArg::Str(expr_str)], kwargs~)
}

///|
pub fn expr_attr(
  expr : @symcore.Expr,
  attr : String,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  let expr_obj = objenum_to_obj(sympify_with_env(expr, env))
  match expr_obj.get_attr(attr, print_err=true) {
    Some(value) => py_str_enum(value)
    None => fail("sympy-attr-missing:\{attr}")
  }
}

///|
pub fn is_zero(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_zero", env~)
}

///|
pub fn is_nonzero(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_nonzero", env~)
}

///|
pub fn is_integer(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_integer", env~)
}

///|
pub fn is_rational(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_rational", env~)
}

///|
pub fn is_real(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_real", env~)
}

///|
pub fn is_positive(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_positive", env~)
}

///|
pub fn is_nonnegative(
  expr : @symcore.Expr,
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> String raise {
  expr_attr(expr, "is_nonnegative", env~)
}

///|
fn assumptions_globals() -> @py.PyDict raise {
  let builtins = match @py.pyimport("builtins") {
    Some(mod) => mod
    None => fail("py-builtins-missing")
  }
  let sympy_mod = match @py.pyimport("sympy") {
    Some(mod) => mod
    None => fail("py-sympy-missing")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", sympy_mod.obj())
  for name in [
    "Q",
    "ask",
    "Implies",
    "Equivalent",
    "And",
    "Or",
    "Not",
    "Eq",
    "Ne",
    "Gt",
    "Ge",
    "Lt",
    "Le",
    "MatrixSymbol",
  ] {
    match sympy_mod.get_attr(name, print_err=false) {
      Some(obj) => globals.set(name, objenum_to_obj(obj))
      None => ()
    }
  }
  for sym_name in ["x", "y", "z", "a", "b", "c", "n", "m", "t", "u", "v"] {
    let sym = sympy_call_must("sympy.Symbol", [OracleArg::Str(sym_name)])
    globals.set(sym_name, objenum_to_obj(sym))
  }
  for const_name in ["oo", "zoo", "I", "E", "pi"] {
    match sympy_mod.get_attr(const_name, print_err=false) {
      Some(obj) => globals.set(const_name, objenum_to_obj(obj))
      None => ()
    }
  }
  globals
}

///|
fn py_eval_assumptions(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let result = try {
    let builtins = match @py.pyimport("builtins") {
      Some(mod) => mod
      None => fail("py-builtins-missing")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=false) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let eval_callable = py_callable_from_enum(eval_obj)
    let globals = assumptions_globals()
    let args = @sympy.py_pack_args([
      OracleArg::Str(expr),
      OracleArg::PyObj(globals.obj()),
      OracleArg::PyObj(globals.obj()),
    ])
    match @sympy.py_call_object(eval_callable, args, print_err=false) {
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
pub fn ask_query_str(
  proposition : String,
  assumptions? : String = "True",
) -> String {
  // Wrap with str(...) so Python None is represented as "None"
  // instead of being treated as a missing return object.
  let expr = "str(ask(\{proposition}, assumptions=(\{assumptions})))"
  let result : Result[@py.PyObjectEnum, Error] = try? py_eval_assumptions(expr)
  match result {
    Ok(value) => py_str_enum(value)
    Err(err) => {
      let msg = "\{err}"
      @cpython.py_err_clear()
      if msg.contains("inconsistent assumptions") || msg.contains("py-eval-none") {
        "InconsistentAssumptions"
      } else {
        "OracleError:\{msg}"
      }
    }
  }
}
