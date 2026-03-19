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

///|
pub fn parse_expr_equiv_stage2(
  lhs_src : String,
  rhs_src : String,
) -> String raise {
  let transforms = "sympy.parsing.sympy_parser.standard_transformations + " +
    "(sympy.parsing.sympy_parser.implicit_multiplication_application, " +
    "sympy.parsing.sympy_parser.factorial_notation, " +
    "sympy.parsing.sympy_parser.convert_equals_signs)"
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
fn locals_literal(
  callable_names : Array[String],
  binding_names : Array[String],
  binding_exprs : Array[String],
) -> String {
  let entries : Array[String] = []
  for i in 0..<binding_names.length() {
    let name = python_string_literal(binding_names[i])
    let expr = python_string_literal(binding_exprs[i])
    entries.push(name + ": sympy.sympify(" + expr + ")")
  }
  for name in callable_names {
    let rendered_name = python_string_literal(name)
    let function_name = match
      binding_lookup(binding_names, binding_exprs, name) {
      Some(expr) => "str(sympy.sympify(" + python_string_literal(expr) + "))"
      None => rendered_name
    }
    entries.push(rendered_name + ": sympy.Function(" + function_name + ")")
  }
  "{" + entries.join(", ") + "}"
}

///|
fn parse_expr_sstr_with(
  src : String,
  transformations : String,
  local_dict_literal : String,
  evaluate : Bool,
) -> String raise {
  let evaluate_text = if evaluate { "True" } else { "False" }
  let local_dict_clause = if local_dict_literal == "{}" {
    ""
  } else {
    ", local_dict=" + local_dict_literal
  }
  parsing_eval_str(
    "sympy.sstr(sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(src) +
    ", transformations=" +
    transformations +
    local_dict_clause +
    ", evaluate=" +
    evaluate_text +
    "))",
  )
}

///|
pub fn parse_expr_equiv_stage3(
  lhs_src : String,
  rhs_src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
) -> String raise {
  let transforms = "sympy.parsing.sympy_parser.standard_transformations + " +
    "(sympy.parsing.sympy_parser.implicit_multiplication_application, " +
    "sympy.parsing.sympy_parser.factorial_notation, " +
    "sympy.parsing.sympy_parser.convert_equals_signs)"
  let local_dict_literal = locals_literal(
    callable_names, binding_names, binding_exprs,
  )
  parsing_eval_str(
    "sympy.sstr(sympy.simplify(" +
    "sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(lhs_src) +
    ", transformations=" +
    transforms +
    ", local_dict=" +
    local_dict_literal +
    ") - sympy.parsing.sympy_parser.parse_expr(" +
    python_string_literal(rhs_src) +
    ", transformations=" +
    transforms +
    ", local_dict=" +
    local_dict_literal +
    ")))",
  )
}

///|
pub fn parse_expr_sstr_stage2(
  src : String,
  evaluate? : Bool = true,
) -> String raise {
  let transforms = "sympy.parsing.sympy_parser.standard_transformations + " +
    "(sympy.parsing.sympy_parser.implicit_multiplication_application, " +
    "sympy.parsing.sympy_parser.factorial_notation, " +
    "sympy.parsing.sympy_parser.convert_equals_signs)"
  parse_expr_sstr_with(src, transforms, "{}", evaluate)
}

///|
pub fn parse_expr_sstr_stage3(
  src : String,
  callable_names : Array[String],
  binding_names? : Array[String] = [],
  binding_exprs? : Array[String] = [],
  evaluate? : Bool = true,
) -> String raise {
  let transforms = "sympy.parsing.sympy_parser.standard_transformations + " +
    "(sympy.parsing.sympy_parser.implicit_multiplication_application, " +
    "sympy.parsing.sympy_parser.factorial_notation, " +
    "sympy.parsing.sympy_parser.convert_equals_signs)"
  parse_expr_sstr_with(
    src,
    transforms,
    locals_literal(callable_names, binding_names, binding_exprs),
    evaluate,
  )
}
