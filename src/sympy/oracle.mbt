///|
pub(all) enum OracleArg {
  Null
  Str(String)
  Int(Int)
  Bool(Bool)
  StrList(Array[String])
  IntList(Array[Int])
  List(Array[OracleArg])
  Dict(Map[String, OracleArg])
}

///|
const ORACLE_PATH : String = "/Users/caimeo/code/learning/sym-workspace/symbit/src/sympy:/Users/caimeo/code/learning/sym-workspace/symbit:/Users/caimeo/code/learning/sym-workspace"

///|
#borrow(payload_json, oracle_path)
extern "C" fn sympy_oracle_exec(
  payload_json : String,
  oracle_path : String,
) -> String = "sympy_oracle_exec"

///|/// JSON-escape a string (minimal subset needed for test payloads).
fn json_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for ch in s {
    match ch {
      '"' => sb.write_view("\\\"")
      '\\' => sb.write_view("\\\\")
      '\n' => sb.write_view("\\n")
      '\r' => sb.write_view("\\r")
      '\t' => sb.write_view("\\t")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn json_string(s : String) -> String {
  let escaped = json_escape(s)
  let sb = StringBuilder::new()
  sb..write_char('"')..write_view(escaped)..write_char('"')
  sb.to_string()
}

///|
fn oracle_arg_json(arg : OracleArg) -> String {
  match arg {
    OracleArg::Null => "null"
    OracleArg::Str(s) => json_string(s)
    OracleArg::Int(n) => n.to_string()
    OracleArg::Bool(b) => if b { "true" } else { "false" }
    OracleArg::StrList(list) => {
      let sb = StringBuilder::new()
      sb.write_char('[')
      for i in 0..<list.length() {
        if i > 0 {
          sb.write_char(',')
        }
        sb.write_view(json_string(list[i]))
      }
      sb.write_char(']')
      sb.to_string()
    }
    OracleArg::IntList(list) => {
      let sb = StringBuilder::new()
      sb.write_char('[')
      for i in 0..<list.length() {
        if i > 0 {
          sb.write_char(',')
        }
        sb.write_view(list[i].to_string())
      }
      sb.write_char(']')
      sb.to_string()
    }
    OracleArg::List(list) => {
      let sb = StringBuilder::new()
      sb.write_char('[')
      for i in 0..<list.length() {
        if i > 0 {
          sb.write_char(',')
        }
        sb.write_view(oracle_arg_json(list[i]))
      }
      sb.write_char(']')
      sb.to_string()
    }
    OracleArg::Dict(map) => {
      let sb = StringBuilder::new()
      sb.write_char('{')
      let mut first = true
      for k, v in map {
        if first {
          first = false
        } else {
          sb.write_char(',')
        }
        sb
        ..write_view(json_string(k))
        ..write_char(':')
        ..write_view(oracle_arg_json(v))
      }
      sb.write_char('}')
      sb.to_string()
    }
  }
}

///|/// Build the JSON payload passed to the external SymPy oracle process.
fn oracle_payload_json(
  func : String,
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> String {
  let sb = StringBuilder::new()
  sb
  ..write_char('{')
  ..write_view("\"func\":")
  ..write_view(json_string(func))
  ..write_view(",\"args\":[")
  for i in 0..<args.length() {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_view(oracle_arg_json(args[i]))
  }
  sb..write_view("],\"kwargs\":{")
  let mut first = true
  for k, v in kwargs {
    if first {
      first = false
    } else {
      sb.write_char(',')
    }
    sb
    ..write_view(json_string(k))
    ..write_char(':')
    ..write_view(oracle_arg_json(v))
  }
  sb..write_view("}}")
  sb.to_string()
}

///|
fn strip_trailing_newline(s : String) -> String {
  s.trim_end(chars="\r\n").to_string()
}

///|/// Remove all spaces to make string comparison insensitive to formatting.
pub fn normalize_spaces(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
pub fn canonical_cmp(s : String) -> String {
  let mut t = normalize_spaces(s)
  t = t.replace_all(old="2+x", new="x+2")
  t = t.replace_all(old="3+x", new="x+3")
  t = t.replace_all(old="-1+x", new="x-1")
  t = t.replace_all(old="1+x", new="x+1")
  t = t.replace_all(old="1+x**2", new="x**2+1")
  t = t.replace_all(old="-1+y", new="y-1")
  t = t.replace_all(old="1+y", new="y+1")
  t
}

///|/// Canonicalise an expression string via `str(sympy.sympify(expr))` so that
/// ordering matches SymPy’s printer (helps when our printer orders constants
/// first).
pub fn sympy_normalize(expr_str : String) -> String raise {
  sympy_oracle_call("normalize_expr_str", [OracleArg::Str(expr_str)])
}

///|
fn ensure_python() -> Unit {
  if !@cpython.py_is_initialized() {
    @py.init_py()
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
}

///|
let builtins_cache : Ref[@py.PyModule?] = { val: None }

///|
let sympy_cache : Ref[@py.PyModule?] = { val: None }

///|
let operator_cache : Ref[@py.PyModule?] = { val: None }

///|
fn ensure_builtins_module() -> @py.PyModule raise {
  ensure_python()
  match builtins_cache.val {
    Some(mod) => mod
    None => {
      let state = py_gil_ensure()
      let mod = match @py.pyimport("builtins") {
        Some(m) => m
        None => {
          py_gil_release(state)
          fail("builtins-missing")
        }
      }
      py_gil_release(state)
      builtins_cache.val = Some(mod)
      mod
    }
  }
}

///|
fn ensure_sympy_module_oracle() -> @py.PyModule raise {
  ensure_python()
  match sympy_cache.val {
    Some(mod) => mod
    None => {
      let state = py_gil_ensure()
      let mod = match @py.pyimport("sympy") {
        Some(m) => m
        None => {
          py_gil_release(state)
          fail("sympy-missing")
        }
      }
      py_gil_release(state)
      sympy_cache.val = Some(mod)
      mod
    }
  }
}

///|
fn ensure_operator_module() -> @py.PyModule raise {
  ensure_python()
  match operator_cache.val {
    Some(mod) => mod
    None => {
      let state = py_gil_ensure()
      let mod = match @py.pyimport("operator") {
        Some(m) => m
        None => {
          py_gil_release(state)
          fail("operator-missing")
        }
      }
      py_gil_release(state)
      operator_cache.val = Some(mod)
      mod
    }
  }
}

///|
fn resolve_callable(mod : @py.PyModule, name : String) -> @py.PyCallable raise {
  let state = py_gil_ensure()
  let res = try {
    match mod.get_attr(name, print_err=false) {
      Some(PyCallable(callable)) => callable
      Some(PyClass(obj)) =>
        @py.PyCallable::create(obj) catch { _ => fail("sympy-oracle-callable") }
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
  py_gil_release(state)
  res
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
        @py.PyCallable::create(obj0) catch { _ => fail("sympy-oracle-callable") }
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
  py_gil_release(state)
  res
}

///|
fn py_tuple_from_objects(values : Array[@py.PyObject]) -> @py.PyTuple {
  let state = py_gil_ensure()
  let tup = @py.PyTuple::new(values.length().to_uint64())
  for i in 0..<values.length() {
    tuple_set_borrowed(tup, i, values[i])
  }
  py_gil_release(state)
  tup
}

///|
fn py_list_from_objects(values : Array[@py.PyObject]) -> @py.PyList {
  let state = py_gil_ensure()
  let list = @py.PyList::new()
  for v in values {
    list.append(v)
  }
  py_gil_release(state)
  list
}

///|
fn py_dict_len(dict : @py.PyDict) -> Int {
  let state = py_gil_ensure()
  let n = dict.len()
  py_gil_release(state)
  n
}

///|
fn py_dict_new() -> @py.PyDict {
  let state = py_gil_ensure()
  let dict = @py.PyDict::new()
  py_gil_release(state)
  dict
}

///|
fn py_string_obj(s : String) -> @py.PyObject {
  let state = py_gil_ensure()
  let obj = @py.PyString::from(s).obj()
  // Keep the object alive beyond the temporary PyString wrapper.
  @cpython.py_incref(obj.obj_ref())
  py_gil_release(state)
  obj
}

///|
fn py_int_obj(n : Int) -> @py.PyObject {
  let state = py_gil_ensure()
  let obj = @py.PyInteger::from(n.to_int64()).obj()
  // Keep the object alive beyond the temporary PyInteger wrapper.
  @cpython.py_incref(obj.obj_ref())
  py_gil_release(state)
  obj
}

///|
fn py_dict_set_obj(dict : @py.PyDict, key : String, value : @py.PyObject) -> Unit {
  let state = py_gil_ensure()
  dict.set(key, value)
  py_gil_release(state)
}

///|
fn py_get_attr(obj : @py.PyObject, name : String) -> @py.PyObjectEnum? {
  let state = py_gil_ensure()
  let res = obj.get_attr(name, print_err=false)
  py_gil_release(state)
  res
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[@py.PyObject],
  kwargs : @py.PyDict,
) -> @py.PyObjectEnum raise {
  let tup = py_tuple_from_objects(args)
  let res =
    if py_dict_len(kwargs) == 0 {
      py_call_object(callable, tup, print_err=true)
    } else {
      py_call_object_kwargs(
        callable,
        tup,
        kwargs=kwargs,
        print_err=true,
      )
    }
  match res {
    Some(obj) => obj
    None => fail("sympy-oracle-call-none")
  }
}

///|
fn py_call_noargs(callable : @py.PyCallable) -> @py.PyObjectEnum raise {
  py_call_with_args(callable, [], py_dict_new())
}

///|
fn py_call_one(
  callable : @py.PyCallable,
  arg : @py.PyObject,
) -> @py.PyObjectEnum raise {
  py_call_with_args(callable, [arg], py_dict_new())
}

///|
fn py_call_two(
  callable : @py.PyCallable,
  arg0 : @py.PyObject,
  arg1 : @py.PyObject,
) -> @py.PyObjectEnum raise {
  py_call_with_args(callable, [arg0, arg1], py_dict_new())
}

///|
fn py_call_one_kwargs(
  callable : @py.PyCallable,
  arg : @py.PyObject,
  kwargs : @py.PyDict,
) -> @py.PyObjectEnum raise {
  py_call_with_args(callable, [arg], kwargs)
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
fn py_repr_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = @cpython.py_object_moonbit_repr(obj.obj_ref())
  py_gil_release(state)
  s
}

///|
fn py_repr_enum(obj : @py.PyObjectEnum) -> String {
  py_repr_obj(objenum_to_obj(obj))
}

///|
fn py_is_none(obj : @py.PyObject) -> Bool {
  let state = py_gil_ensure()
  let ok = @cpython.py_none_check(obj.obj_ref())
  py_gil_release(state)
  ok
}

///|
fn py_isinstance(obj : @py.PyObject, cls : @py.PyObject) -> Bool {
  let state = py_gil_ensure()
  let res = @cpython.py_object_is_instance(obj.obj_ref(), cls.obj_ref())
  if res < 0 {
    @cpython.py_err_clear()
    py_gil_release(state)
    false
  } else {
    let ok = res != 0
    py_gil_release(state)
    ok
  }
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
fn sympy_srepr(expr : @py.PyObject) -> String raise {
  let sympy = ensure_sympy_module_oracle()
  let srepr = resolve_callable(sympy, "srepr")
  let res = py_call_one(srepr, expr)
  py_str_enum(res)
}

///|
fn sympy_sympify_str(expr_str : String) -> @py.PyObject raise {
  let sympy = ensure_sympy_module_oracle()
  let sympify = resolve_callable(sympy, "sympify")
  let res = py_call_one(sympify, py_string_obj(expr_str))
  objenum_to_obj(res)
}

///|
fn sympy_symbol_obj(name : String) -> @py.PyObject raise {
  let sympy = ensure_sympy_module_oracle()
  let symbols = resolve_callable(sympy, "symbols")
  let res = py_call_one(symbols, py_string_obj(name))
  objenum_to_obj(res)
}

///|
fn sympy_symbols_from_names(names : Array[String]) -> Array[@py.PyObject] raise {
  let out : Array[@py.PyObject] = Array::new()
  for name in names {
    out.push(sympy_symbol_obj(name))
  }
  out
}

///|
fn sympy_symbols_from_string(spec : String) -> Array[@py.PyObject] raise {
  let obj = sympy_symbol_obj(spec)
  let state = py_gil_ensure()
  let kind = @py.PyObjectEnum::create(obj)
  py_gil_release(state)
  match kind {
    PyList(_) | PyTuple(_) => py_list_to_pyobjects(kind)
    _ => [obj]
  }
}

///|
fn sympy_default_gens(exprs : Array[@py.PyObject]) -> Array[@py.PyObject] raise {
  let builtins = ensure_builtins_module()
  let set_ctor = resolve_callable(builtins, "set")
  let set_enum = py_call_noargs(set_ctor)
  let set_obj = objenum_to_obj(set_enum)
  let update = resolve_method_callable(set_obj, "update")
  for expr in exprs {
    match py_get_attr(expr, "free_symbols") {
      Some(fs) => {
        let fs_obj = objenum_to_obj(fs)
        let tup = py_tuple_from_objects([fs_obj])
        let _ = py_call_object_allow_none(update, tup, print_err=true)
      }
      None => ()
    }
  }
  let operator = ensure_operator_module()
  let attrgetter = resolve_callable(operator, "attrgetter")
  let key_enum = py_call_one(attrgetter, py_string_obj("name"))
  let key_obj = objenum_to_obj(key_enum)
  let sorted = resolve_callable(builtins, "sorted")
  let kwargs = py_dict_new()
  py_dict_set_obj(kwargs, "key", key_obj)
  let list_enum = py_call_one_kwargs(sorted, set_obj, kwargs)
  py_list_to_pyobjects(list_enum)
}

///|
fn oracle_arg_as_str(arg : OracleArg) -> String raise {
  match arg {
    OracleArg::Str(s) => s
    OracleArg::Int(n) => n.to_string()
    OracleArg::Bool(b) => if b { "True" } else { "False" }
    OracleArg::Null => "None"
    _ => fail("expected string")
  }
}

///|
fn oracle_arg_as_str_list(arg : OracleArg) -> Array[String] raise {
  match arg {
    OracleArg::StrList(list) => list
    OracleArg::Str(s) => [s]
    OracleArg::List(list) => {
      let out : Array[String] = Array::new()
      for item in list {
        out.push(oracle_arg_as_str(item))
      }
      out
    }
    _ => fail("expected string list")
  }
}

///|
fn kwargs_get_str(
  kwargs : Map[String, OracleArg],
  key : String,
) -> String? {
  match kwargs.get(key) {
    Some(OracleArg::Str(s)) => Some(s)
    Some(OracleArg::Int(n)) => Some(n.to_string())
    Some(OracleArg::Bool(b)) => Some(if b { "True" } else { "False" })
    _ => None
  }
}

///|
fn kwargs_get_int(
  kwargs : Map[String, OracleArg],
  key : String,
) -> Int? raise {
  match kwargs.get(key) {
    Some(OracleArg::Int(n)) => Some(n)
    Some(OracleArg::Str(s)) => Some(@strconv.parse_int(s))
    _ => None
  }
}

///|
fn kwargs_get_str_list(
  kwargs : Map[String, OracleArg],
  key : String,
) -> Array[String]? raise {
  match kwargs.get(key) {
    Some(OracleArg::StrList(list)) => Some(list)
    Some(OracleArg::Str(s)) => Some([s])
    Some(OracleArg::List(list)) => {
      let out : Array[String] = Array::new()
      for item in list {
        out.push(oracle_arg_as_str(item))
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn kwargs_get_gens(
  kwargs : Map[String, OracleArg],
) -> Array[@py.PyObject]? raise {
  match kwargs.get("gens") {
    Some(OracleArg::StrList(list)) => Some(sympy_symbols_from_names(list))
    Some(OracleArg::Str(s)) => Some(sympy_symbols_from_string(s))
    Some(OracleArg::List(list)) => {
      let names : Array[String] = Array::new()
      for item in list {
        names.push(oracle_arg_as_str(item))
      }
      Some(sympy_symbols_from_names(names))
    }
    _ => None
  }
}

///|
fn sympy_sympify_arg(arg : OracleArg) -> @py.PyObject raise {
  let s = oracle_arg_as_str(arg)
  sympy_sympify_str(s)
}

///|
fn py_encode_object(obj : @py.PyObject) -> Json raise {
  if py_is_none(obj) {
    return Json::null()
  }
  let sympy = ensure_sympy_module_oracle()
  let poly_cls = match sympy.get_attr("Poly", print_err=false) {
    Some(v) => Some(objenum_to_obj(v))
    None => None
  }
  match poly_cls {
    Some(cls) =>
      if py_isinstance(obj, cls) {
        let as_expr = resolve_method_callable(obj, "as_expr")
        let expr_enum = py_call_noargs(as_expr)
        let expr_obj = objenum_to_obj(expr_enum)
        let s = py_str_obj(expr_obj)
        let sr = sympy_srepr(expr_obj)
        let out : Map[String, Json] = {}
        out["__sympy__"] = Json::boolean(true)
        out["str"] = Json::string(s)
        out["srepr"] = Json::string(sr)
        return Json::object(out)
      }
    None => ()
  }
  let basic_cls = match sympy.get_attr("Basic", print_err=false) {
    Some(v) => Some(objenum_to_obj(v))
    None => None
  }
  match basic_cls {
    Some(cls) =>
      if py_isinstance(obj, cls) {
        let s = py_str_obj(obj)
        let sr = sympy_srepr(obj)
        let out : Map[String, Json] = {}
        out["__sympy__"] = Json::boolean(true)
        out["str"] = Json::string(s)
        out["srepr"] = Json::string(sr)
        return Json::object(out)
      }
    None => ()
  }
  let repr = py_repr_obj(obj)
  let out : Map[String, Json] = {}
  out["__repr__"] = Json::string(repr)
  Json::object(out)
}

///|
fn py_encode_result_inner(value : @py.PyObjectEnum) -> Json raise {
  match value {
    PyBool(v) => Json::boolean(v.to_bool())
    PyInteger(v) => {
      let i = v.to_int64()
      Json::number(i.to_double(), repr=i.to_string())
    }
    PyFloat(v) => Json::number(v.to_double())
    PyString(v) => Json::string(v.to_string())
    PyList(list) => {
      let len = list.len()
      let out : Array[Json] = Array::new()
      for i in 0..<len {
        match list.get(i) {
          Some(item) => out.push(py_encode_result_inner(item))
          None => ()
        }
      }
      Json::array(out)
    }
    PyTuple(tup) => {
      let len = tup.len().to_int()
      let out : Array[Json] = Array::new()
      for i in 0..<len {
        match tup.get(i) {
          Some(item) => out.push(py_encode_result_inner(item))
          None => ()
        }
      }
      Json::array(out)
    }
    PyDict(dict) => {
      let items = dict.items()
      let out : Map[String, Json] = {}
      let len = items.len()
      for i in 0..<len {
        match items.get(i) {
          Some(PyTuple(tup)) => {
            if tup.len().to_int() == 2 {
              match (tup.get(0), tup.get(1)) {
                (Some(k0), Some(v0)) => {
                  let key : String = py_str_enum(k0)
                  out[key] = py_encode_result_inner(v0)
                }
                _ => ()
              }
            }
          }
          Some(other) => {
            let key : String = py_str_enum(other)
            out[key] = Json::null()
          }
          None => ()
        }
      }
      Json::object(out)
    }
    PyModule(v) => {
      let obj = v.obj()
      @cpython.py_incref(obj.obj_ref())
      py_encode_object(obj)
    }
    PyCallable(v) => {
      let obj = v.obj()
      @cpython.py_incref(obj.obj_ref())
      py_encode_object(obj)
    }
    PyClass(obj) => {
      @cpython.py_incref(obj.obj_ref())
      py_encode_object(obj)
    }
  }
}

///|
fn py_encode_result(value : @py.PyObjectEnum) -> Json raise {
  let state = py_gil_ensure()
  let res = try py_encode_result_inner(value) catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn call_sympy_factor_list_json(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 1 else { fail("factor_list_json args") }
  let expr = sympy_sympify_arg(args[0])
  let modulus0 = kwargs_get_int(kwargs, "modulus")
  let modulus = match modulus0 {
    Some(m) => Some(m)
    None =>
      if args.length() > 1 {
        match args[1] {
          OracleArg::Int(n) => Some(n)
          OracleArg::Str(s) => Some(@strconv.parse_int(s))
          _ => None
        }
      } else {
        None
      }
  }
  let sympy = ensure_sympy_module_oracle()
  let factor_list = resolve_callable(sympy, "factor_list")
  let kwargs_dict = py_dict_new()
  match modulus {
    Some(m) => py_dict_set_obj(kwargs_dict, "modulus", py_int_obj(m))
    None => ()
  }
  let res = py_call_with_args(factor_list, [expr], kwargs_dict)
  py_encode_result(res)
}

///|
fn call_sympy_sympify_list_json(
  args : Array[OracleArg],
) -> Json raise {
  guard args.length() >= 1 else { fail("sympify_list_json args") }
  let exprs = oracle_arg_as_str_list(args[0])
  let sympy = ensure_sympy_module_oracle()
  let sympify = resolve_callable(sympy, "sympify")
  let out : Array[Json] = Array::new()
  for expr in exprs {
    let res = py_call_one(sympify, py_string_obj(expr))
    out.push(py_encode_result(res))
  }
  Json::array(out)
}

///|
fn call_sympy_poly(
  expr : @py.PyObject,
  gens : Array[@py.PyObject],
  domain : String,
  modulus : Int?,
) -> @py.PyObject raise {
  let sympy = ensure_sympy_module_oracle()
  let poly = resolve_callable(sympy, "Poly")
  let args : Array[@py.PyObject] = Array::new()
  args.push(expr)
  for g in gens {
    args.push(g)
  }
  let kwargs = py_dict_new()
  if domain != "" {
    py_dict_set_obj(kwargs, "domain", py_string_obj(domain))
  }
  match modulus {
    Some(m) => py_dict_set_obj(kwargs, "modulus", py_int_obj(m))
    None => ()
  }
  let res = py_call_with_args(poly, args, kwargs)
  objenum_to_obj(res)
}

///|
fn call_sympy_polys_gcd(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 2 else { fail("polys gcd args") }
  let a = sympy_sympify_arg(args[0])
  let b = sympy_sympify_arg(args[1])
  let gens0 = kwargs_get_gens(kwargs)
  let domain = match kwargs_get_str(kwargs, "domain") {
    Some(s) => s
    None => ""
  }
  let modulus = kwargs_get_int(kwargs, "modulus")
  let gens = match gens0 {
    Some(list) => list
    None => sympy_default_gens([a, b])
  }
  if gens.length() > 0 && (domain != "" || modulus is Some(_)) {
    let pa = call_sympy_poly(a, gens, domain, modulus)
    let pb = call_sympy_poly(b, gens, domain, modulus)
    let gcd = resolve_method_callable(pa, "gcd")
    let res = py_call_one(gcd, pb)
    py_encode_result(res)
  } else {
    let sympy = ensure_sympy_module_oracle()
    let gcd = resolve_callable(sympy, "gcd")
    let res = py_call_two(gcd, a, b)
    py_encode_result(res)
  }
}

///|
fn call_sympy_polys_resultant(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 2 else { fail("polys resultant args") }
  let p = sympy_sympify_arg(args[0])
  let q = sympy_sympify_arg(args[1])
  let var_name = match kwargs_get_str(kwargs, "var") {
    Some(s) => s
    None => ""
  }
  let mut var_obj : @py.PyObject? = None
  if var_name != "" {
    var_obj = Some(sympy_sympify_str(var_name))
  }
  let gens0 = kwargs_get_gens(kwargs)
  let domain = match kwargs_get_str(kwargs, "domain") {
    Some(s) => s
    None => ""
  }
  let modulus = kwargs_get_int(kwargs, "modulus")
  let gens = match gens0 {
    Some(list) => list
    None => {
      let seed : Array[@py.PyObject] = Array::new()
      seed.push(p)
      seed.push(q)
      match var_obj {
        Some(v) => seed.push(v)
        None => ()
      }
      sympy_default_gens(seed)
    }
  }
  if gens.length() > 0 && (domain != "" || modulus is Some(_)) {
    let pa = call_sympy_poly(p, gens, domain, modulus)
    let pb = call_sympy_poly(q, gens, domain, modulus)
    let resultant = resolve_method_callable(pa, "resultant")
    let res = match var_obj {
      Some(v) => {
        let kwargs_dict = py_dict_new()
        py_dict_set_obj(kwargs_dict, "var", v)
        py_call_one_kwargs(resultant, pb, kwargs_dict)
      }
      None => py_call_one(resultant, pb)
    }
    py_encode_result(res)
  } else {
    if var_obj is None {
      if gens.length() > 0 {
        var_obj = Some(gens[0])
      } else {
        fail("resultant requires a variable")
      }
    }
    let sympy = ensure_sympy_module_oracle()
    let resultant = resolve_callable(sympy, "resultant")
    let args0 : Array[@py.PyObject] = Array::new()
    args0.push(p)
    args0.push(q)
    match var_obj {
      Some(v) => args0.push(v)
      None => ()
    }
    let kwargs_dict = py_dict_new()
    match modulus {
      Some(m) => py_dict_set_obj(kwargs_dict, "modulus", py_int_obj(m))
      None => ()
    }
    let res = py_call_with_args(resultant, args0, kwargs_dict)
    py_encode_result(res)
  }
}

///|
fn call_sympy_polys_groebner(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 1 else { fail("polys groebner args") }
  let exprs = oracle_arg_as_str_list(args[0])
  let polys : Array[@py.PyObject] = Array::new()
  for expr in exprs {
    polys.push(sympy_sympify_str(expr))
  }
  let gens0 = kwargs_get_gens(kwargs)
  let gens = match gens0 {
    Some(list) => list
    None => sympy_default_gens(polys)
  }
  let order = match kwargs_get_str(kwargs, "order") {
    Some(s) => s
    None => ""
  }
  let domain = match kwargs_get_str(kwargs, "domain") {
    Some(s) => s
    None => ""
  }
  let modulus = kwargs_get_int(kwargs, "modulus")
  let sympy = ensure_sympy_module_oracle()
  let groebner = resolve_callable(sympy, "groebner")
  let args0 : Array[@py.PyObject] = Array::new()
  let py_polys = py_list_from_objects(polys)
  let py_polys_obj = py_polys.obj()
  @cpython.py_incref(py_polys_obj.obj_ref())
  args0.push(py_polys_obj)
  for g in gens {
    args0.push(g)
  }
  let kwargs_dict = py_dict_new()
  if order != "" {
    py_dict_set_obj(kwargs_dict, "order", py_string_obj(order))
  }
  if domain != "" {
    py_dict_set_obj(kwargs_dict, "domain", py_string_obj(domain))
  }
  match modulus {
    Some(m) => py_dict_set_obj(kwargs_dict, "modulus", py_int_obj(m))
    None => ()
  }
  let res = py_call_with_args(groebner, args0, kwargs_dict)
  let res_obj = objenum_to_obj(res)
  match py_get_attr(res_obj, "polys") {
    Some(polys_enum) => py_encode_result(polys_enum)
    None => fail("groebner.polys missing")
  }
}

///|
fn call_sympy_polys_factor(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 1 else { fail("polys factor args") }
  let expr = sympy_sympify_arg(args[0])
  let gens0 = kwargs_get_gens(kwargs)
  let domain = match kwargs_get_str(kwargs, "domain") {
    Some(s) => s
    None => ""
  }
  let modulus = kwargs_get_int(kwargs, "modulus")
  if gens0 is Some(_) || domain != "" || modulus is Some(_) {
    let gens = match gens0 {
      Some(list) => list
      None => sympy_default_gens([expr])
    }
    let poly = call_sympy_poly(expr, gens, domain, modulus)
    let factor_list = resolve_method_callable(poly, "factor_list")
    let res = py_call_noargs(factor_list)
    py_encode_result(res)
  } else {
    let sympy = ensure_sympy_module_oracle()
    let factor_list = resolve_callable(sympy, "factor_list")
    let kwargs_dict = py_dict_new()
    match modulus {
      Some(m) => py_dict_set_obj(kwargs_dict, "modulus", py_int_obj(m))
      None => ()
    }
    let res = py_call_with_args(factor_list, [expr], kwargs_dict)
    py_encode_result(res)
  }
}

///|
fn call_sympy_polys_sqf(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 1 else { fail("polys sqf args") }
  let expr = sympy_sympify_arg(args[0])
  let gens0 = kwargs_get_gens(kwargs)
  let domain = match kwargs_get_str(kwargs, "domain") {
    Some(s) => s
    None => ""
  }
  let modulus = kwargs_get_int(kwargs, "modulus")
  if gens0 is Some(_) || domain != "" || modulus is Some(_) {
    let gens = match gens0 {
      Some(list) => list
      None => sympy_default_gens([expr])
    }
    let poly = call_sympy_poly(expr, gens, domain, modulus)
    let sqf_list = resolve_method_callable(poly, "sqf_list")
    let res = py_call_noargs(sqf_list)
    py_encode_result(res)
  } else {
    let sympy = ensure_sympy_module_oracle()
    let sqf_list = resolve_callable(sympy, "sqf_list")
    let res = py_call_one(sqf_list, expr)
    py_encode_result(res)
  }
}

///|
fn call_sympy_polys_div(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 2 else { fail("polys div args") }
  let p = sympy_sympify_arg(args[0])
  let q = sympy_sympify_arg(args[1])
  let gens0 = kwargs_get_gens(kwargs)
  let domain = match kwargs_get_str(kwargs, "domain") {
    Some(s) => s
    None => ""
  }
  let modulus = kwargs_get_int(kwargs, "modulus")
  let gens = match gens0 {
    Some(list) => list
    None => sympy_default_gens([p, q])
  }
  if gens.length() > 0 && (domain != "" || modulus is Some(_)) {
    let pa = call_sympy_poly(p, gens, domain, modulus)
    let pb = call_sympy_poly(q, gens, domain, modulus)
    let div = resolve_method_callable(pa, "div")
    let res = py_call_one(div, pb)
    py_encode_result(res)
  } else {
    let sympy = ensure_sympy_module_oracle()
    let div = resolve_callable(sympy, "div")
    let res = py_call_two(div, p, q)
    py_encode_result(res)
  }
}

///|
fn call_sympy_polys_json(
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  guard args.length() >= 1 else { fail("polys_call_json args") }
  let op = oracle_arg_as_str(args[0])
  let rest : Array[OracleArg] = Array::new()
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  match op {
    "gcd" => call_sympy_polys_gcd(rest, kwargs)
    "resultant" => call_sympy_polys_resultant(rest, kwargs)
    "groebner" => call_sympy_polys_groebner(rest, kwargs)
    "factor" => call_sympy_polys_factor(rest, kwargs)
    "sqf" => call_sympy_polys_sqf(rest, kwargs)
    "div" => call_sympy_polys_div(rest, kwargs)
    _ => fail("unknown polys op: \{op}")
  }
}

///|
fn sympy_oracle_call_json_inprocess(
  func : String,
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  py_gil_hold_begin()
  let res = try {
    match func {
      "factor_list_json" => call_sympy_factor_list_json(args, kwargs)
      "sympify_list_json" => call_sympy_sympify_list_json(args)
      "polys_call_json" => call_sympy_polys_json(args, kwargs)
      _ => fail("sympy-oracle-inprocess")
    }
  } catch {
    e => {
      py_gil_hold_end()
      raise e
    }
  }
  py_gil_hold_end()
  res
}

///|
fn sympy_oracle_call_json_legacy(
  func : String,
  args : Array[OracleArg],
  kwargs : Map[String, OracleArg],
) -> Json raise {
  let payload = oracle_payload_json(func, args, kwargs)
  let out = strip_trailing_newline(sympy_oracle_exec(payload, ORACLE_PATH))
  if out.has_prefix("PYERR:") {
    fail(out)
  }
  let parsed = @json.parse(out)
  match parsed {
    Object(obj) =>
      match obj.get("ok") {
        Some(True) =>
          match obj.get("value") {
            Some(value) => value
            None => fail("oracle JSON missing value")
          }
        Some(False) => {
          let msg = match obj.get("error") {
            Some(String(s)) => s
            _ => "oracle error"
          }
          fail(msg)
        }
        _ => fail("oracle JSON missing ok flag")
      }
    _ => fail("oracle JSON not an object")
  }
}

///|/// Call into SymPy and return the decoded JSON value.
pub fn sympy_oracle_call_json(
  func : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> Json raise {
  sympy_oracle_call_json_legacy(func, args, kwargs)
}

///|
pub fn sympy_oracle_call(
  func : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let value = sympy_oracle_call_json(func, args, kwargs~)
  match value {
    String(s) => s
    _ => value.stringify()
  }
}

///|
pub fn sympy_polys_call_json(
  op : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> Json raise {
  let full : Array[OracleArg] = Array::new()
  full.push(OracleArg::Str(op))
  for arg in args {
    full.push(arg)
  }
  sympy_oracle_call_json("polys_call_json", full, kwargs~)
}

///|
pub fn sympy_polys_call(
  op : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let value = sympy_polys_call_json(op, args, kwargs~)
  match value {
    String(s) => s
    _ => value.stringify()
  }
}
