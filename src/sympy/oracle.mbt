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
pub(all) enum DenseData {
  Coef(@symnum.BigRational)
  Poly(Array[DenseData])
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
pub fn poly_expr(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens0 = if gens.is_empty() {
    None
  } else {
    Some(sympy_symbols_from_names(gens))
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let gens_list = match gens0 {
    Some(list) => list
    None => sympy_default_gens([expr_obj])
  }
  let poly = call_sympy_poly(expr_obj, gens_list, domain, modulus_opt)
  let as_expr = resolve_method_callable(poly, "as_expr")
  let expr_enum = py_call_noargs(as_expr)
  py_str_enum(expr_enum)
}

///|
pub fn mod_rational(num : Int, den : Int, p : Int) -> String raise {
  let inv = sympy_call_must("sympy.mod_inverse", [
    OracleArg::Int(den),
    OracleArg::Int(p),
  ])
  let inv_obj = objenum_to_obj(inv)
  let num_obj = sympy_call_must("sympy.Integer", [OracleArg::Int(num)])
  let mul = sympy_call_must("sympy.Mul", [
    OracleArg::PyObj(objenum_to_obj(num_obj)),
    OracleArg::PyObj(inv_obj),
  ])
  let mod_res = sympy_call_must("sympy.Mod", [
    OracleArg::PyObj(objenum_to_obj(mul)),
    OracleArg::Int(p),
  ])
  py_str_enum(mod_res)
}

///|
pub fn dict_from_expr(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_obj))
  let kwargs : Map[String, OracleArg] = {}
  if !gens.is_empty() {
    let gens_objs = sympy_symbols_from_names(gens)
    let list = py_list_from_objects(gens_objs)
    kwargs["gens"] = OracleArg::PyObj(list.obj())
  }
  let res = sympy_call_must("sympy.polys.polyutils.dict_from_expr", args, kwargs~)
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("dict_from_expr tuple") }
  let dict_obj = items[0]
  let gens_obj = items[1]
  let items_call = resolve_method_callable(dict_obj, "items")
  let items_enum = py_call_noargs(items_call)
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let items_list_enum = py_call_one(list_ctor, objenum_to_obj(items_enum))
  let kvs = py_list_to_pyobjects(items_list_enum)
  let entries : Array[(Array[Int], String)] = Array::new()
  for pair in kvs {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      let key_obj = pair_items[0]
      let val_obj = pair_items[1]
      let exps_objs = py_list_to_pyobjects(@py.PyObjectEnum::create(key_obj))
      let exps : Array[Int] = Array::new()
      for e in exps_objs {
        exps.push(py_obj_to_int(e))
      }
      let coeff_str = py_str_obj(val_obj)
      entries.push((exps, coeff_str))
    }
  }
  entries.sort_by((a, b) => cmp_exps(a.0, b.0))
  let dict_str = dict_repr(entries)
  let gens_list = py_list_to_pyobjects(@py.PyObjectEnum::create(gens_obj))
  let gen_names : Array[String] = Array::new()
  for g in gens_list {
    gen_names.push(py_str_obj(g))
  }
  let gens_str = gen_names.map(n => "\"\{n}\"").join(",")
  "\{dict_str}||[\{gens_str}]"
}

///|
pub fn sort_gens(
  gens : Array[String],
  wrt? : Array[String] = [],
  sort? : String = "",
) -> Array[String] raise {
  let gens_objs = sympy_symbols_from_names(gens)
  let args : Array[OracleArg] = Array::new()
  let gens_list = py_list_from_objects(gens_objs)
  args.push(OracleArg::PyObj(gens_list.obj()))
  let kwargs : Map[String, OracleArg] = {}
  if !wrt.is_empty() {
    let wrt_objs = sympy_symbols_from_names(wrt)
    let wrt_list = py_list_from_objects(wrt_objs)
    kwargs["wrt"] = OracleArg::PyObj(wrt_list.obj())
  }
  if sort != "" {
    kwargs["sort"] = OracleArg::Str(sort)
  }
  let res = sympy_call_must("sympy.polys.polyutils._sort_gens", args, kwargs~)
  let items = py_list_to_pyobjects(res)
  let names : Array[String] = Array::new()
  for obj in items {
    names.push(py_str_obj(obj))
  }
  names
}

///|
pub fn unify_gens(a : Array[String], b : Array[String]) -> Array[String] raise {
  let a_objs = sympy_symbols_from_names(a)
  let b_objs = sympy_symbols_from_names(b)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(py_list_from_objects(a_objs).obj()),
    OracleArg::PyObj(py_list_from_objects(b_objs).obj()),
  ]
  let res = sympy_call_must("sympy.polys.polyutils._unify_gens", args)
  let items = py_list_to_pyobjects(res)
  let names : Array[String] = Array::new()
  for obj in items {
    names.push(py_str_obj(obj))
  }
  names
}

///|
pub fn analyze_gens(gens : Array[String]) -> Array[String] raise {
  let gens_objs = sympy_symbols_from_names(gens)
  let args : Array[OracleArg] = [
    OracleArg::PyObj(py_list_from_objects(gens_objs).obj()),
  ]
  let res = sympy_call_must("sympy.polys.polyutils._analyze_gens", args)
  let items = py_list_to_pyobjects(res)
  let names : Array[String] = Array::new()
  for obj in items {
    names.push(py_str_obj(obj))
  }
  names
}

///|
pub fn analyze_gens_nested(gens : Array[Array[String]]) -> Array[String] raise {
  let outer : Array[@py.PyObject] = Array::new()
  for group in gens {
    let group_objs = sympy_symbols_from_names(group)
    let group_list = py_list_from_objects(group_objs)
    outer.push(group_list.obj())
  }
  let args : Array[OracleArg] = [
    OracleArg::PyObj(py_list_from_objects(outer).obj()),
  ]
  let res = sympy_call_must("sympy.polys.polyutils._analyze_gens", args)
  let items = py_list_to_pyobjects(res)
  let names : Array[String] = Array::new()
  for obj in items {
    names.push(py_str_obj(obj))
  }
  names
}

///|
pub fn sort_factors(factors : Array[Array[Int]]) -> String raise {
  let items : Array[@py.PyObject] = Array::new()
  for f in factors {
    let inner : Array[@py.PyObject] = Array::new()
    for v in f {
      inner.push(py_int_obj(v))
    }
    let inner_list = py_list_from_objects(inner)
    items.push(inner_list.obj())
  }
  let args : Array[OracleArg] = [
    OracleArg::PyObj(py_list_from_objects(items).obj()),
  ]
  let kwargs : Map[String, OracleArg] = { "multiple": OracleArg::Bool(false) }
  let res = sympy_call_must("sympy.polys.polyutils._sort_factors", args, kwargs~)
  let lists = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in lists {
    let seq_items = py_list_to_pyobjects(@py.PyObjectEnum::create(item))
    let seq : Array[String] = Array::new()
    for v in seq_items {
      seq.push(py_obj_to_int(v).to_string())
    }
    let joined = seq.join(",")
    parts.push("[\{joined}]")
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
pub fn sort_factors_multiple(
  factors : Array[(Array[Int], Int)],
) -> String raise {
  let items : Array[@py.PyObject] = Array::new()
  for f in factors {
    let inner : Array[@py.PyObject] = Array::new()
    for v in f.0 {
      inner.push(py_int_obj(v))
    }
    let inner_list = py_list_from_objects(inner)
    let pair = py_tuple_from_objects([inner_list.obj(), py_int_obj(f.1)])
    items.push(pair.obj())
  }
  let args : Array[OracleArg] = [
    OracleArg::PyObj(py_list_from_objects(items).obj()),
  ]
  let kwargs : Map[String, OracleArg] = { "multiple": OracleArg::Bool(true) }
  let res = sympy_call_must("sympy.polys.polyutils._sort_factors", args, kwargs~)
  let pairs = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for pair in pairs {
    let items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if items.length() >= 2 {
      let seq_items = py_list_to_pyobjects(@py.PyObjectEnum::create(items[0]))
      let seq : Array[String] = Array::new()
      for item in seq_items {
        seq.push(py_obj_to_int(item).to_string())
      }
      let seq_joined = seq.join(",")
      let list_str = "[\{seq_joined}]"
      let exp = py_obj_to_int(items[1])
      parts.push("(\{list_str},\{exp})")
    }
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn cmp_exps(a : Array[Int], b : Array[Int]) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  a.length() - b.length()
}

///|
fn tuple_repr(exps : Array[Int]) -> String {
  if exps.length() == 1 {
    return "(\{exps[0]},)"
  }
  let parts = exps.map(e => e.to_string()).join(",")
  "(\{parts})"
}

///|
fn dict_repr(entries : Array[(Array[Int], String)]) -> String {
  let parts : Array[String] = Array::new()
  for entry in entries {
    let (exps, coeff) = entry
    parts.push("\{tuple_repr(exps)}:\{coeff}")
  }
  let joined = parts.join(",")
  "{\{joined}}"
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
fn py_str_value(obj : @py.PyObject) -> String raise {
  let builtins = ensure_builtins_module()
  let str_enum = match builtins.get_attr("str", print_err=false) {
    Some(v) => v
    None => fail("builtins-str-missing")
  }
  let callable = @py.PyCallable::create(objenum_to_obj(str_enum)) catch {
      _ => fail("builtins-str-callable")
    }
  let res = py_call_one(callable, obj)
  match res {
    PyString(s) => @py.PyString::to_string(s)
    _ => py_str_enum(res)
  }
}

///|
fn py_dense_str(obj : @py.PyObjectEnum) -> String raise {
  match obj {
    PyList(_) => {
      let items = py_list_to_pyobjects(obj)
      let parts : Array[String] = Array::new()
      for it in items {
        parts.push(py_dense_str(@py.PyObjectEnum::create(it)))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
    PyTuple(_) => {
      let items = py_list_to_pyobjects(obj)
      let parts : Array[String] = Array::new()
      for it in items {
        parts.push(py_dense_str(@py.PyObjectEnum::create(it)))
      }
      let joined = parts.join(",")
      "(\{joined})"
    }
    _ => py_str_value(objenum_to_obj(obj))
  }
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
pub fn factor_list(
  expr : @symcore.Expr,
  modulus? : Int = 0,
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let expr_obj = expr_to_sympy(expr)
  let sympy = ensure_sympy_module_oracle()
  let use_gfext = !gfext_modulus.is_empty()
  let kwargs_map : Map[String, OracleArg] = {}
  if use_gfext {
    match modulus_opt {
      Some(m) =>
        kwargs_map["domain"] =
          OracleArg::PyObj(sympy_domain_gfext(m, gfext_modulus, gfext_gen))
      None => fail("gfext-modulus-missing")
    }
  } else {
    match modulus_opt {
      Some(m) => kwargs_map["modulus"] = OracleArg::Int(m)
      None => ()
    }
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
pub fn sqf_list(
  expr : @symcore.Expr,
  modulus? : Int = 0,
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let expr_obj = expr_to_sympy(expr)
  let sympy = ensure_sympy_module_oracle()
  let use_gfext = !gfext_modulus.is_empty()
  let (content_obj, factors_obj) = if use_gfext {
    let domain_obj = match modulus_opt {
      Some(m) => sympy_domain_gfext(m, gfext_modulus, gfext_gen)
      None => fail("gfext-modulus-missing")
    }
    let poly = call_sympy_poly(expr_obj, [], "", None, domain_obj=Some(domain_obj))
    let sqf_list = resolve_method_callable(poly, "sqf_list")
    let res = py_call_noargs(sqf_list)
    let items = py_list_to_pyobjects(res)
    guard items.length() >= 2 else { fail("sqf_list tuple") }
    (items[0], items[1])
  } else {
    match modulus_opt {
      Some(m) => {
        let poly = call_sympy_poly(expr_obj, [], "", Some(m))
        let sqf_list = resolve_method_callable(poly, "sqf_list")
        let res = py_call_noargs(sqf_list)
        let items = py_list_to_pyobjects(res)
        guard items.length() >= 2 else { fail("sqf_list tuple") }
        (items[0], items[1])
      }
      None => {
        let res =
          sympy_call_must("sympy.sqf_list", [OracleArg::PyObj(expr_obj)])
        let items = py_list_to_pyobjects(res)
        guard items.length() >= 2 else { fail("sqf_list tuple") }
        (items[0], items[1])
      }
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
  domain_obj? : @py.PyObject? = None,
) -> @py.PyObject raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr))
  for g in gens {
    args.push(OracleArg::PyObj(g))
  }
  let kwargs : Map[String, OracleArg] = {}
  match domain_obj {
    Some(obj) => kwargs["domain"] = OracleArg::PyObj(obj)
    None =>
      if domain != "" {
        kwargs["domain"] = OracleArg::Str(domain)
      }
  }
  if domain_obj is None {
    match modulus {
      Some(m) => kwargs["modulus"] = OracleArg::Int(m)
      None => ()
    }
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
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let a = expr_to_sympy(p)
  let b = expr_to_sympy(q)
  let gens0 = if gens.is_empty() {
    None
  } else {
    Some(sympy_symbols_from_names(gens))
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let use_gfext = !gfext_modulus.is_empty()
  let use_poly =
    gens0 is Some(_) ||
    domain != "" ||
    modulus_opt is Some(_) ||
    use_gfext
  if use_poly {
    let gens_list = match gens0 {
      Some(list) => list
      None => sympy_default_gens([a, b])
    }
    let domain_obj = if use_gfext {
      match modulus_opt {
        Some(m) => Some(sympy_domain_gfext(m, gfext_modulus, gfext_gen))
        None => fail("gfext-modulus-missing")
      }
    } else {
      None
    }
    let pa = call_sympy_poly(a, gens_list, domain, modulus_opt, domain_obj~)
    let pb = call_sympy_poly(b, gens_list, domain, modulus_opt, domain_obj~)
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
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
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
  let use_gfext = !gfext_modulus.is_empty()
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
  if gens_list.length() > 0 && (domain != "" || modulus_opt is Some(_) || use_gfext) {
    let domain_obj = if use_gfext {
      match modulus_opt {
        Some(m) => Some(sympy_domain_gfext(m, gfext_modulus, gfext_gen))
        None => fail("gfext-modulus-missing")
      }
    } else {
      None
    }
    let pa = call_sympy_poly(p_obj, gens_list, domain, modulus_opt, domain_obj~)
    let pb = call_sympy_poly(q_obj, gens_list, domain, modulus_opt, domain_obj~)
    let resultant = resolve_method_callable(pa, "resultant")
    // Poly.resultant does not accept a 'var' kwarg; gens ordering handles it.
    let res = py_call_one(resultant, pb)
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
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let p_obj = expr_to_sympy(p)
  let q_obj = expr_to_sympy(q)
  let gens0 = if gens.is_empty() {
    None
  } else {
    Some(sympy_symbols_from_names(gens))
  }
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let use_gfext = !gfext_modulus.is_empty()
  let use_poly =
    gens0 is Some(_) ||
    domain != "" ||
    modulus_opt is Some(_) ||
    use_gfext
  let res = if use_poly {
    let gens_list = match gens0 {
      Some(list) => list
      None => sympy_default_gens([p_obj, q_obj])
    }
    let domain_obj = if use_gfext {
      match modulus_opt {
        Some(m) => Some(sympy_domain_gfext(m, gfext_modulus, gfext_gen))
        None => fail("gfext-modulus-missing")
      }
    } else {
      None
    }
    let pa = call_sympy_poly(p_obj, gens_list, domain, modulus_opt, domain_obj~)
    let pb = call_sympy_poly(q_obj, gens_list, domain, modulus_opt, domain_obj~)
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
fn sympy_points_obj(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
) -> @py.PyObject raise {
  let items : Array[@py.PyObject] = Array::new()
  for pair in points {
    let (x, y) = pair
    let x_obj = sympy_number_obj(x)
    let y_obj = sympy_number_obj(y)
    let tup = py_tuple_from_objects([x_obj, y_obj])
    items.push(tup.obj())
  }
  let list = py_list_from_objects(items)
  list.obj()
}

///|
pub fn interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  x? : String = "x",
) -> String raise {
  let data_obj = sympy_points_obj(points)
  let sym = sympy_symbol_obj(x)
  let res = sympy_call_must(
    "sympy.interpolate",
    [OracleArg::PyObj(data_obj), OracleArg::PyObj(sym)],
  )
  py_sympy_enum_str(res)
}

///|
pub fn interpolate_values(
  values : Array[@symnum.BigRational],
  x? : String = "x",
) -> String raise {
  let data_obj = py_list_from_rationals(values)
  let sym = sympy_symbol_obj(x)
  let res = sympy_call_must(
    "sympy.interpolate",
    [OracleArg::PyObj(data_obj), OracleArg::PyObj(sym)],
  )
  py_sympy_enum_str(res)
}

///|
pub fn interpolate_dict(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  x? : String = "x",
) -> String raise {
  let dict = py_dict_new()
  let dict_obj = dict.obj()
  let setitem = resolve_method_callable(dict_obj, "__setitem__")
  for pair in points {
    let x_obj = sympy_number_obj_oracle(pair.0)
    let y_obj = sympy_number_obj_oracle(pair.1)
    let tup = py_tuple_from_objects([x_obj, y_obj])
    let _ = py_call_object_allow_none(setitem, tup, print_err=true)
  }
  let sym = sympy_symbol_obj(x)
  let res = sympy_call_must(
    "sympy.interpolate",
    [OracleArg::PyObj(dict_obj), OracleArg::PyObj(sym)],
  )
  py_sympy_enum_str(res)
}

///|
pub fn rational_interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  x? : String = "x",
) -> String raise {
  let data_obj = sympy_points_obj(points)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(data_obj))
  args.push(OracleArg::Int(deg_num))
  let kwargs : Map[String, OracleArg] = {}
  if x != "" {
    kwargs["X"] = OracleArg::PyObj(sympy_symbol_obj(x))
  }
  let res = sympy_call_must("sympy.rational_interpolate", args, kwargs~)
  let res_obj = objenum_to_obj(res)
  let frac = sympy_call_must("sympy.fraction", [OracleArg::PyObj(res_obj)])
  let items = py_list_to_pyobjects(frac)
  guard items.length() >= 2 else { fail("rational_interpolate fraction") }
  let num_str = py_sympy_expr_str(items[0])
  let den_str = py_sympy_expr_str(items[1])
  "\{num_str}||\{den_str}"
}

///|
fn sympy_domain_obj(name : String) -> @py.PyObject raise {
  let sympy = ensure_sympy_module_oracle()
  match sympy.get_attr(name, print_err=false) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-domain-missing:\{name}")
  }
}

///|
fn gfext_mod_poly_str(coeffs : Array[Int], gen : String) -> String {
  let terms : Array[String] = Array::new()
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if c == 0 {
      continue
    }
    let term = if i == 0 {
      "\{c}"
    } else if i == 1 {
      if c == 1 { gen } else { "\{c}*\{gen}" }
    } else {
      let base = "\{gen}**\{i}"
      if c == 1 { base } else { "\{c}*\{base}" }
    }
    terms.push(term)
  }
  if terms.is_empty() {
    "0"
  } else {
    terms.join(" + ")
  }
}

///|
fn sympy_domain_gfext(
  modulus : Int,
  mod_poly : Array[Int],
  gen : String,
) -> @py.PyObject raise {
  if modulus <= 1 {
    fail("gfext-modulus")
  }
  let expr_str = gfext_mod_poly_str(mod_poly, gen)
  let expr_obj = sympy_sympify_str(expr_str)
  let gen_obj = sympy_symbol_obj(gen)
  let poly_args : Array[OracleArg] = [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(gen_obj),
  ]
  let poly_kwargs : Map[String, OracleArg] = { "modulus": OracleArg::Int(modulus) }
  let poly_enum = sympy_call_must("sympy.Poly", poly_args, kwargs=poly_kwargs)
  let poly_obj = objenum_to_obj(poly_enum)
  let ext_enum = sympy_call_must(
    "sympy.polys.agca.extensions.FiniteExtension",
    [OracleArg::PyObj(poly_obj)],
  )
  objenum_to_obj(ext_enum)
}

///|
fn sympy_number_obj_oracle(n : @symnum.BigRational) -> @py.PyObject raise {
  if n.is_integral() {
    let num_str = n.numerator().to_string()
    objenum_to_obj(sympy_call_must("sympy.Integer", [OracleArg::Str(num_str)]))
  } else {
    let num_str = n.numerator().to_string()
    let den_str = n.denominator().to_string()
    objenum_to_obj(sympy_call_must(
      "sympy.Rational",
      [OracleArg::Str(num_str), OracleArg::Str(den_str)],
    ))
  }
}

///|
fn sympy_domain_elem(
  n : @symnum.BigRational,
  domain : String,
) -> @py.PyObject raise {
  let dom = sympy_domain_obj(domain)
  let convert_enum = match py_get_attr(dom, "convert") {
    Some(v) => v
    None => fail("sympy-domain-convert-missing")
  }
  let convert = @py.PyCallable::create(objenum_to_obj(convert_enum)) catch {
      _ => fail("sympy-domain-convert-callable")
    }
  let num_obj = sympy_number_obj_oracle(n)
  let res = py_call_one(convert, num_obj)
  objenum_to_obj(res)
}

///|
fn py_list_from_rationals(
  coeffs : Array[@symnum.BigRational],
) -> @py.PyObject raise {
  let items : Array[@py.PyObject] = Array::new()
  for c in coeffs {
    items.push(sympy_number_obj_oracle(c))
  }
  let list = py_list_from_objects(items)
  list.obj()
}

///|
fn py_list_from_rationals_domain(
  coeffs : Array[@symnum.BigRational],
  domain : String,
) -> @py.PyObject raise {
  let items : Array[@py.PyObject] = Array::new()
  for c in coeffs {
    items.push(sympy_domain_elem(c, domain))
  }
  let list = py_list_from_objects(items)
  list.obj()
}

///|
fn dense_data_to_pyobj(data : DenseData) -> @py.PyObject raise {
  match data {
    DenseData::Coef(c) => sympy_number_obj_oracle(c)
    DenseData::Poly(items) => {
      let out : Array[@py.PyObject] = Array::new()
      for it in items {
        out.push(dense_data_to_pyobj(it))
      }
      let list = py_list_from_objects(out)
      list.obj()
    }
  }
}

///|
fn dense_data_to_pyobj_domain(
  data : DenseData,
  domain : String,
) -> @py.PyObject raise {
  match data {
    DenseData::Coef(c) => sympy_domain_elem(c, domain)
    DenseData::Poly(items) => {
      let out : Array[@py.PyObject] = Array::new()
      for it in items {
        out.push(dense_data_to_pyobj_domain(it, domain))
      }
      let list = py_list_from_objects(out)
      list.obj()
    }
  }
}

///|
pub fn dup_add_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(k))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_add_term", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_sub_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(k))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_sub_term", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_mul_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(k))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_mul_term", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_add_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_add_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_sub_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_sub_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_mul_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_mul_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_quo_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_quo_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_exquo_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_number_obj_oracle(c)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_exquo_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_lshift(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_lshift", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_rshift(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_rshift", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_neg(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_neg", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_abs(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals(f)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_abs", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_add(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_add", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_sub(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_sub", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_mul(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_mul", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_sqr(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_sqr", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_pow(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_pow", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_rr_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_rr_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_ff_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_ff_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_rem(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_rem", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_quo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_quo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_exquo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(g, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_exquo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_add_term(
  f : DenseData,
  c : DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(c, domain)))
  args.push(OracleArg::Int(k))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_add_term", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_sub_term(
  f : DenseData,
  c : DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(c, domain)))
  args.push(OracleArg::Int(k))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_sub_term", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_mul_term(
  f : DenseData,
  c : DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(c, domain)))
  args.push(OracleArg::Int(k))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_mul_term", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_add_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_add_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_sub_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_sub_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_mul_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_mul_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_quo_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_quo_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_exquo_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(c, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_exquo_ground", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_abs(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_abs", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_neg(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_neg", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_add(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_add", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_sub(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_sub", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_mul(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_mul", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_sqr(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_sqr", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_pow(
  f : DenseData,
  n : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_pow", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_add_mul(
  f : DenseData,
  g : DenseData,
  h : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(h, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_add_mul", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_sub_mul(
  f : DenseData,
  g : DenseData,
  h : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(h, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_sub_mul", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_pdiv(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_pdiv", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_prem(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_prem", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_pquo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_pquo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_pexquo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_pexquo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_rr_div(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_rr_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_ff_div(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_ff_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_div(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_rem(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_rem", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_quo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_quo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_exquo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(g, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_exquo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_max_norm(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_max_norm", args)
  py_sympy_enum_str(res)
}

///|
pub fn dmp_max_norm(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_max_norm", args)
  py_sympy_enum_str(res)
}

///|
pub fn dup_l1_norm(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_l1_norm", args)
  py_sympy_enum_str(res)
}

///|
pub fn dmp_l1_norm(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_l1_norm", args)
  py_sympy_enum_str(res)
}

///|
pub fn dup_l2_norm_squared(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_l2_norm_squared", args)
  py_sympy_enum_str(res)
}

///|
pub fn dmp_l2_norm_squared(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_l2_norm_squared", args)
  py_sympy_enum_str(res)
}

///|
pub fn dup_expand(
  polys : Array[Array[@symnum.BigRational]],
  domain? : String = "ZZ",
) -> String raise {
  let outer : Array[@py.PyObject] = Array::new()
  for f in polys {
    outer.push(py_list_from_rationals_domain(f, domain))
  }
  let list = py_list_from_objects(outer)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(list.obj()))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dup_expand", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_expand(
  polys : Array[DenseData],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let outer : Array[@py.PyObject] = Array::new()
  for f in polys {
    outer.push(dense_data_to_pyobj_domain(f, domain))
  }
  let list = py_list_from_objects(outer)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(list.obj()))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densearith.dmp_expand", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_from_sympy(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals(f)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dup_from_sympy", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_from_sympy(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj(f)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dmp_from_sympy", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_exclude(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dmp_exclude", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_include(
  f : DenseData,
  jlist : Array[Int],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::IntList(jlist))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dmp_include", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_terms_gcd(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dup_terms_gcd", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_terms_gcd(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dmp_terms_gcd", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_list_terms(
  f : DenseData,
  u : Int,
  order? : String = "",
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let kwargs : Map[String, OracleArg] = {}
  if order != "" {
    kwargs["order"] = OracleArg::Str(order)
  }
  let res = sympy_call_must("sympy.polys.densebasic.dmp_list_terms", args, kwargs~)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_slice(
  f : Array[@symnum.BigRational],
  m : Int,
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dup_slice", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_slice(
  f : DenseData,
  m : Int,
  n : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dmp_slice", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_slice_in(
  f : DenseData,
  m : Int,
  n : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(n))
  args.push(OracleArg::Int(j))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densebasic.dmp_slice_in", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn symmetrize(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(expr)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if formal {
    kwargs["formal"] = OracleArg::Bool(true)
  }
  if !symbols.is_empty() {
    let sym_objs = sympy_symbols_from_names(symbols)
    let list = py_list_from_objects(sym_objs)
    kwargs["symbols"] = OracleArg::PyObj(list.obj())
  }
  let res = sympy_call_must("sympy.symmetrize", args, kwargs~)
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("symmetrize tuple") }
  let sym_str = py_sympy_expr_str(items[0])
  let rem_str = py_sympy_expr_str(items[1])
  if formal {
    let mapping_enum = @py.PyObjectEnum::create(items[2])
    let mapping_items = py_list_to_pyobjects(mapping_enum)
    let parts : Array[String] = Array::new()
    for pair in mapping_items {
      let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
      if pair_items.length() >= 2 {
        let s_str = py_sympy_expr_str(pair_items[0])
        let e_str = py_sympy_expr_str(pair_items[1])
        parts.push("(\{s_str}, \{e_str})")
      }
    }
    let joined = parts.join(", ")
    let mapping_str = "[\{joined}]"
    "\{sym_str}||\{rem_str}||\{mapping_str}"
  } else {
    "\{sym_str}||\{rem_str}"
  }
}

///|
pub fn symmetrize_list(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> String raise {
  let expr_objs : Array[@py.PyObject] = Array::new()
  for expr in exprs {
    expr_objs.push(expr_to_sympy(expr))
  }
  let expr_list = py_list_from_objects(expr_objs)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_list.obj()))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if formal {
    kwargs["formal"] = OracleArg::Bool(true)
  }
  if !symbols.is_empty() {
    let sym_objs = sympy_symbols_from_names(symbols)
    let list = py_list_from_objects(sym_objs)
    kwargs["symbols"] = OracleArg::PyObj(list.obj())
  }
  let res = sympy_call_must("sympy.symmetrize", args, kwargs~)
  if formal {
    let items = py_list_to_pyobjects(res)
    guard items.length() >= 2 else { fail("symmetrize list tuple") }
    let list_enum = @py.PyObjectEnum::create(items[0])
    let list_items = py_list_to_pyobjects(list_enum)
    let pair_parts : Array[String] = Array::new()
    for pair in list_items {
      let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
      if pair_items.length() >= 2 {
        let s_str = py_sympy_expr_str(pair_items[0])
        let r_str = py_sympy_expr_str(pair_items[1])
        pair_parts.push("(\{s_str}, \{r_str})")
      }
    }
    let pairs_joined = pair_parts.join(", ")
    let list_str = "[\{pairs_joined}]"
    let mapping_enum = @py.PyObjectEnum::create(items[1])
    let mapping_items = py_list_to_pyobjects(mapping_enum)
    let mapping_parts : Array[String] = Array::new()
    for pair in mapping_items {
      let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
      if pair_items.length() >= 2 {
        let s_str = py_sympy_expr_str(pair_items[0])
        let e_str = py_sympy_expr_str(pair_items[1])
        mapping_parts.push("(\{s_str}, \{e_str})")
      }
    }
    let mapping_joined = mapping_parts.join(", ")
    let mapping_str = "[\{mapping_joined}]"
    "\{list_str}||\{mapping_str}"
  } else {
    let items = py_list_to_pyobjects(res)
    let parts : Array[String] = Array::new()
    for pair in items {
      let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
      if pair_items.length() >= 2 {
        let s_str = py_sympy_expr_str(pair_items[0])
        let r_str = py_sympy_expr_str(pair_items[1])
        parts.push("(\{s_str}, \{r_str})")
      }
    }
    let joined = parts.join(", ")
    "[\{joined}]"
  }
}

///|
pub fn horner(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  wrt? : String = "",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(expr)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(OracleArg::PyObj(gen))
    }
  }
  let kwargs : Map[String, OracleArg] = {}
  if wrt != "" {
    kwargs["wrt"] = OracleArg::PyObj(sympy_symbol_obj(wrt))
  }
  let res = sympy_call_must("sympy.horner", args, kwargs~)
  py_sympy_enum_str(res)
}

///|
pub fn viete(
  expr : @symcore.Expr,
  roots? : Array[String] = [],
  gen? : String = "",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(expr)))
  if !roots.is_empty() {
    let root_objs = sympy_symbols_from_names(roots)
    let list = py_list_from_objects(root_objs)
    args.push(OracleArg::PyObj(list.obj()))
  }
  if gen != "" {
    args.push(OracleArg::PyObj(sympy_symbol_obj(gen)))
  }
  let res = sympy_call_must("sympy.viete", args)
  py_sympy_enum_str(res)
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
pub fn dup_integrate(
  f : Array[@symnum.BigRational],
  m : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dup_integrate", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_integrate(
  f : DenseData,
  m : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_integrate", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_integrate_in(
  f : DenseData,
  m : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(j))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_integrate_in", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_diff(
  f : Array[@symnum.BigRational],
  m : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dup_diff", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_diff(
  f : DenseData,
  m : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_diff", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_diff_in(
  f : DenseData,
  m : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(m))
  args.push(OracleArg::Int(j))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_diff_in", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_eval(
  f : Array[@symnum.BigRational],
  a : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(a, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dup_eval", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_eval(
  f : DenseData,
  a : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(a, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_eval", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_eval_in(
  f : DenseData,
  a : @symnum.BigRational,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(a, domain)))
  args.push(OracleArg::Int(j))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_eval_in", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_monic(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(f, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dup_monic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_ground_monic(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(dense_data_to_pyobj_domain(f, domain)))
  args.push(OracleArg::Int(u))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.densetools.dmp_ground_monic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_strip(f : Array[Int]) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_strip", [
    OracleArg::IntList(f),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_trunc(f : Array[Int], p : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_trunc", [
    OracleArg::IntList(f),
    OracleArg::Int(p),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_add(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::IntList(f))
  args.push(OracleArg::IntList(g))
  args.push(OracleArg::Int(p))
  args.push(OracleArg::PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_add", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_sub(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::IntList(f))
  args.push(OracleArg::IntList(g))
  args.push(OracleArg::Int(p))
  args.push(OracleArg::PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_sub", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_mul(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::IntList(f))
  args.push(OracleArg::IntList(g))
  args.push(OracleArg::Int(p))
  args.push(OracleArg::PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_mul", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_div(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::IntList(f))
  args.push(OracleArg::IntList(g))
  args.push(OracleArg::Int(p))
  args.push(OracleArg::PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_gcd(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::IntList(f))
  args.push(OracleArg::IntList(g))
  args.push(OracleArg::Int(p))
  args.push(OracleArg::PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_gcd", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_linear(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_linear", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_quadratic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_quadratic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_cubic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_cubic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_quartic(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_quartic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn rootof(
  expr : @symcore.Expr,
  index : Int,
  radicals? : Bool = true,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(expr)))
  args.push(OracleArg::Int(index))
  let kwargs : Map[String, OracleArg] = {}
  if !radicals {
    kwargs["radicals"] = OracleArg::Bool(false)
  }
  let res = sympy_call_must("sympy.polys.rootoftools.rootof", args, kwargs~)
  py_sympy_enum_str(res)
}

///|
pub fn dup_cauchy_upper_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.rootisolation.dup_cauchy_upper_bound", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_cauchy_lower_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.rootisolation.dup_cauchy_lower_bound", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.rootisolation.dup_mignotte_sep_bound_squared", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_sturm(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.rootisolation.dup_sturm", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_refine_real_root(
  coeffs : Array[@symnum.BigRational],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain? : String = "QQ",
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(s, domain)))
  args.push(OracleArg::PyObj(sympy_domain_elem(t, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let kwargs : Map[String, OracleArg] = {}
  match steps {
    Some(k) => kwargs["steps"] = OracleArg::Int(k)
    None => ()
  }
  match eps {
    Some(e) => kwargs["eps"] = OracleArg::PyObj(sympy_domain_elem(e, domain))
    None => ()
  }
  match disjoint {
    Some(d) => kwargs["disjoint"] = OracleArg::PyObj(sympy_domain_elem(d, domain))
    None => ()
  }
  let res = sympy_call_must("sympy.polys.rootisolation.dup_refine_real_root", args, kwargs~)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_isolate_real_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(OracleArg::PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.rootisolation.dup_isolate_real_roots_sqf", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn res_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(p)))
  args.push(OracleArg::PyObj(expr_to_sympy(q)))
  args.push(OracleArg::PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.res", args)
  py_sympy_enum_str(res)
}

///|
pub fn res_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(p)))
  args.push(OracleArg::PyObj(expr_to_sympy(q)))
  args.push(OracleArg::PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.res_q", args)
  py_sympy_enum_str(res)
}

///|
pub fn res_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(p)))
  args.push(OracleArg::PyObj(expr_to_sympy(q)))
  args.push(OracleArg::PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.res_z", args)
  py_sympy_enum_str(res)
}

///|
pub fn subresultants_rem_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[OracleArg] = Array::new()
  args.push(OracleArg::PyObj(expr_to_sympy(p)))
  args.push(OracleArg::PyObj(expr_to_sympy(q)))
  args.push(OracleArg::PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.subresultants_rem", args)
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
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
