///|
/// Convert a MoonBit `Expr` into a live SymPy object by directly
/// constructing SymPy objects (no expression string parsing).
pub fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  let dummy_cache : Map[Int, @py.PyObject] = {}
  let wild_cache : Map[String, @py.PyObject] = {}
  expr_to_sympy_cached(
    @symcore.normalize_legacy_expr(expr),
    dummy_cache,
    wild_cache,
  )
}

///|
fn expr_to_sympy_cached(
  expr : @symcore.Expr,
  dummy_cache : Map[Int, @py.PyObject],
  wild_cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  let expr = @symcore.normalize_legacy_expr(expr)
  match expr {
    @symcore.Expr::Number(n) => sympy_number_obj(n)
    @symcore.Expr::Float(value) => sympy_float_obj(value)
    @symcore.Expr::ComplexFloat(value) => sympy_complex_float_obj(value)
    @symcore.Expr::NumberSymbol(kind) => sympy_number_symbol_obj(kind)
    @symcore.Expr::Symbol(name) => sympy_symbol_or_singleton_set_obj(name)
    @symcore.Expr::Dummy(name, id) => sympy_dummy_obj(name, id, dummy_cache)
    @symcore.Expr::Wild(name, exclude, properties) =>
      sympy_wild_obj(name, exclude, properties, dummy_cache, wild_cache)
    @symcore.Expr::WildFunction(name, nargs) =>
      sympy_wild_function_obj(name, nargs)
    @symcore.Expr::FunctionHead(name) => sympy_function_head_obj(name)
    @symcore.Expr::UndefinedFunction(name) => sympy_undefined_function_obj(name)
    @symcore.Expr::Apply(head, args) =>
      sympy_apply_obj(head, args, dummy_cache, wild_cache)
    @symcore.Expr::Boolean(value) => sympy_bool_obj(value)
    @symcore.Expr::Add(args) =>
      sympy_nary_obj("sympy.Add", args, "0", dummy_cache, wild_cache, kwargs={
        "evaluate": OracleArg::Bool(false),
      })
    @symcore.Expr::Mul(args) =>
      sympy_nary_obj("sympy.Mul", args, "1", dummy_cache, wild_cache, kwargs={
        "evaluate": OracleArg::Bool(false),
      })
    @symcore.Expr::Pow(base, exp) => {
      let base_obj = expr_to_sympy_cached(base, dummy_cache, wild_cache)
      let exp_obj = expr_to_sympy_cached(exp, dummy_cache, wild_cache)
      sympy_call_obj(
        "sympy.Pow",
        [OracleArg::PyObj(base_obj), OracleArg::PyObj(exp_obj)],
        kwargs={ "evaluate": OracleArg::Bool(false) },
      )
    }
    @symcore.Expr::Mod(lhs, rhs) =>
      sympy_call_obj("sympy.Mod", [
        OracleArg::PyObj(expr_to_sympy_cached(lhs, dummy_cache, wild_cache)),
        OracleArg::PyObj(expr_to_sympy_cached(rhs, dummy_cache, wild_cache)),
      ])
    @symcore.Expr::Tuple(args) => {
      let packed : Array[OracleArg] = []
      for arg in args {
        packed.push(
          OracleArg::PyObj(expr_to_sympy_cached(arg, dummy_cache, wild_cache)),
        )
      }
      sympy_call_obj("sympy.Tuple", packed)
    }
    @symcore.Expr::Dict(items) => {
      let packed : Array[OracleArg] = []
      for item in items {
        let (key, value) = item
        let key_obj = expr_to_sympy_cached(key, dummy_cache, wild_cache)
        let value_obj = expr_to_sympy_cached(value, dummy_cache, wild_cache)
        let pair = sympy_call_obj("sympy.Tuple", [
          OracleArg::PyObj(key_obj),
          OracleArg::PyObj(value_obj),
        ])
        packed.push(OracleArg::PyObj(pair))
      }
      sympy_call_obj("sympy.Dict", packed)
    }
    @symcore.Expr::Relational(op, lhs, rhs) => {
      let path = match op {
        @symcore.RelOp::Eq => "sympy.Eq"
        @symcore.RelOp::Ne => "sympy.Ne"
        @symcore.RelOp::Lt => "sympy.Lt"
        @symcore.RelOp::Le => "sympy.Le"
        @symcore.RelOp::Gt => "sympy.Gt"
        @symcore.RelOp::Ge => "sympy.Ge"
      }
      sympy_call_obj(path, [
        OracleArg::PyObj(expr_to_sympy_cached(lhs, dummy_cache, wild_cache)),
        OracleArg::PyObj(expr_to_sympy_cached(rhs, dummy_cache, wild_cache)),
      ])
    }
    @symcore.Expr::Derivative(inner, deriv_args) => {
      let packed : Array[OracleArg] = [
        OracleArg::PyObj(expr_to_sympy_cached(inner, dummy_cache, wild_cache)),
      ]
      for arg in deriv_args {
        packed.push(
          OracleArg::PyObj(expr_to_sympy_cached(arg, dummy_cache, wild_cache)),
        )
      }
      sympy_call_obj("sympy.Derivative", packed)
    }
    @symcore.Expr::Subs(inner, variable, value) =>
      sympy_call_obj("sympy.Subs", [
        OracleArg::PyObj(expr_to_sympy_cached(inner, dummy_cache, wild_cache)),
        OracleArg::PyObj(
          expr_to_sympy_cached(variable, dummy_cache, wild_cache),
        ),
        OracleArg::PyObj(expr_to_sympy_cached(value, dummy_cache, wild_cache)),
      ])
    @symcore.Expr::IdentityFunction =>
      sympy_attr_obj("sympy.S.IdentityFunction")
    @symcore.Expr::Lambda(vars, body) =>
      sympy_call_obj("sympy.Lambda", [
        OracleArg::PyObj(expr_to_sympy_cached(vars, dummy_cache, wild_cache)),
        OracleArg::PyObj(expr_to_sympy_cached(body, dummy_cache, wild_cache)),
      ])
    @symcore.Expr::Function(_, _) =>
      abort("legacy function should be normalized before bridging")
  }
}

///|
fn ensure_sympy_module() -> @py.PyModule raise {
  match @py.pyimport("sympy") {
    Some(sympy) => sympy
    None => fail("sympy-missing")
  }
}

///|
fn sympy_attr_obj(path : String) -> @py.PyObject raise {
  let parts : Array[String] = []
  for part in path.trim().split(".") {
    parts.push(part.to_string())
  }
  guard !parts.is_empty() && parts[0] == "sympy" else {
    fail("sympy-attr-invalid:\{path}")
  }
  let mut current = ensure_sympy_module().obj()
  for i in 1..<parts.length() {
    let part = parts[i]
    match current.get_attr(part, print_err=true) {
      Some(obj) => current = objenum_to_obj(obj)
      None => fail("sympy-attr-missing:\{path}")
    }
  }
  current
}

///|
fn sympy_call_obj(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObject raise {
  match sympy_call(path, args, kwargs~) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-call-none:\{path}")
  }
}

///|
pub fn sympy_number_obj(n : @symnum.BigRational) -> @py.PyObject raise {
  if n.is_integral() {
    let num_str = n.numerator().to_string()
    sympy_call_obj("sympy.Integer", [OracleArg::Str(num_str)])
  } else {
    let num_str = n.numerator().to_string()
    let den_str = n.denominator().to_string()
    sympy_call_obj("sympy.Rational", [
      OracleArg::Str(num_str),
      OracleArg::Str(den_str),
    ])
  }
}

///|
fn sympy_float_obj(value : @symcore.Float) -> @py.PyObject raise {
  let dps = @symnum.prec_to_dps(value.precision())
  sympy_call_obj("sympy.Float", [
    OracleArg::Str(value.format(dps~)),
    OracleArg::Int(dps),
  ])
}

///|
fn sympy_bool_obj(value : Bool) -> @py.PyObject raise {
  if value {
    sympy_call_obj("sympy.sympify", [OracleArg::Str("True")])
  } else {
    sympy_call_obj("sympy.sympify", [OracleArg::Str("False")])
  }
}

///|
fn sympy_number_symbol_obj(
  kind : @symcore.NumberSymbolKind,
) -> @py.PyObject raise {
  let name = @symcore.number_symbol_name(kind)
  match sympy_constant_obj(name) {
    Some(obj) => obj
    None => sympy_symbol_obj(name)
  }
}

///|
fn sympy_complex_float_obj(value : @symcore.ComplexFloat) -> @py.PyObject raise {
  let real = sympy_float_obj(value.real_part())
  let imag = sympy_float_obj(value.imag_part())
  let imag_term = sympy_call_obj("sympy.Mul", [
    OracleArg::PyObj(imag),
    OracleArg::PyObj(sympy_symbol_or_const_obj("I")),
  ])
  if @symnum.is_zero(value.to_mpc().imag) {
    real
  } else if @symnum.is_zero(value.to_mpc().real) {
    imag_term
  } else {
    sympy_call_obj("sympy.Add", [
      OracleArg::PyObj(real),
      OracleArg::PyObj(imag_term),
    ])
  }
}

///|
fn sympy_constant_obj(name : String) -> @py.PyObject? {
  let sympy = try? ensure_sympy_module()
  match sympy {
    Ok(mod) =>
      match mod.get_attr(name, print_err=false) {
        Some(obj) => Some(objenum_to_obj(obj))
        None => None
      }
    Err(_) => None
  }
}

///|
fn sympy_symbol_or_const_obj(name : String) -> @py.PyObject raise {
  match name {
    "I"
    | "E"
    | "pi"
    | "oo"
    | "zoo"
    | "nan"
    | "GoldenRatio"
    | "EulerGamma"
    | "Catalan" =>
      match sympy_constant_obj(name) {
        Some(obj) => obj
        None => sympy_symbol_obj(name)
      }
    _ => sympy_symbol_obj(name)
  }
}

///|
fn sympy_symbol_or_singleton_set_obj(name : String) -> @py.PyObject raise {
  match name {
    "EmptySet"
    | "UniversalSet"
    | "Naturals"
    | "Naturals0"
    | "Integers"
    | "Rationals"
    | "Reals"
    | "Complexes" =>
      match sympy_constant_obj(name) {
        Some(obj) => obj
        None => sympy_symbol_obj(name)
      }
    _ => sympy_symbol_obj(name)
  }
}

///|
fn sympy_symbol_obj(name : String) -> @py.PyObject raise {
  sympy_call_obj("sympy.symbols", [OracleArg::Str(name)])
}

///|
fn sympy_canonical_head_expr(name : String) -> String? {
  match name {
    "Zero" => Some("sympy.Integer(0).func")
    "One" => Some("sympy.Integer(1).func")
    "NegativeOne" => Some("sympy.Integer(-1).func")
    "Half" => Some("sympy.Rational(1, 2).func")
    "Pi" => Some("sympy.pi.func")
    "Exp1" => Some("sympy.E.func")
    "ImaginaryUnit" => Some("sympy.I.func")
    "Infinity" => Some("sympy.oo.func")
    "NegativeInfinity" => Some("(-sympy.oo).func")
    "ComplexInfinity" => Some("sympy.zoo.func")
    "NaN" => Some("sympy.nan.func")
    "BooleanTrue" => Some("sympy.S.true.func")
    "BooleanFalse" => Some("sympy.S.false.func")
    _ => None
  }
}

///|
fn sympy_eval_obj(code : String) -> @py.PyObject raise {
  let builtins = match @py.pyimport("builtins") {
    Some(mod) => mod
    None => fail("py-builtins-missing")
  }
  let eval_obj = match builtins.get_attr("eval", print_err=true) {
    Some(obj) => obj
    None => fail("py-eval-missing")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", ensure_sympy_module().obj())
  let args = py_pack_args([
    OracleArg::Str(code),
    OracleArg::PyObj(globals.obj()),
  ])
  let callable = @py.PyCallable::create(objenum_to_obj(eval_obj)) catch {
    _ => fail("py-eval-callable")
  }
  match py_call_object(callable, args) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("py-eval-none")
  }
}

///|
fn sympy_function_head_obj(name : String) -> @py.PyObject raise {
  match sympy_canonical_head_expr(name) {
    Some(code) => sympy_eval_obj(code)
    None =>
      match sympy_constant_obj(name) {
        Some(obj) => obj
        None => {
          let sympy = ensure_sympy_module()
          match sympy.get_attr(name, print_err=false) {
            Some(obj) => objenum_to_obj(obj)
            None => sympy_call_obj("sympy.Function", [OracleArg::Str(name)])
          }
        }
      }
  }
}

///|
fn sympy_dummy_obj(
  name : String,
  id : Int,
  dummy_cache : Map[Int, @py.PyObject],
) -> @py.PyObject raise {
  match dummy_cache.get(id) {
    Some(obj) => obj
    None => {
      let obj = sympy_call_obj("sympy.Dummy", [OracleArg::Str(name)])
      dummy_cache.set(id, obj)
      obj
    }
  }
}

///|
fn sympy_wild_cache_key(
  name : String,
  exclude : Array[@symcore.Expr],
  properties : Array[@symcore.WildProperty],
) -> String {
  let parts : Array[String] = [name]
  for item in exclude {
    parts.push(@symprint.debug_repr(item))
  }
  for property in properties {
    parts.push(@symcore.wild_property_name(property))
  }
  parts.join("|")
}

///|
fn sympy_wild_property_callable(
  property : @symcore.WildProperty,
) -> @py.PyObject raise {
  let attr = match property {
    @symcore.WildProperty::Symbol => "is_Symbol"
    @symcore.WildProperty::Integer => "is_integer"
    @symcore.WildProperty::Rational => "is_rational"
    @symcore.WildProperty::Real => "is_real"
    @symcore.WildProperty::Positive => "is_positive"
    @symcore.WildProperty::Negative => "is_negative"
    @symcore.WildProperty::Finite => "is_finite"
    @symcore.WildProperty::Nonzero => "is_nonzero"
  }
  sympy_eval_obj("lambda k: getattr(k, '" + attr + "', None)")
}

///|
fn sympy_wild_obj(
  name : String,
  exclude : Array[@symcore.Expr],
  properties : Array[@symcore.WildProperty],
  dummy_cache : Map[Int, @py.PyObject],
  wild_cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  let cache_key = sympy_wild_cache_key(name, exclude, properties)
  match wild_cache.get(cache_key) {
    Some(obj) => obj
    None => {
      let exclude_list = @py.PyList::new()
      for item in exclude {
        exclude_list.append(expr_to_sympy_cached(item, dummy_cache, wild_cache))
      }
      let property_list = @py.PyList::new()
      for property in properties {
        property_list.append(sympy_wild_property_callable(property))
      }
      let obj = sympy_call_obj("sympy.Wild", [OracleArg::Str(name)], kwargs={
        "exclude": OracleArg::PyObj(exclude_list.obj()),
        "properties": OracleArg::PyObj(property_list.obj()),
      })
      wild_cache.set(cache_key, obj)
      obj
    }
  }
}

///|
fn sympy_undefined_function_obj(name : String) -> @py.PyObject raise {
  sympy_call_obj("sympy.Function", [OracleArg::Str(name)])
}

///|
fn sympy_wild_function_obj(
  name : String,
  nargs : Array[Int],
) -> @py.PyObject raise {
  let kwargs : Map[String, OracleArg] = {}
  match nargs {
    [] => ()
    [arity] => kwargs["nargs"] = OracleArg::Int(arity)
    _ => kwargs["nargs"] = OracleArg::IntList(nargs)
  }
  sympy_call_obj("sympy.WildFunction", [OracleArg::Str(name)], kwargs~)
}

///|
fn sympy_apply_obj(
  head : @symcore.Expr,
  args : Array[@symcore.Expr],
  dummy_cache : Map[Int, @py.PyObject],
  wild_cache : Map[String, @py.PyObject],
) -> @py.PyObject raise {
  match @symcore.function_head_name(head) {
    Some("Piecewise") if args.length() % 2 == 0 => {
      let pair_objs : Array[@py.PyObject] = Array::new()
      let mut i = 0
      while i + 1 < args.length() {
        let expr_obj = expr_to_sympy_cached(args[i], dummy_cache, wild_cache)
        let cond_obj = expr_to_sympy_cached(
          args[i + 1],
          dummy_cache,
          wild_cache,
        )
        let pair = sympy_call_obj("sympy.Tuple", [
          OracleArg::PyObj(expr_obj),
          OracleArg::PyObj(cond_obj),
        ])
        pair_objs.push(pair)
        i += 2
      }
      let head_obj = expr_to_sympy_cached(head, dummy_cache, wild_cache)
      let callable = @py.PyCallable::create(head_obj) catch {
        _ => fail("sympy-apply-callable")
      }
      return call_callable(callable, pair_objs)
    }
    Some("Union") | Some("Intersection") | Some("Complement") => {
      let arg_objs : Array[OracleArg] = Array::new()
      for arg in args {
        arg_objs.push(
          OracleArg::PyObj(expr_to_sympy_cached(arg, dummy_cache, wild_cache)),
        )
      }
      let path = match @symcore.function_head_name(head) {
        Some(name) => "sympy.\{name}"
        None => fail("sympy-set-op-head")
      }
      return sympy_call_obj(path, arg_objs, kwargs={
        "evaluate": OracleArg::Bool(false),
      })
    }
    _ => ()
  }
  let arg_objs : Array[@py.PyObject] = Array::new()
  for arg in args {
    arg_objs.push(expr_to_sympy_cached(arg, dummy_cache, wild_cache))
  }
  let head_obj = expr_to_sympy_cached(head, dummy_cache, wild_cache)
  let callable = @py.PyCallable::create(head_obj) catch {
    _ => fail("sympy-apply-callable")
  }
  call_callable(callable, arg_objs)
}

///|
fn sympy_nary_obj(
  path : String,
  args : Array[@symcore.Expr],
  identity : String,
  dummy_cache : Map[Int, @py.PyObject],
  wild_cache : Map[String, @py.PyObject],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObject raise {
  if args.is_empty() {
    return sympy_call_obj("sympy.Integer", [OracleArg::Str(identity)])
  }
  let packed : Array[OracleArg] = Array::new()
  for arg in args {
    packed.push(
      OracleArg::PyObj(expr_to_sympy_cached(arg, dummy_cache, wild_cache)),
    )
  }
  sympy_call_obj(path, packed, kwargs~)
}

///|
fn call_callable(
  callable : @py.PyCallable,
  args : Array[@py.PyObject],
) -> @py.PyObject raise {
  let tup = py_tuple_from_objects(args)
  let res = py_call_object(callable, tup, print_err=true)
  match res {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-callable-none")
  }
}

///|
pub fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  let out = match obj {
    PyBool(v) => v.obj()
    PyCallable(v) => v.obj()
    PyClass(v) => v
    PyDict(v) => v.obj()
    PyFloat(v) => v.obj()
    PyInteger(v) => v.obj()
    PyList(v) => v.obj()
    PyModule(v) => v.obj()
    PyString(v) => v.obj()
    PyTuple(v) => v.obj()
  }
  let state = py_gil_ensure()
  @cpython.py_incref(out.obj_ref())
  py_gil_release(state)
  out
}
