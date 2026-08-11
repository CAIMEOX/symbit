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
fn standard_transformations_text() -> String {
  "sympy.parsing.sympy_parser.standard_transformations"
}

///|
fn relaxed_transformations_text() -> String {
  "sympy.parsing.sympy_parser.standard_transformations + " +
  "(sympy.parsing.sympy_parser.convert_xor, " +
  "sympy.parsing.sympy_parser.implicit_multiplication_application, " +
  "sympy.parsing.sympy_parser.convert_equals_signs)"
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
  }
  py_gil_release(state)
  res
}

///|
pub fn parsing_eval_str(expr : String) -> String raise {
  py_str_obj(objenum_to_obj(parsing_eval(expr)))
}

///|
fn parsing_exec_result_str(script : String) -> String raise {
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
    let exec_callable = py_callable_from_enum(exec_obj)
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
    ignore(py_call_object(exec_callable, exec_args, print_err=true))
    let eval_args = @sympy.py_pack_args([
      @sympy.OracleArg::Str("__result__"),
      @sympy.OracleArg::PyObj(globals.obj()),
      @sympy.OracleArg::PyObj(globals.obj()),
    ])
    match py_call_object(eval_callable, eval_args, print_err=true) {
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
fn binding_lookup(
  binding_names : Array[String],
  binding_exprs : Array[String],
  name : String,
) -> String? {
  for i in 0..<binding_names.length() {
    if binding_names[i] == name {
      return Some(binding_exprs[i])
    }
  }
  None
}

///|
fn find_char_index(value : String, target : Char) -> Int? {
  let chars = value.to_array()
  for i in 0..<chars.length() {
    if chars[i] == target {
      return Some(i)
    }
  }
  None
}

///|
fn dict_literal(
  callable_names : Array[String],
  binding_names : Array[String],
  binding_exprs : Array[String],
) -> String {
  let binding_value_text = fn(expr : String) -> String {
    if expr.has_prefix("sympy.") {
      expr
    } else {
      "sympy.sympify(" + python_string_literal(expr) + ")"
    }
  }
  let entries : Array[String] = []
  for i in 0..<binding_names.length() {
    let name = python_string_literal(binding_names[i])
    entries.push(name + ": " + binding_value_text(binding_exprs[i]))
  }
  for name in callable_names {
    let rendered_name = python_string_literal(name)
    let function_name = match
      binding_lookup(binding_names, binding_exprs, name) {
      Some(expr) => "str(" + binding_value_text(expr) + ")"
      None => rendered_name
    }
    entries.push(rendered_name + ": sympy.Function(" + function_name + ")")
  }
  "{" + entries.join(", ") + "}"
}

///|
pub fn parse_expr_sstr_with(
  src : String,
  transformations : String,
  local_dict_literal : String,
  global_dict_literal : String,
  evaluate : Bool,
) -> String raise {
  let evaluate_text = if evaluate { "True" } else { "False" }
  let local_dict_clause = if local_dict_literal == "{}" {
    ""
  } else {
    ", local_dict=" + local_dict_literal
  }
  let global_dict_clause = if global_dict_literal == "{}" {
    ""
  } else {
    ", global_dict=dict(sympy.__dict__, __builtins__=__builtins__, **" +
    global_dict_literal +
    ")"
  }
  parsing_eval_str(
    "sympy.sstr(sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(src) +
    ", transformations=" +
    transformations +
    local_dict_clause +
    global_dict_clause +
    ", evaluate=" +
    evaluate_text +
    "))",
  )
}

///|
pub fn parse_expr_error_sstr_with(
  src : String,
  transformations : String,
  local_dict_literal : String,
  global_dict_literal : String,
  evaluate : Bool,
) -> String raise {
  let evaluate_text = if evaluate { "True" } else { "False" }
  let local_dict_clause = if local_dict_literal == "{}" {
    ""
  } else {
    ", local_dict=" + local_dict_literal
  }
  let global_dict_clause = if global_dict_literal == "{}" {
    ""
  } else {
    ", global_dict=dict(sympy.__dict__, __builtins__=__builtins__, **" +
    global_dict_literal +
    ")"
  }
  parsing_exec_result_str(
    "from sympy.parsing.sympy_parser import parse_expr\n" +
    "try:\n" +
    "    parse_expr(" +
    python_string_literal(src) +
    ", transformations=" +
    transformations +
    local_dict_clause +
    global_dict_clause +
    ", evaluate=" +
    evaluate_text +
    ")\n" +
    "    __result__ = 'OK'\n" +
    "except Exception as e:\n" +
    "    __result__ = type(e).__name__ + ': ' + str(e)\n",
  )
}

///|
pub fn parse_expr_sstr(src : String, evaluate? : Bool = true) -> String raise {
  parse_expr_sstr_with(
    src,
    standard_transformations_text(),
    "{}",
    "{}",
    evaluate,
  )
}

///|
pub fn parse_expr_sstr_relaxed(
  src : String,
  evaluate? : Bool = true,
) -> String raise {
  parse_expr_sstr_with(
    src,
    relaxed_transformations_text(),
    "{}",
    "{}",
    evaluate,
  )
}

///|
pub fn parse_expr_equiv(lhs_src : String, rhs_src : String) -> String raise {
  let transforms = standard_transformations_text()
  parsing_eval_str(
    "sympy.sstr(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ", transformations=" +
    transforms +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ", transformations=" +
    transforms +
    ")))",
  )
}

///|
pub fn parse_expr_equiv_relaxed(
  lhs_src : String,
  rhs_src : String,
) -> String raise {
  let transforms = relaxed_transformations_text()
  parsing_eval_str(
    "sympy.sstr(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ", transformations=" +
    transforms +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ", transformations=" +
    transforms +
    ")))",
  )
}

///|
pub fn parse_expr_equiv_relaxed_near_zero(
  lhs_src : String,
  rhs_src : String,
  tolerance? : String = "1e-12",
) -> String raise {
  let transforms = relaxed_transformations_text()
  parsing_eval_str(
    "sympy.sstr(sympy.Abs(sympy.N(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ", transformations=" +
    transforms +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ", transformations=" +
    transforms +
    ")), 50)) < sympy.Float(" +
    python_string_literal(tolerance) +
    "))",
  )
}

///|
pub fn parse_expr_equiv_in(
  lhs_src : String,
  rhs_src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
) -> String raise {
  let transforms = standard_transformations_text()
  let local_dict_literal = dict_literal(
    callable_names, binding_names, binding_exprs,
  )
  let global_dict_literal = dict_literal(
    global_callable_names, global_binding_names, global_binding_exprs,
  )
  parsing_eval_str(
    "sympy.sstr(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ", transformations=" +
    transforms +
    ", local_dict=" +
    local_dict_literal +
    ", global_dict=" +
    "dict(sympy.__dict__, __builtins__=__builtins__, **" +
    global_dict_literal +
    ")" +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ", transformations=" +
    transforms +
    ", local_dict=" +
    local_dict_literal +
    ", global_dict=" +
    "dict(sympy.__dict__, __builtins__=__builtins__, **" +
    global_dict_literal +
    ")" +
    ")))",
  )
}

///|
pub fn parse_expr_equiv_in_relaxed(
  lhs_src : String,
  rhs_src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
) -> String raise {
  let transforms = relaxed_transformations_text()
  let local_dict_literal = dict_literal(
    callable_names, binding_names, binding_exprs,
  )
  let global_dict_literal = dict_literal(
    global_callable_names, global_binding_names, global_binding_exprs,
  )
  parsing_eval_str(
    "sympy.sstr(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ", transformations=" +
    transforms +
    ", local_dict=" +
    local_dict_literal +
    ", global_dict=" +
    "dict(sympy.__dict__, __builtins__=__builtins__, **" +
    global_dict_literal +
    ")" +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ", transformations=" +
    transforms +
    ", local_dict=" +
    local_dict_literal +
    ", global_dict=" +
    "dict(sympy.__dict__, __builtins__=__builtins__, **" +
    global_dict_literal +
    ")" +
    ")))",
  )
}

///|
pub fn parse_expr_sstr_in(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
  evaluate? : Bool = true,
) -> String raise {
  parse_expr_sstr_with(
    src,
    standard_transformations_text(),
    dict_literal(callable_names, binding_names, binding_exprs),
    dict_literal(
      global_callable_names, global_binding_names, global_binding_exprs,
    ),
    evaluate,
  )
}

///|
pub fn parse_expr_error_sstr_in(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
  evaluate? : Bool = true,
) -> String raise {
  parse_expr_error_sstr_with(
    src,
    standard_transformations_text(),
    dict_literal(callable_names, binding_names, binding_exprs),
    dict_literal(
      global_callable_names, global_binding_names, global_binding_exprs,
    ),
    evaluate,
  )
}

///|
pub fn parse_expr_sstr_in_relaxed(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  global_callable_names? : Array[String] = [],
  global_binding_names? : Array[String] = [],
  global_binding_exprs? : Array[String] = [],
  evaluate? : Bool = true,
) -> String raise {
  parse_expr_sstr_with(
    src,
    relaxed_transformations_text(),
    dict_literal(callable_names, binding_names, binding_exprs),
    dict_literal(
      global_callable_names, global_binding_names, global_binding_exprs,
    ),
    evaluate,
  )
}

///|
pub fn parse_expr_split_custom_sstr(
  src : String,
  excluded_names : Array[String],
) -> String raise {
  let rendered_excluded = excluded_names.map(python_string_literal).join(", ")
  let transforms = "sympy.parsing.sympy_parser.standard_transformations + " +
    "(sympy.parsing.sympy_parser.split_symbols_custom(" +
    "(lambda symbol: symbol not in [" +
    rendered_excluded +
    "] and sympy.parsing.sympy_parser._token_splittable(symbol))" +
    "), sympy.parsing.sympy_parser.implicit_multiplication)"
  parse_expr_sstr_with(src, transforms, "{}", "{}", true)
}

///|
pub fn ast_parse_expr_sstr(
  src : String,
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
) -> String raise {
  let binding_value_text = fn(expr : String) -> String {
    if expr.has_prefix("sympy.") {
      expr
    } else {
      "sympy.sympify(" + python_string_literal(expr) + ")"
    }
  }
  let entries : Array[String] = []
  for i in 0..<binding_names.length() {
    entries.push(
      python_string_literal(binding_names[i]) +
      ": " +
      binding_value_text(binding_exprs[i]),
    )
  }
  let locals_text = "{" + entries.join(", ") + "}"
  let trimmed = src.trim().to_owned()
  if trimmed.has_prefix("lambda ") {
    let colon_idx = match find_char_index(trimmed, ':') {
      Some(idx) => idx
      None => fail("expected lambda body")
    }
    let params_text = trimmed[7:colon_idx].trim().to_owned()
    let body_text = trimmed[colon_idx + 1:].trim().to_owned()
    let params : Array[String] = []
    for param in params_text.split(",") {
      params.push(param.trim().to_owned())
    }
    let params_python = if params.length() == 1 {
      "sympy.Symbol(" + python_string_literal(params[0]) + ")"
    } else {
      "sympy.Tuple(" +
      params
      .map(param => "sympy.Symbol(" + python_string_literal(param) + ")")
      .join(", ") +
      ")"
    }
    return parsing_eval_str(
      "sympy.sstr(sympy.Lambda(" +
      params_python +
      ", __import__(" +
      python_string_literal("sympy.parsing.ast_parser") +
      ", fromlist=['parse_expr']).parse_expr(" +
      python_string_literal(body_text) +
      ", " +
      locals_text +
      ")))",
    )
  }
  parsing_eval_str(
    "sympy.sstr(__import__(" +
    python_string_literal("sympy.parsing.ast_parser") +
    ", fromlist=['parse_expr']).parse_expr(" +
    python_string_literal(src) +
    ", " +
    locals_text +
    "))",
  )
}

///|
pub fn ast_parse_expr_error_sstr(
  src : String,
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
) -> String raise {
  let binding_value_text = fn(expr : String) -> String {
    if expr.has_prefix("sympy.") {
      expr
    } else {
      "sympy.sympify(" + python_string_literal(expr) + ")"
    }
  }
  let entries : Array[String] = []
  for i in 0..<binding_names.length() {
    entries.push(
      python_string_literal(binding_names[i]) +
      ": " +
      binding_value_text(binding_exprs[i]),
    )
  }
  let locals_text = "{" + entries.join(", ") + "}"
  parsing_exec_result_str(
    "from sympy.parsing.ast_parser import parse_expr\n" +
    "try:\n" +
    "    parse_expr(" +
    python_string_literal(src) +
    ", " +
    locals_text +
    ")\n" +
    "    __result__ = 'OK'\n" +
    "except Exception as e:\n" +
    "    __result__ = type(e).__name__ + ': ' + str(e)\n",
  )
}
