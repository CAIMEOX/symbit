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
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
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
fn sympy_call_must(
  path : String,
  args : Array[@sympy.OracleArg],
  kwargs? : Map[String, @sympy.OracleArg] = {},
) -> @py.PyObjectEnum raise {
  match @sympy.sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
pub fn core_expr_sstr(expr : @symcore.Expr) -> String raise {
  let obj = @sympy.expr_to_sympy(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.sstr", [@sympy.OracleArg::PyObj(obj)]),
    ),
  )
}

///|
pub fn core_expr_srepr(expr : @symcore.Expr) -> String raise {
  let obj = @sympy.expr_to_sympy(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.srepr", [@sympy.OracleArg::PyObj(obj)]),
    ),
  )
}

///|
pub fn core_expr_latex_kwargs(
  expr : @symcore.Expr,
  kwargs? : Map[String, @sympy.OracleArg] = {},
) -> String raise {
  let obj = @sympy.expr_to_sympy(expr)
  py_str_obj(
    objenum_to_obj(
      sympy_call_must("sympy.latex", [@sympy.OracleArg::PyObj(obj)], kwargs~),
    ),
  )
}

///|
pub fn core_expr_latex(
  expr : @symcore.Expr,
  mode? : String = "plain",
) -> String raise {
  core_expr_latex_kwargs(expr, kwargs={ "mode": @sympy.OracleArg::Str(mode) })
}

///|
pub fn core_func_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals(
      "getattr(expr.func, '__name__', sympy.sstr(expr.func))", globals,
    ),
  )
}

///|
pub fn core_args_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals("tuple(sympy.sstr(v) for v in expr.args)", globals),
  )
}

///|
pub fn core_attr_bool(expr : @symcore.Expr, attr : String) -> Bool raise {
  let expr_obj = @sympy.expr_to_sympy(expr)
  if attr == "is_nan" {
    let globals = @py.PyDict::new()
    globals.set("expr", expr_obj)
    return py_str_obj(core_eval_with_globals("expr is sympy.nan", globals)) ==
      "True"
  }
  if attr == "is_one" {
    let globals = @py.PyDict::new()
    globals.set("expr", expr_obj)
    return py_str_obj(
        core_eval_with_globals("expr == sympy.Integer(1)", globals),
      ) ==
      "True"
  }
  match expr_obj.get_attr(attr, print_err=true) {
    Some(value) => py_str_obj(objenum_to_obj(value)) == "True"
    None => fail("sympy-attr-missing:\{attr}")
  }
}

///|
fn core_eval_with_globals(
  code : String,
  globals : @py.PyDict,
) -> @py.PyObject raise {
  let builtins = match @py.pyimport("builtins") {
    Some(mod) => mod
    None => fail("py-builtins-missing")
  }
  let eval_obj = match builtins.get_attr("eval", print_err=true) {
    Some(obj) => obj
    None => fail("py-eval-missing")
  }
  globals.set("__builtins__", builtins.obj())
  let sympy_mod = match @py.pyimport("sympy") {
    Some(mod) => mod.obj()
    None => fail("py-sympy-missing")
  }
  globals.set("sympy", sympy_mod)
  let args = @sympy.py_pack_args([
    @sympy.OracleArg::Str(code),
    @sympy.OracleArg::PyObj(globals.obj()),
  ])
  let res = match @sympy.py_call_object(py_callable_from_enum(eval_obj), args) {
    Some(obj) => obj
    None => fail("py-eval-none")
  }
  objenum_to_obj(res)
}

///|
fn core_exec_result_str(script : String) -> String raise {
  let state = py_gil_ensure()
  let res = try {
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
    let eval_callable = py_callable_from_enum(eval_obj)
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
    ignore(@sympy.py_call_object(py_callable_from_enum(exec_obj), exec_args))
    let eval_args = @sympy.py_pack_args([
      @sympy.OracleArg::Str("__result__"),
      @sympy.OracleArg::PyObj(globals.obj()),
      @sympy.OracleArg::PyObj(globals.obj()),
    ])
    match @sympy.py_call_object(eval_callable, eval_args) {
      Some(obj) => py_str_obj(objenum_to_obj(obj))
      None => fail("py-eval-result-none")
    }
  } catch {
    err => {
      py_gil_release(state)
      raise err
    }
  }
  py_gil_release(state)
  res
}

///|
pub fn core_parameters_sstr(
  expr_code : String,
  evaluate? : Bool = true,
  distribute? : Bool = true,
  exp_is_pow? : Bool = false,
) -> String raise {
  let eval_text = if evaluate { "True" } else { "False" }
  let distribute_text = if distribute { "True" } else { "False" }
  let exp_is_pow_text = if exp_is_pow { "True" } else { "False" }
  let script = "import contextlib\n" +
    "from sympy.core.parameters import evaluate, distribute, _exp_is_pow\n" +
    "x = sympy.Symbol('x')\n" +
    "y = sympy.Symbol('y')\n" +
    "with contextlib.ExitStack() as _stack:\n" +
    "    _stack.enter_context(evaluate(" +
    eval_text +
    "))\n" +
    "    _stack.enter_context(distribute(" +
    distribute_text +
    "))\n" +
    "    _stack.enter_context(_exp_is_pow(" +
    exp_is_pow_text +
    "))\n" +
    "    __result__ = sympy.sstr(" +
    expr_code +
    ")\n"
  core_exec_result_str(script)
}

///|
pub fn core_free_symbols_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals(
      "tuple(sorted((sympy.sstr(v) for v in expr.free_symbols)))", globals,
    ),
  )
}

///|
pub fn core_atoms_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals(
      "tuple(sorted((sympy.sstr(v) for v in expr.atoms())))", globals,
    ),
  )
}

///|
pub fn core_has_bool(
  expr : @symcore.Expr,
  needle : @symcore.Expr,
) -> Bool raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  globals.set("needle", @sympy.expr_to_sympy(needle))
  py_str_obj(core_eval_with_globals("expr.has(needle)", globals)) == "True"
}

///|
pub fn core_xreplace_sstr(
  expr : @symcore.Expr,
  old_expr : @symcore.Expr,
  new_expr : @symcore.Expr,
) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  globals.set("old", @sympy.expr_to_sympy(old_expr))
  globals.set("new", @sympy.expr_to_sympy(new_expr))
  py_str_obj(
    core_eval_with_globals("sympy.sstr(expr.xreplace({old: new}))", globals),
  )
}

///|
pub fn core_replace_sin_with_cos_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  let code = "sympy.sstr(expr.replace(lambda e: e.func == sympy.sin, " +
    "lambda e: sympy.cos(*e.args)))"
  py_str_obj(core_eval_with_globals(code, globals))
}

///|
pub fn core_subst_symbol_sstr(
  expr : @symcore.Expr,
  symbol_name : String,
  new_expr : @symcore.Expr,
) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  globals.set("old", @sympy.expr_to_sympy(@symcore.Expr::Symbol(symbol_name)))
  globals.set("new", @sympy.expr_to_sympy(new_expr))
  py_str_obj(core_eval_with_globals("sympy.sstr(expr.subs(old, new))", globals))
}

///|
pub fn core_subst_expr_sstr(
  expr : @symcore.Expr,
  old_expr : @symcore.Expr,
  new_expr : @symcore.Expr,
) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  globals.set("old", @sympy.expr_to_sympy(old_expr))
  globals.set("new", @sympy.expr_to_sympy(new_expr))
  py_str_obj(core_eval_with_globals("sympy.sstr(expr.subs(old, new))", globals))
}

///|
pub fn core_sorted_sstr(exprs : Array[@symcore.Expr]) -> String raise {
  let list = @py.PyList::new()
  for expr in exprs {
    list.append(@sympy.expr_to_sympy(expr))
  }
  let globals = @py.PyDict::new()
  globals.set("exprs", list.obj())
  py_str_obj(
    core_eval_with_globals(
      "tuple(sympy.sstr(v) for v in sorted(exprs, key=sympy.default_sort_key))",
      globals,
    ),
  )
}

///|
pub fn core_evalf_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(core_eval_with_globals("sympy.sstr(expr.evalf())", globals))
}

///|
pub fn core_match_sstr(
  pattern : @symcore.Expr,
  expr : @symcore.Expr,
) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("pattern", @sympy.expr_to_sympy(pattern))
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals(
      "('None' if pattern.matches(expr) is None else '|'.join(" +
      "f'{sympy.sstr(k)}={sympy.sstr(v)}' " +
      "for k, v in sorted(pattern.matches(expr).items(), key=lambda kv: sympy.sstr(kv[0]))))",
      globals,
    ),
  )
}

///|
pub fn core_preorder_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals(
      "tuple(sympy.sstr(v) for v in sympy.preorder_traversal(expr))", globals,
    ),
  )
}

///|
pub fn core_postorder_sstr(expr : @symcore.Expr) -> String raise {
  let globals = @py.PyDict::new()
  globals.set("expr", @sympy.expr_to_sympy(expr))
  py_str_obj(
    core_eval_with_globals(
      "tuple(sympy.sstr(v) for v in sympy.postorder_traversal(expr))", globals,
    ),
  )
}
