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
fn sympy_expr(expr : String) -> @py.PyObjectEnum raise {
  sympy_call_must("sympy.sympify", [OracleArg::Str(expr)])
}

///|
fn sympy_str_call(
  path : String,
  expr : String,
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let expr_obj = sympy_expr(expr)
  let res = sympy_call_must(
    path,
    [OracleArg::PyObj(objenum_to_obj(expr_obj))],
    kwargs~,
  )
  py_str_enum(res)
}

///|
/// Parse a boolean expression string with SymPy and return its string form.
pub fn boolalg_str(expr : String) -> String raise {
  py_str_enum(sympy_expr(expr))
}

///|
pub fn boolalg_to_nnf(
  expr : String,
  simplify? : Bool = true,
  form? : String,
) -> String raise {
  let _ = form
  let kwargs : Map[String, OracleArg] = {
    "simplify": OracleArg::Bool(simplify),
  }
  sympy_str_call("sympy.logic.boolalg.to_nnf", expr, kwargs~)
}

///|
pub fn boolalg_to_cnf(
  expr : String,
  simplify? : Bool = false,
  force? : Bool = false,
) -> String raise {
  let kwargs : Map[String, OracleArg] = {
    "simplify": OracleArg::Bool(simplify),
    "force": OracleArg::Bool(force),
  }
  sympy_str_call("sympy.logic.boolalg.to_cnf", expr, kwargs~)
}

///|
pub fn boolalg_to_dnf(
  expr : String,
  simplify? : Bool = false,
  force? : Bool = false,
) -> String raise {
  let kwargs : Map[String, OracleArg] = {
    "simplify": OracleArg::Bool(simplify),
    "force": OracleArg::Bool(force),
  }
  sympy_str_call("sympy.logic.boolalg.to_dnf", expr, kwargs~)
}

///|
pub fn boolalg_to_anf(expr : String, deep? : Bool = true) -> String raise {
  let kwargs : Map[String, OracleArg] = { "deep": OracleArg::Bool(deep) }
  sympy_str_call("sympy.logic.boolalg.to_anf", expr, kwargs~)
}

///|
pub fn boolalg_eliminate_implications(
  expr : String,
  form? : String,
) -> String raise {
  let _ = form
  sympy_str_call("sympy.logic.boolalg.eliminate_implications", expr)
}

///|
pub fn boolalg_is_cnf(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.is_cnf", expr)
}

///|
pub fn boolalg_is_dnf(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.is_dnf", expr)
}

///|
pub fn boolalg_is_nnf(expr : String, simplified? : Bool = true) -> String raise {
  let kwargs : Map[String, OracleArg] = {
    "simplified": OracleArg::Bool(simplified),
  }
  sympy_str_call("sympy.logic.boolalg.is_nnf", expr, kwargs~)
}

///|
pub fn boolalg_is_anf(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.is_anf", expr)
}

///|
pub fn boolalg_distribute_and_over_or(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.distribute_and_over_or", expr)
}

///|
pub fn boolalg_distribute_or_over_and(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.distribute_or_over_and", expr)
}

///|
pub fn boolalg_distribute_xor_over_and(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.distribute_xor_over_and", expr)
}

///|
fn sympy_symbols_from_names(names : Array[String]) -> Array[OracleArg] raise {
  let out : Array[OracleArg] = Array::new()
  for name in names {
    let obj = sympy_expr(name)
    out.push(OracleArg::PyObj(objenum_to_obj(obj)))
  }
  out
}

///|
pub fn boolalg_sop_form_ints(
  variables : Array[String],
  minterms : Array[Int],
  dontcares? : Array[Int],
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [var_list, OracleArg::IntList(minterms)]
  match dontcares {
    Some(dc) => args.push(OracleArg::IntList(dc))
    None => ()
  }
  let res = sympy_call_must("sympy.logic.boolalg.SOPform", args)
  py_str_enum(res)
}

///|
pub fn boolalg_pos_form_ints(
  variables : Array[String],
  minterms : Array[Int],
  dontcares? : Array[Int],
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [var_list, OracleArg::IntList(minterms)]
  match dontcares {
    Some(dc) => args.push(OracleArg::IntList(dc))
    None => ()
  }
  let res = sympy_call_must("sympy.logic.boolalg.POSform", args)
  py_str_enum(res)
}

///|
pub fn boolalg_anf_form(
  variables : Array[String],
  truthvalues : Array[Int],
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [var_list, OracleArg::IntList(truthvalues)]
  let res = sympy_call_must("sympy.logic.boolalg.ANFform", args)
  py_str_enum(res)
}

///|
pub fn boolalg_simplify_logic(
  expr : String,
  form? : String,
  deep? : Bool = true,
  force? : Bool = false,
  dontcare? : String,
) -> String raise {
  let kwargs : Map[String, OracleArg] = {
    "deep": OracleArg::Bool(deep),
    "force": OracleArg::Bool(force),
  }
  match form {
    Some(v) => kwargs["form"] = OracleArg::Str(v)
    None => ()
  }
  match dontcare {
    Some(dc) => {
      let dc_obj = sympy_expr(dc)
      kwargs["dontcare"] = OracleArg::PyObj(objenum_to_obj(dc_obj))
    }
    None => ()
  }
  sympy_str_call("sympy.logic.boolalg.simplify_logic", expr, kwargs~)
}

///|
pub fn boolalg_gateinputcount(expr : String) -> String raise {
  sympy_str_call("sympy.logic.boolalg.gateinputcount", expr)
}

///|
pub fn boolalg_bool_map(expr1 : String, expr2 : String) -> String raise {
  let obj1 = sympy_expr(expr1)
  let obj2 = sympy_expr(expr2)
  let res = sympy_call_must("sympy.logic.boolalg.bool_map", [
    OracleArg::PyObj(objenum_to_obj(obj1)),
    OracleArg::PyObj(objenum_to_obj(obj2)),
  ])
  py_str_enum(res)
}

///|
pub fn boolalg_bool_minterm_int(
  variables : Array[String],
  k : Int,
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [OracleArg::Int(k), var_list]
  let res = sympy_call_must("sympy.logic.boolalg.bool_minterm", args)
  py_str_enum(res)
}

///|
pub fn boolalg_bool_minterm_bits(
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [OracleArg::IntList(bits), var_list]
  let res = sympy_call_must("sympy.logic.boolalg.bool_minterm", args)
  py_str_enum(res)
}

///|
pub fn boolalg_bool_maxterm_int(
  variables : Array[String],
  k : Int,
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [OracleArg::Int(k), var_list]
  let res = sympy_call_must("sympy.logic.boolalg.bool_maxterm", args)
  py_str_enum(res)
}

///|
pub fn boolalg_bool_maxterm_bits(
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [OracleArg::IntList(bits), var_list]
  let res = sympy_call_must("sympy.logic.boolalg.bool_maxterm", args)
  py_str_enum(res)
}

///|
pub fn boolalg_bool_monomial_int(
  variables : Array[String],
  k : Int,
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [OracleArg::Int(k), var_list]
  let res = sympy_call_must("sympy.logic.boolalg.bool_monomial", args)
  py_str_enum(res)
}

///|
pub fn boolalg_bool_monomial_bits(
  variables : Array[String],
  bits : Array[Int],
) -> String raise {
  let var_list = OracleArg::List(sympy_symbols_from_names(variables))
  let args : Array[OracleArg] = [OracleArg::IntList(bits), var_list]
  let res = sympy_call_must("sympy.logic.boolalg.bool_monomial", args)
  py_str_enum(res)
}
