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
  PyObj(@py.PyObject)
}

///|
/// Remove all spaces to make string comparison insensitive to formatting.
pub fn remove_spaces(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
pub fn canonical_cmp(s : String) -> String {
  let mut t = remove_spaces(s)
  t = t.replace_all(old="2+x", new="x+2")
  t = t.replace_all(old="3+x", new="x+3")
  t = t.replace_all(old="-1+x", new="x-1")
  t = t.replace_all(old="1+x", new="x+1")
  t = t.replace_all(old="1+x**2", new="x**2+1")
  t = t.replace_all(old="-1+y", new="y-1")
  t = t.replace_all(old="1+y", new="y+1")
  t
}

///|
/// Canonicalise an expression string via `str(sympy.sympify(expr))` so that
/// ordering matches SymPy’s printer (helps when our printer orders constants
/// first).
pub fn sympy_normalize(expr_str : String) -> String raise {
  let expr = sympy_sympify_str(expr_str)
  py_str_obj(expr)
}

///|

///|

///|
let builtins_cache : Ref[@py.PyModule?] = { val: None }

///|
let sympy_cache : Ref[@py.PyModule?] = { val: None }

///|
let operator_cache : Ref[@py.PyModule?] = { val: None }

///|

///|
fn init {
  ensure_python()
}

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

///|
fn resolve_callable(mod : @py.PyModule, name : String) -> @py.PyCallable raise {
  let state = py_gil_ensure()
  let res = try {
    match mod.get_attr(name, print_err=false) {
      Some(PyCallable(callable)) => callable
      Some(PyClass(obj)) =>
        @py.PyCallable::create(obj) catch {
          _ => fail("sympy-oracle-callable")
        }
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
  @cpython.py_incref(res.obj_ref())
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
        @py.PyCallable::create(obj0) catch {
          _ => fail("sympy-oracle-callable")
        }
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
  @cpython.py_incref(res.obj_ref())
  py_gil_release(state)
  res
}

///|
fn py_tuple_from_objects(values : Array[@py.PyObject]) -> @py.PyTuple {
  let state = py_gil_ensure()
  let tup = @py.PyTuple::new(values.length().to_uint64())
  for i in 0..<values.length() {
    let obj = values[i]
    tup.set(i, obj)
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
  py_gil_release(state)
  obj
}

///|
fn py_int_obj(n : Int) -> @py.PyObject {
  let state = py_gil_ensure()
  let obj = @py.PyInteger::from(n.to_int64()).obj()
  py_gil_release(state)
  obj
}

///|
fn py_dict_set_obj(
  dict : @py.PyDict,
  key : String,
  value : @py.PyObject,
) -> Unit {
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
  let res = if py_dict_len(kwargs) == 0 {
    py_call_object(callable, tup, print_err=true)
  } else {
    py_call_object_kwargs(callable, tup, kwargs~, print_err=true)
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
fn py_sympy_expr_str(obj : @py.PyObject) -> String raise {
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
        return py_str_enum(expr_enum)
      }
    None => ()
  }
  py_str_obj(obj)
}

///|
fn py_sympy_enum_str(obj : @py.PyObjectEnum) -> String raise {
  py_sympy_expr_str(objenum_to_obj(obj))
}

///|
fn py_obj_to_int(obj : @py.PyObject) -> Int raise {
  match @py.PyObjectEnum::create(obj) {
    PyInteger(v) => v.to_int64().to_int()
    _ => @strconv.parse_int(py_str_obj(obj))
  }
}

///|

///|

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

///|
fn sympy_sympify_str(expr_str : String) -> @py.PyObject raise {
  let res = sympy_call_must("sympy.sympify", [OracleArg::Str(expr_str)])
  objenum_to_obj(res)
}

///|
fn sympy_symbol_obj(name : String) -> @py.PyObject raise {
  let res = sympy_call_must("sympy.symbols", [OracleArg::Str(name)])
  objenum_to_obj(res)
}

///|
fn sympy_poly_from_expr(
  expr : String,
  gens : Array[String],
) -> @py.PyObject raise {
  let expr_obj = sympy_sympify_str(expr)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_obj))
  for g in gens {
    args.push(OracleArg::PyObj(sympy_symbol_obj(g)))
  }
  let res = sympy_call_must("sympy.Poly", args)
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

///|

///|
fn sympy_fmt_mod(expr : @py.PyObject, modulus : Int) -> String raise {
  let poly = call_sympy_poly(expr, [], "", Some(modulus))
  let terms_callable = resolve_method_callable(poly, "terms")
  let terms_enum = py_call_noargs(terms_callable)
  let terms = py_list_to_pyobjects(terms_enum)
  let gens_enum = match py_get_attr(poly, "gens") {
    Some(v) => v
    None => fail("poly.gens missing")
  }
  let gens = py_list_to_pyobjects(gens_enum)
  let builtins = ensure_builtins_module()
  let pow_fn = resolve_callable(builtins, "pow")
  let operator = ensure_operator_module()
  let mul_fn = resolve_callable(operator, "mul")
  let add_fn = resolve_callable(operator, "add")
  let mut acc = py_int_obj(0)
  for term in terms {
    let term_items = py_list_to_pyobjects(@py.PyObjectEnum::create(term))
    if term_items.length() >= 2 {
      let monom_obj = term_items[0]
      let coeff_obj = term_items[1]
      let mut coeff_mod = py_obj_to_int(coeff_obj) % modulus
      if coeff_mod < 0 {
        coeff_mod = coeff_mod + modulus
      }
      let mut term_expr = py_int_obj(coeff_mod)
      let exps = py_list_to_pyobjects(@py.PyObjectEnum::create(monom_obj))
      let limit = if exps.length() < gens.length() {
        exps.length()
      } else {
        gens.length()
      }
      for i in 0..<limit {
        let exp_val = py_obj_to_int(exps[i])
        if exp_val != 0 {
          let pow_res = py_call_two(pow_fn, gens[i], py_int_obj(exp_val))
          let term_enum = py_call_two(
            mul_fn,
            term_expr,
            objenum_to_obj(pow_res),
          )
          term_expr = objenum_to_obj(term_enum)
        }
      }
      let acc_enum = py_call_two(add_fn, acc, term_expr)
      acc = objenum_to_obj(acc_enum)
    }
  }
  let res = sympy_call_must("sympy.expand", [OracleArg::PyObj(acc)])
  py_str_enum(res)
}

///|
fn sympy_factor_str(
  factor_obj : @py.PyObject,
  poly_cls : @py.PyObject?,
  modulus : Int?,
) -> String raise {
  let is_poly = match poly_cls {
    Some(cls) => py_isinstance(factor_obj, cls)
    None => false
  }
  match modulus {
    Some(m) =>
      if is_poly {
        let as_expr = resolve_method_callable(factor_obj, "as_expr")
        let expr_enum = py_call_noargs(as_expr)
        let expr_obj = objenum_to_obj(expr_enum)
        sympy_fmt_mod(expr_obj, m)
      } else {
        sympy_fmt_mod(factor_obj, m)
      }
    None =>
      if is_poly {
        let as_expr = resolve_method_callable(factor_obj, "as_expr")
        let expr_enum = py_call_noargs(as_expr)
        py_str_enum(expr_enum)
      } else {
        let poly = call_sympy_poly(factor_obj, [], "", None)
        let as_expr = resolve_method_callable(poly, "as_expr")
        let expr_enum = py_call_noargs(as_expr)
        py_str_enum(expr_enum)
      }
  }
}

///|
pub fn factor_list(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let expr_obj = expr_to_sympy(expr)
  let sympy = ensure_sympy_module_oracle()
  let kwargs_map : Map[String, OracleArg] = {}
  match modulus_opt {
    Some(m) => kwargs_map["modulus"] = OracleArg::Int(m)
    None => ()
  }
  let res = sympy_call_must(
    "sympy.factor_list",
    [OracleArg::PyObj(expr_obj)],
    kwargs=kwargs_map,
  )
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("factor_list tuple") }
  let content_obj = items[0]
  let factors_enum = @py.PyObjectEnum::create(items[1])
  let factors = py_list_to_pyobjects(factors_enum)
  let poly_cls = match sympy.get_attr("Poly", print_err=false) {
    Some(v) => Some(objenum_to_obj(v))
    None => None
  }
  let entries : Array[(String, Int, String)] = Array::new()
  for pair in factors {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      let factor_obj = pair_items[0]
      let exp_obj = pair_items[1]
      let factor_str = sympy_factor_str(factor_obj, poly_cls, modulus_opt)
      if factor_str != "1" {
        let exp_val = py_obj_to_int(exp_obj)
        entries.push((factor_str, exp_val, factor_str))
      }
    }
  }
  entries.sort_by((a, b) => {
    let cmp = a.0.compare(b.0)
    if cmp != 0 {
      cmp
    } else {
      a.1 - b.1
    }
  })
  let parts : Array[String] = Array::new()
  for entry in entries {
    parts.push("(\{entry.2}, \{entry.1})")
  }
  let factors_str = parts.join(",")
  let content_str = py_str_obj(content_obj)
  "(\{content_str}, [\{factors_str}])"
}

///|
pub fn monic(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let expr_obj = expr_to_sympy(expr)
  let poly = call_sympy_poly(expr_obj, [], "", modulus_opt)
  let monic = resolve_method_callable(poly, "monic")
  let monic_enum = py_call_noargs(monic)
  let monic_obj = objenum_to_obj(monic_enum)
  let as_expr = resolve_method_callable(monic_obj, "as_expr")
  let expr_enum = py_call_noargs(as_expr)
  py_str_enum(expr_enum)
}

///|
pub fn sqf_list(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let expr_obj = expr_to_sympy(expr)
  let sympy = ensure_sympy_module_oracle()
  let (content_obj, factors_obj) = match modulus_opt {
    Some(m) => {
      let poly = call_sympy_poly(expr_obj, [], "", Some(m))
      let sqf_list = resolve_method_callable(poly, "sqf_list")
      let res = py_call_noargs(sqf_list)
      let items = py_list_to_pyobjects(res)
      guard items.length() >= 2 else { fail("sqf_list tuple") }
      (items[0], items[1])
    }
    None => {
      let res = sympy_call_must("sympy.sqf_list", [OracleArg::PyObj(expr_obj)])
      let items = py_list_to_pyobjects(res)
      guard items.length() >= 2 else { fail("sqf_list tuple") }
      (items[0], items[1])
    }
  }
  let poly_cls = match sympy.get_attr("Poly", print_err=false) {
    Some(v) => Some(objenum_to_obj(v))
    None => None
  }
  let factors = py_list_to_pyobjects(@py.PyObjectEnum::create(factors_obj))
  let entries : Array[(String, Int, String)] = Array::new()
  for pair in factors {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      let factor_obj = pair_items[0]
      let exp_obj = pair_items[1]
      let factor_str = sympy_factor_str(factor_obj, poly_cls, modulus_opt)
      if factor_str != "1" {
        let exp_val = py_obj_to_int(exp_obj)
        entries.push((factor_str, exp_val, factor_str))
      }
    }
  }
  entries.sort_by((a, b) => {
    let cmp = a.0.compare(b.0)
    if cmp != 0 {
      cmp
    } else {
      a.1 - b.1
    }
  })
  let parts : Array[String] = Array::new()
  for entry in entries {
    parts.push("(\{entry.2}, \{entry.1})")
  }
  let factors_str = parts.join(",")
  let content_str = py_str_obj(content_obj)
  "(\{content_str}, [\{factors_str}])"
}

///|
pub fn groebner(
  exprs : Array[@symcore.Expr],
  order? : String = "lex",
) -> String raise {
  let expr_objs : Array[@py.PyObject] = Array::new()
  for expr in exprs {
    expr_objs.push(expr_to_sympy(expr))
  }
  let gens = sympy_default_gens(expr_objs)
  let args0 : Array[OracleArg] = Array::new()
  let py_polys = py_list_from_objects(expr_objs)
  args0.push(OracleArg::PyObj(py_polys.obj()))
  for g in gens {
    args0.push(OracleArg::PyObj(g))
  }
  let kwargs : Map[String, OracleArg] = {}
  if order != "" {
    kwargs["order"] = OracleArg::Str(order)
  }
  let res = sympy_call_must("sympy.groebner", args0, kwargs~)
  let res_obj = objenum_to_obj(res)
  let polys_enum = match py_get_attr(res_obj, "polys") {
    Some(v) => v
    None => fail("groebner.polys missing")
  }
  let polys = py_list_to_pyobjects(polys_enum)
  let basis : Array[String] = Array::new()
  for poly in polys {
    let monic = resolve_method_callable(poly, "monic")
    let monic_enum = py_call_noargs(monic)
    let monic_obj = objenum_to_obj(monic_enum)
    let as_expr = resolve_method_callable(monic_obj, "as_expr")
    let expr_enum = py_call_noargs(as_expr)
    basis.push(py_str_enum(expr_enum))
  }
  basis.sort()
  basis.join(" | ")
}

///|
pub fn sympy_sort_factor_repr(repr_str : String) -> String raise {
  let parsed = sympy_sympify_str(repr_str)
  let parsed_enum = @py.PyObjectEnum::create(parsed)
  let items = py_list_to_pyobjects(parsed_enum)
  guard items.length() >= 2 else { fail("sort_factor_repr tuple") }
  let content_obj = items[0]
  let factors_enum = @py.PyObjectEnum::create(items[1])
  let factors = py_list_to_pyobjects(factors_enum)
  let entries : Array[(String, Int, String)] = Array::new()
  for pair in factors {
    let pair_enum = @py.PyObjectEnum::create(pair)
    let pair_items = py_list_to_pyobjects(pair_enum)
    if pair_items.length() >= 2 {
      let factor_obj = pair_items[0]
      let exp_obj = pair_items[1]
      let factor_str = py_str_obj(factor_obj)
      let exp_val = match @py.PyObjectEnum::create(exp_obj) {
        PyInteger(v) => v.to_int64().to_int()
        _ => @strconv.parse_int(py_str_obj(exp_obj))
      }
      entries.push((factor_str, exp_val, factor_str))
    }
  }
  entries.sort_by((a, b) => {
    let cmp = a.0.compare(b.0)
    if cmp != 0 {
      cmp
    } else {
      a.1 - b.1
    }
  })
  let parts : Array[String] = Array::new()
  for entry in entries {
    parts.push("(\{entry.2}, \{entry.1})")
  }
  let factors_str = parts.join(",")
  let content_str = py_str_obj(content_obj)
  "(\{content_str}, [\{factors_str}])"
}

///|
pub fn sqf_part(expr : @symcore.Expr) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let poly = call_sympy_poly(expr_obj, [], "", None)
  let sqf_part = resolve_method_callable(poly, "sqf_part")
  let res = py_call_noargs(sqf_part)
  let res_obj = objenum_to_obj(res)
  let as_expr = resolve_method_callable(res_obj, "as_expr")
  let expr_enum = py_call_noargs(as_expr)
  py_str_enum(expr_enum)
}

///|
pub fn expr_equal(lhs : String, rhs : String) -> Bool raise {
  let diff_expr = sympy_sympify_str("(\{lhs}) - (\{rhs})")
  let res = sympy_call_must("sympy.simplify", [OracleArg::PyObj(diff_expr)])
  py_str_enum(res) == "0"
}

///|

///|
fn call_sympy_poly(
  expr : @py.PyObject,
  gens : Array[@py.PyObject],
  domain : String,
  modulus : Int?,
) -> @py.PyObject raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr))
  for g in gens {
    args.push(OracleArg::PyObj(g))
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  match modulus {
    Some(m) => kwargs["modulus"] = OracleArg::Int(m)
    None => ()
  }
  let res = sympy_call_must("sympy.Poly", args, kwargs~)
  objenum_to_obj(res)
}

///|
pub fn gcd(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let a = expr_to_sympy(p)
  let b = expr_to_sympy(q)
  let gens0 = if gens.is_empty() {
    None
  } else {
    Some(sympy_symbols_from_names(gens))
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let use_poly = gens0 is Some(_) || domain != "" || modulus_opt is Some(_)
  if use_poly {
    let gens_list = match gens0 {
      Some(list) => list
      None => sympy_default_gens([a, b])
    }
    let pa = call_sympy_poly(a, gens_list, domain, modulus_opt)
    let pb = call_sympy_poly(b, gens_list, domain, modulus_opt)
    let gcd = resolve_method_callable(pa, "gcd")
    let res = py_call_one(gcd, pb)
    py_sympy_enum_str(res)
  } else {
    let res = sympy_call_must("sympy.gcd", [
      OracleArg::PyObj(a),
      OracleArg::PyObj(b),
    ])
    py_sympy_enum_str(res)
  }
}

///|
pub fn resultant(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let p_obj = expr_to_sympy(p)
  let q_obj = expr_to_sympy(q)
  let mut var_obj : @py.PyObject? = None
  if x != "" {
    var_obj = Some(sympy_sympify_str(x))
  }
  let gens0 = if gens.is_empty() {
    None
  } else {
    Some(sympy_symbols_from_names(gens))
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let gens_list = match gens0 {
    Some(list) => list
    None => {
      let seed : Array[@py.PyObject] = Array::new()
      seed.push(p_obj)
      seed.push(q_obj)
      match var_obj {
        Some(v) => seed.push(v)
        None => ()
      }
      sympy_default_gens(seed)
    }
  }
  if gens_list.length() > 0 && (domain != "" || modulus_opt is Some(_)) {
    let pa = call_sympy_poly(p_obj, gens_list, domain, modulus_opt)
    let pb = call_sympy_poly(q_obj, gens_list, domain, modulus_opt)
    let resultant = resolve_method_callable(pa, "resultant")
    let res = match var_obj {
      Some(v) => {
        let kwargs_dict = py_dict_new()
        py_dict_set_obj(kwargs_dict, "var", v)
        py_call_one_kwargs(resultant, pb, kwargs_dict)
      }
      None => py_call_one(resultant, pb)
    }
    py_sympy_enum_str(res)
  } else {
    if var_obj is None {
      if gens_list.length() > 0 {
        var_obj = Some(gens_list[0])
      } else {
        fail("resultant requires a variable")
      }
    }
    let args0 : Array[OracleArg] = Array::new()
    args0.push(OracleArg::PyObj(p_obj))
    args0.push(OracleArg::PyObj(q_obj))
    match var_obj {
      Some(v) => args0.push(OracleArg::PyObj(v))
      None => ()
    }
    let kwargs_map : Map[String, OracleArg] = {}
    match modulus_opt {
      Some(m) => kwargs_map["modulus"] = OracleArg::Int(m)
      None => ()
    }
    let res = sympy_call_must("sympy.resultant", args0, kwargs=kwargs_map)
    py_sympy_enum_str(res)
  }
}

///|

///|
pub fn div(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let p_obj = expr_to_sympy(p)
  let q_obj = expr_to_sympy(q)
  let gens0 = if gens.is_empty() {
    None
  } else {
    Some(sympy_symbols_from_names(gens))
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let use_poly = gens0 is Some(_) || domain != "" || modulus_opt is Some(_)
  let res = if use_poly {
    let gens_list = match gens0 {
      Some(list) => list
      None => sympy_default_gens([p_obj, q_obj])
    }
    let pa = call_sympy_poly(p_obj, gens_list, domain, modulus_opt)
    let pb = call_sympy_poly(q_obj, gens_list, domain, modulus_opt)
    let div = resolve_method_callable(pa, "div")
    py_call_one(div, pb)
  } else {
    sympy_call_must("sympy.div", [
      OracleArg::PyObj(p_obj),
      OracleArg::PyObj(q_obj),
    ])
  }
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("div result tuple") }
  let quo = py_sympy_expr_str(items[0])
  let rem = py_sympy_expr_str(items[1])
  "\{quo}||\{rem}"
}

///|
pub fn gcd_list(
  polys : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  let list_items : Array[OracleArg] = Array::new()
  for p in polys {
    list_items.push(OracleArg::PyObj(expr_to_sympy(p)))
  }
  args.push(OracleArg::List(list_items))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for g in gens_list {
      args.push(OracleArg::PyObj(g))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.gcd_list", args, kwargs~)
  py_sympy_enum_str(res)
}

///|
pub fn lcm_list(
  polys : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  let list_items : Array[OracleArg] = Array::new()
  for p in polys {
    list_items.push(OracleArg::PyObj(expr_to_sympy(p)))
  }
  args.push(OracleArg::List(list_items))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for g in gens_list {
      args.push(OracleArg::PyObj(g))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.lcm_list", args, kwargs~)
  py_sympy_enum_str(res)
}

///|
pub fn terms_gcd(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let poly = call_sympy_poly(expr_obj, gens_list, domain, modulus_opt)
  let content_call = resolve_method_callable(poly, "content")
  let content_enum = py_call_noargs(content_call)
  let terms_gcd_call = resolve_method_callable(poly, "terms_gcd")
  let gcd_enum = py_call_noargs(terms_gcd_call)
  let gcd_items = py_list_to_pyobjects(gcd_enum)
  guard gcd_items.length() >= 1 else { fail("terms_gcd result tuple") }
  let exp_items = py_list_to_pyobjects(@py.PyObjectEnum::create(gcd_items[0]))
  let mut acc = objenum_to_obj(content_enum)
  for i in 0..<exp_items.length() {
    let exp = py_obj_to_int(exp_items[i])
    if exp == 0 {
      continue
    }
    let pow = sympy_call_must(
      "sympy.Pow",
      [OracleArg::PyObj(gens_list[i]), OracleArg::Int(exp)],
    )
    let mul = resolve_method_callable(acc, "__mul__")
    let acc_enum = py_call_one(mul, objenum_to_obj(pow))
    acc = objenum_to_obj(acc_enum)
  }
  py_sympy_expr_str(acc)
}

///|
pub fn cancel(
  p : @symcore.Expr,
  q : @symcore.Expr,
) -> String raise {
  let p_obj = expr_to_sympy(p)
  let q_obj = expr_to_sympy(q)
  let div_call = resolve_method_callable(p_obj, "__truediv__")
  let div_enum = py_call_one(div_call, q_obj)
  let cancel_res = sympy_call_must(
    "sympy.cancel",
    [OracleArg::PyObj(objenum_to_obj(div_enum))],
  )
  let frac = sympy_call_must(
    "sympy.fraction",
    [OracleArg::PyObj(objenum_to_obj(cancel_res))],
  )
  let items = py_list_to_pyobjects(frac)
  guard items.length() >= 2 else { fail("cancel fraction tuple") }
  let num = py_sympy_expr_str(items[0])
  let den = py_sympy_expr_str(items[1])
  "\{num}||\{den}"
}

///|
pub fn reduced(
  f : @symcore.Expr,
  divisors : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(f)))
  let list_items : Array[OracleArg] = Array::new()
  for g in divisors {
    list_items.push(OracleArg::PyObj(expr_to_sympy(g)))
  }
  args.push(OracleArg::List(list_items))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for g in gens_list {
      args.push(OracleArg::PyObj(g))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.reduced", args, kwargs~)
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("reduced result tuple") }
  let qs = py_list_to_pyobjects(@py.PyObjectEnum::create(items[0]))
  let parts : Array[String] = Array::new()
  for q in qs {
    parts.push(py_sympy_expr_str(q))
  }
  let r = py_sympy_expr_str(items[1])
  let joined = parts.join(" | ")
  "\{joined}||\{r}"
}

///|
pub fn compose(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(f)))
  args.push(OracleArg::PyObj(expr_to_sympy(g)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.compose", args, kwargs~)
  py_sympy_enum_str(res)
}

///|
pub fn decompose(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(f)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.decompose", args, kwargs~)
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn sturm(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(f)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.sturm", args, kwargs~)
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn discriminant(
  f : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(f)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must(
    "sympy.polys.polytools.discriminant",
    args,
    kwargs~,
  )
  py_sympy_enum_str(res)
}

///|
pub fn subresultants(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(p)))
  args.push(OracleArg::PyObj(expr_to_sympy(q)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if domain != "" {
    kwargs["domain"] = OracleArg::Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = OracleArg::Int(modulus)
  }
  let res = sympy_call_must(
    "sympy.polys.polytools.subresultants",
    args,
    kwargs~,
  )
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn poly_degree_list(
  expr : String,
  gens? : Array[String] = [],
) -> Array[Int] raise {
  let poly = sympy_poly_from_expr(expr, gens)
  let degree_list = resolve_method_callable(poly, "degree_list")
  let res = py_call_noargs(degree_list)
  let items = py_list_to_pyobjects(res)
  let out : Array[Int] = Array::new()
  for item in items {
    out.push(py_obj_to_int(item))
  }
  out
}

///|
pub fn poly_lc(expr : String, gens? : Array[String] = []) -> String raise {
  let poly = sympy_poly_from_expr(expr, gens)
  let lc = resolve_method_callable(poly, "LC")
  let res = py_call_noargs(lc)
  py_sympy_enum_str(res)
}

///|
pub fn poly_tc(expr : String, gens? : Array[String] = []) -> String raise {
  let poly = sympy_poly_from_expr(expr, gens)
  let tc = resolve_method_callable(poly, "TC")
  let res = py_call_noargs(tc)
  py_sympy_enum_str(res)
}

///|
/// Convenience wrapper that returns `str(result)` for SymPy calls.
pub fn sympy_call_string(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> String raise {
  let res = sympy_call_must(path, args, kwargs~)
  py_sympy_enum_str(res)
}
