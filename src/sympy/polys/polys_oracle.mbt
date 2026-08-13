///|
type LegacyArg = @sympy.OracleArg

///|
fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object(callable, args, print_err~)
}

///|
fn py_call_object_allow_none(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object_allow_none(callable, args, print_err~)
}

///|
fn py_call_object_kwargs(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  kwargs? : @py.PyDict = @py.PyDict::new(),
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object_kwargs(callable, args, kwargs~, print_err~)
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
fn sympy_call(
  path : String,
  args : Array[LegacyArg],
  kwargs? : Map[String, LegacyArg] = {},
) -> @py.PyObjectEnum? raise {
  @sympy.sympy_call(path, args, kwargs~)
}

///|
fn ensure_python() -> Unit {
  @sympy.ensure_python()
}

///|
fn sympy_number_obj(n : @symnum.BigRational) -> @py.PyObject raise {
  @sympy.sympy_number_obj(n)
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
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
pub fn sympify_pythonrational(num : Int, den : Int) -> String raise {
  let rational = sympy_call_must(
    "sympy.polys.domains.pythonrational.PythonRational",
    [Int(num), Int(den)],
  )
  let res = sympy_call_must(
    "sympy.polys.domains.pythonrational.sympify_pythonrational",
    [PyObj(objenum_to_obj(rational))],
  )
  py_str_enum(res)
}

///|
pub fn wrap(text : String, width? : Int = 80) -> String raise {
  let res = sympy_call_must("sympy.polys.numberfields.galois_resolvents.wrap", [
    Str(text),
    Int(width),
  ])
  py_str_enum(res)
}

///|
fn oracle_ring_element_from_expr(
  ring_obj : @py.PyObject,
  expr : @symcore.Expr,
) -> @py.PyObject raise {
  let from_expr = resolve_method_callable(ring_obj, "from_expr")
  objenum_to_obj(py_call_one(from_expr, expr_to_sympy(expr)))
}

///|
pub fn modgcd_univariate(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gen? : String = "x",
) -> String raise {
  oracle_modgcd("sympy.polys.modulargcd.modgcd_univariate", f, g, gen)
}

///|
pub fn modgcd_bivariate(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : String = "x,y",
) -> String raise {
  oracle_modgcd("sympy.polys.modulargcd.modgcd_bivariate", f, g, gens)
}

///|
pub fn modgcd_multivariate(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : String = "x,y,z",
) -> String raise {
  oracle_modgcd("sympy.polys.modulargcd.modgcd_multivariate", f, g, gens)
}

///|
pub fn func_field_modgcd_sqrt2(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : String = "x",
) -> String raise {
  let ring_tuple = sympy_call_must("sympy.polys.rings.ring", [
    Str(gens),
    PyObj(oracle_domain_from_spec("QQ<sqrt(2)>")),
  ])
  let ring_items = py_list_to_pyobjects(ring_tuple)
  guard ring_items.length() >= 1 else { fail("ring-result-shape") }
  let ring_obj = ring_items[0]
  let f_obj = oracle_ring_element_from_expr(ring_obj, f)
  let g_obj = oracle_ring_element_from_expr(ring_obj, g)
  let res = sympy_call_must("sympy.polys.modulargcd.func_field_modgcd", [
    PyObj(f_obj),
    PyObj(g_obj),
  ])
  let parts = py_list_to_pyobjects(res)
  guard parts.length() == 3 else { fail("func-field-modgcd-result-shape") }
  let h = oracle_poly_element_as_expr(parts[0])
  let cff = oracle_poly_element_as_expr(parts[1])
  let cfg = oracle_poly_element_as_expr(parts[2])
  "(\{h},\{cff},\{cfg})"
}

///|
fn oracle_poly_element_as_expr(poly : @py.PyObject) -> String raise {
  let as_expr = resolve_method_callable(poly, "as_expr")
  let expr = py_call_noargs(as_expr)
  remove_spaces(sympy_normalize(py_str_enum(expr)))
}

///|
fn oracle_modgcd(
  path : String,
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens : String,
) -> String raise {
  let ring_tuple = sympy_call_must("sympy.polys.rings.ring", [
    Str(gens),
    PyObj(oracle_domain_from_spec("ZZ")),
  ])
  let ring_items = py_list_to_pyobjects(ring_tuple)
  guard ring_items.length() >= 1 else { fail("ring-result-shape") }
  let ring_obj = ring_items[0]
  let f_obj = oracle_ring_element_from_expr(ring_obj, f)
  let g_obj = oracle_ring_element_from_expr(ring_obj, g)
  let res = sympy_call_must(path, [PyObj(f_obj), PyObj(g_obj)])
  let parts = py_list_to_pyobjects(res)
  guard parts.length() == 3 else { fail("modgcd-result-shape") }
  let h = remove_spaces(sympy_normalize(py_str_obj(parts[0])))
  let cff = remove_spaces(sympy_normalize(py_str_obj(parts[1])))
  let cfg = remove_spaces(sympy_normalize(py_str_obj(parts[2])))
  "(\{h},\{cff},\{cfg})"
}

///|
pub fn domain_repr(spec : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  recipe.builder.request_str(domain)
}

///|
pub fn domain_characteristic(spec : String) -> Int raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.method_call(domain, "characteristic", [])
  parse_domain_int(recipe.builder.request_int(result))
}

///|
fn domain_attr_bool(spec : String, attr : String) -> Bool raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let value = recipe.builder.getattr(domain, attr)
  recipe.builder.request_bool(recipe.attr_is_true(value))
}

///|
pub fn domain_attr_bool_query(spec : String, attr : String) -> Bool raise {
  domain_attr_bool(spec, attr)
}

///|
pub fn domain_attr_bool_or_false(spec : String, attr : String) -> Bool raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let fallback = recipe.builder.value(Bool(false))
  let value = recipe.builder.getattr_or(domain, attr, fallback)
  recipe.builder.request_bool(recipe.attr_is_true(value))
}

///|
pub fn domain_is_field(spec : String) -> Bool raise {
  domain_attr_bool(spec, "is_Field")
}

///|
pub fn domain_is_ring(spec : String) -> Bool raise {
  domain_attr_bool(spec, "is_Ring")
}

///|
pub fn domain_is_exact(spec : String) -> Bool raise {
  domain_attr_bool(spec, "is_Exact")
}

///|
pub fn domain_is_finite_field(spec : String) -> Bool raise {
  domain_attr_bool(spec, "is_FiniteField")
}

///|
pub fn domain_get_field(spec : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.method_call(domain, "get_field", [])
  recipe.builder.request_str(result)
}

///|
pub fn domain_get_exact(spec : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.method_call(domain, "get_exact", [])
  recipe.builder.request_str(result)
}

///|
pub fn domain_get_ring(spec : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(domain, "get_ring", [])
  recipe.request_captured_str(result)
}

///|
pub fn domain_unify(lhs_spec : String, rhs_spec : String) -> String raise {
  let recipe = DomainRecipe::new()
  let lhs = recipe.domain(lhs_spec)
  let rhs = recipe.domain(rhs_spec)
  let result = recipe.method_call(lhs, "unify", [Ref(rhs)])
  recipe.builder.request_str(result)
}

///|
pub fn domain_poly_ring(spec : String, gens : Array[String]) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(
    domain,
    "poly_ring",
    recipe.symbols(gens),
  )
  recipe.request_captured_str(result)
}

///|
pub fn domain_frac_field(spec : String, gens : Array[String]) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(
    domain,
    "frac_field",
    recipe.symbols(gens),
  )
  recipe.request_captured_str(result)
}

///|
pub fn domain_old_poly_ring(
  spec : String,
  gens : Array[String],
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(
    domain,
    "old_poly_ring",
    recipe.symbols(gens),
  )
  recipe.request_captured_str(result)
}

///|
pub fn domain_old_frac_field(
  spec : String,
  gens : Array[String],
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(
    domain,
    "old_frac_field",
    recipe.symbols(gens),
  )
  recipe.request_captured_str(result)
}

///|
pub fn domain_set_domain(spec : String, ground_spec : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let ground = recipe.domain(ground_spec)
  let result = recipe.captured_method_call(domain, "set_domain", [Ref(ground)])
  recipe.request_captured_str(result)
}

///|
pub fn domain_unify_with_symbols(
  lhs_spec : String,
  rhs_spec : String,
  symbols : Array[String],
) -> String raise {
  let recipe = DomainRecipe::new()
  let lhs = recipe.domain(lhs_spec)
  let rhs = recipe.domain(rhs_spec)
  let symbol_tuple = recipe.builder.tuple(recipe.symbols(symbols))
  let result = recipe.captured_method_call(lhs, "unify_with_symbols", [
    Ref(rhs),
    Ref(symbol_tuple),
  ])
  recipe.request_captured_str(result)
}

///|
pub fn domain_unify_composite(
  lhs_spec : String,
  rhs_spec : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let lhs = recipe.domain(lhs_spec)
  let rhs = recipe.domain(rhs_spec)
  let result = recipe.captured_method_call(lhs, "unify_composite", [Ref(rhs)])
  recipe.request_captured_str(result)
}

///|
pub fn domain_algebraic_field(
  spec : String,
  extension : Array[String],
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let args : Array[@recipe.RecipeArg] = []
  for expression in extension {
    args.push(Ref(recipe.sympify(expression)))
  }
  let result = recipe.captured_method_call(domain, "algebraic_field", args)
  recipe.request_captured_str(result)
}

///|
pub fn domain_alg_field_from_poly(
  spec : String,
  poly_expr : String,
  gen : String,
  extension_name? : String? = None,
  root_index? : Int = -1,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let expression = recipe.sympify(poly_expr)
  let generator = recipe.symbol(gen)
  let poly_constructor = recipe.builder.getattr(recipe.sympy, "Poly")
  let poly = recipe.builder.require_non_none(
    recipe.builder.call(poly_constructor, [Ref(expression), Ref(generator)]),
    message="sympy-polys-domain-poly-none",
  )
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  match extension_name {
    Some(name) if name != "" => kwargs["alias"] = Str(name)
    _ => ()
  }
  if root_index != -1 {
    kwargs["root_index"] = DecimalInt(Show::to_string(root_index))
  }
  let result = recipe.method_call(
    domain,
    "alg_field_from_poly",
    [Ref(poly)],
    kwargs~,
  )
  recipe.builder.request_str(result)
}

///|
pub fn domain_cyclotomic_field(
  spec : String,
  n : Int,
  ss? : Bool = false,
  extension_name? : String = "zeta",
  gen? : String? = None,
  root_index? : Int = -1,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let kwargs : Map[String, @recipe.RecipeArg] = {
    "ss": Bool(ss),
    "alias": Str(extension_name),
  }
  match gen {
    Some(name) if name != "" => kwargs["gen"] = Ref(recipe.symbol(name))
    _ => ()
  }
  if root_index != -1 {
    kwargs["root_index"] = DecimalInt(Show::to_string(root_index))
  }
  let result = recipe.method_call(
    domain,
    "cyclotomic_field",
    [DecimalInt(Show::to_string(n))],
    kwargs~,
  )
  recipe.builder.request_str(result)
}

///|
pub fn domain_inject(spec : String, gens : Array[String]) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(
    domain,
    "inject",
    recipe.symbols(gens),
  )
  recipe.request_captured_str(result)
}

///|
pub fn domain_drop(spec : String, gens : Array[String]) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.captured_method_call(domain, "drop", recipe.symbols(gens))
  recipe.request_captured_str(result)
}

///|
pub fn domain_contains_expr(spec : String, expr : String) -> Bool raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let expression = recipe.sympify(expr)
  let result = recipe.contains(domain, expression)
  recipe.builder.request_bool(result)
}

///|
pub fn domain_from_sympy_expr(spec : String, expr : String) -> String raise {
  let recipe = DomainRecipe::new()
  let result = domain_from_sympy_graph(recipe, spec, expr)
  recipe.request_domain_str(result.0, result.1)
}

///|
pub fn domain_to_sympy_expr(spec : String, expr : String) -> String raise {
  let recipe = DomainRecipe::new()
  let result = domain_from_sympy_graph(recipe, spec, expr)
  recipe.request_domain_str(result.0, result.1)
}

///|
fn domain_from_sympy_graph(
  recipe : DomainRecipe,
  spec : String,
  expr : String,
) -> (@recipe.ValueRef, @recipe.ValueRef) raise {
  let domain = recipe.domain(spec)
  let expression = recipe.sympify(expr)
  let element = recipe.try_method(
    domain,
    "from_sympy",
    [Ref(expression)],
    recipe.error_sentinel,
  )
  (domain, element)
}

///|
pub fn domain_convert_from_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let base = recipe.domain(base_spec)
  let expression = recipe.sympify(expr)
  let element = recipe.try_method(
    base,
    "from_sympy",
    [Ref(expression)],
    recipe.error_sentinel,
  )
  let converted = recipe.try_method(
    domain,
    "convert_from",
    [Ref(element), Ref(base)],
    recipe.error_sentinel,
  )
  recipe.request_domain_str(domain, converted)
}

///|
pub fn domain_convert_expr(spec : String, expr : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let expression = recipe.sympify(expr)
  let converted = recipe.try_method(
    domain,
    "convert",
    [Ref(expression)],
    recipe.error_sentinel,
  )
  recipe.request_domain_str(domain, converted)
}

///|
pub fn domain_sum_expr(spec : String, exprs : Array[String]) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let elements : Array[@recipe.RecipeArg] = []
  for expr in exprs {
    let expression = recipe.sympify(expr)
    let element = recipe.try_method(
      domain,
      "from_sympy",
      [Ref(expression)],
      recipe.error_sentinel,
    )
    elements.push(Ref(element))
  }
  let result = recipe.sum(domain, elements)
  recipe.request_domain_str(domain, result)
}

///|
fn domain_try_method_from_base_expr(
  spec : String,
  expr : String,
  base_spec : String,
  method_name : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let base = recipe.domain(base_spec)
  let expression = recipe.sympify(expr)
  let element = recipe.try_method(
    base,
    "from_sympy",
    [Ref(expression)],
    recipe.error_sentinel,
  )
  let result = recipe.optional_hook(domain, method_name, element, base)
  recipe.request_domain_str(domain, result)
}

///|
pub fn domain_from_ff_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_FF")
}

///|
pub fn domain_from_ff_python_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_FF_python")
}

///|
pub fn domain_from_zz_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_ZZ")
}

///|
pub fn domain_from_zz_python_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_ZZ_python")
}

///|
pub fn domain_from_qq_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_QQ")
}

///|
pub fn domain_from_qq_python_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_QQ_python")
}

///|
pub fn domain_from_ff_gmpy_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_FF_gmpy")
}

///|
pub fn domain_from_zz_gmpy_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_ZZ_gmpy")
}

///|
pub fn domain_from_qq_gmpy_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_QQ_gmpy")
}

///|
pub fn domain_from_real_field_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_RealField")
}

///|
pub fn domain_from_complex_field_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_ComplexField")
}

///|
fn py_quote_single_polys(text : String) -> String {
  "'" +
  text.replace_all(old="\\", new="\\\\").replace_all(old="'", new="\\'") +
  "'"
}

///|
fn py_exec_polys_result(
  script : String,
  result_expr : String,
) -> @py.PyObject raise {
  let builtins = ensure_builtins_module()
  let exec_obj = match builtins.get_attr("exec", print_err=true) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("builtins-exec-missing")
  }
  let exec_call = @py.PyCallable::create(exec_obj) catch {
    _ => fail("builtins-exec-callable")
  }
  let eval_obj = match builtins.get_attr("eval", print_err=true) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("builtins-eval-missing")
  }
  let eval_call = @py.PyCallable::create(eval_obj) catch {
    _ => fail("builtins-eval-callable")
  }
  let globals = py_dict_new()
  globals.set("__builtins__", builtins.obj())
  globals.set("sympy", ensure_sympy_module_oracle().obj())
  ignore(
    py_call_with_args(
      exec_call,
      [@py.PyString::from(script).obj(), globals.obj()],
      py_dict_new(),
    ),
  )
  objenum_to_obj(
    py_call_with_args(
      eval_call,
      [@py.PyString::from(result_expr).obj(), globals.obj()],
      py_dict_new(),
    ),
  )
}

///|
pub fn to_rational(
  value : String,
  max_denom : String,
  limit? : Bool = true,
) -> String raise {
  let limit_text = if limit { "True" } else { "False" }
  let value_code = py_quote_single_polys(value)
  let denom_code = py_quote_single_polys(max_denom)
  let script = "from sympy import Float\n" +
    "try:\n" +
    "    from sympy.polys.domains.realfield import to_rational as _to_rational\n" +
    "except (ImportError, AttributeError):\n" +
    "    _to_rational = None\n" +
    "_value = Float(\{value_code})\n" +
    "_max_denom = int(\{denom_code})\n" +
    "_limit = \{limit_text}\n" +
    "if _to_rational is not None:\n" +
    "    __result__ = _to_rational(_value, _max_denom, _limit)\n" +
    "else:\n" +
    "    from fractions import Fraction\n" +
    "    from sympy.external.mpmath import to_rational as _mpmath_to_rational\n" +
    "    p, q = _mpmath_to_rational(_value._mpf_)\n" +
    "    p = int(p)\n" +
    "    q = int(q)\n" +
    "    if (not _limit) or q <= _max_denom:\n" +
    "        __result__ = (p, q)\n" +
    "    else:\n" +
    "        p0, q0, p1, q1 = 0, 1, 1, 0\n" +
    "        n, d = p, q\n" +
    "        while True:\n" +
    "            a = n // d\n" +
    "            q2 = q0 + a*q1\n" +
    "            if q2 > _max_denom:\n" +
    "                break\n" +
    "            p0, q0, p1, q1 = p1, q1, p0 + a*p1, q2\n" +
    "            n, d = d, n - a*d\n" +
    "        k = (_max_denom - q0) // q1\n" +
    "        number = Fraction(p, q)\n" +
    "        bound1 = Fraction(p0 + k*p1, q0 + k*q1)\n" +
    "        bound2 = Fraction(p1, q1)\n" +
    "        if not bound2 or not bound1:\n" +
    "            __result__ = (p, q)\n" +
    "        elif abs(bound2 - number) <= abs(bound1 - number):\n" +
    "            __result__ = (bound2.numerator, bound2.denominator)\n" +
    "        else:\n" +
    "            __result__ = (bound1.numerator, bound1.denominator)\n"
  py_str_obj(py_exec_polys_result(script, "__result__"))
}

///|
pub fn domain_from_algebraic_field_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_AlgebraicField")
}

///|
pub fn domain_from_gaussian_integer_ring_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_GaussianIntegerRing",
  )
}

///|
pub fn domain_from_gaussian_rational_field_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_GaussianRationalField",
  )
}

///|
pub fn domain_from_polynomial_ring_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_PolynomialRing")
}

///|
pub fn domain_from_fraction_field_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(spec, expr, base_spec, "from_FractionField")
}

///|
pub fn domain_from_global_polynomial_ring_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_GlobalPolynomialRing",
  )
}

///|
pub fn domain_from_generalized_polynomial_ring_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_GeneralizedPolynomialRing",
  )
}

///|
pub fn domain_from_monogenic_finite_extension_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_MonogenicFiniteExtension",
  )
}

///|
pub fn domain_from_expression_domain_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_ExpressionDomain",
  )
}

///|
pub fn domain_from_expression_raw_domain_expr(
  spec : String,
  expr : String,
  base_spec : String,
) -> String raise {
  domain_try_method_from_base_expr(
    spec, expr, base_spec, "from_ExpressionRawDomain",
  )
}

///|
fn domain_attr_element_expr(spec : String, attr_name : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.try_attr(domain, attr_name)
  recipe.request_domain_str(domain, result)
}

///|
fn domain_unary_element_expr(
  spec : String,
  expr : String,
  method_name : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.unary_element_method(domain, method_name, expr)
  recipe.request_domain_str(domain, result)
}

///|
fn domain_binary_element_expr(
  spec : String,
  left : String,
  right : String,
  method_name : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.binary_element_method(domain, method_name, left, right)
  recipe.request_domain_str(domain, result)
}

///|
fn domain_unary_element_predicate_expr(
  spec : String,
  expr : String,
  method_name : String,
) -> Bool raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.element_predicate(domain, method_name, expr)
  recipe.builder.request_bool(result)
}

///|
fn domain_binary_element_predicate_expr(
  spec : String,
  left : String,
  right : String,
  method_name : String,
) -> Bool raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.binary_element_predicate(domain, method_name, left, right)
  recipe.builder.request_bool(result)
}

///|
pub fn domain_zero_expr(spec : String) -> String raise {
  domain_attr_element_expr(spec, "zero")
}

///|
pub fn domain_one_expr(spec : String) -> String raise {
  domain_attr_element_expr(spec, "one")
}

///|
pub fn domain_pos_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "pos")
}

///|
pub fn domain_neg_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "neg")
}

///|
pub fn domain_add_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "add")
}

///|
pub fn domain_sub_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "sub")
}

///|
pub fn domain_mul_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "mul")
}

///|
pub fn domain_pow_expr(spec : String, expr : String, exp : Int) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let element = recipe.element(domain, expr)
  let result = recipe.try_method(
    domain,
    "pow",
    [Ref(element), DecimalInt(Show::to_string(exp))],
    recipe.error_sentinel,
  )
  recipe.request_domain_str(domain, result)
}

///|
pub fn domain_half_gcdex_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let lhs = recipe.element(domain, left)
  let rhs = recipe.element(domain, right)
  let result = recipe.half_gcdex(domain, lhs, rhs)
  recipe.builder.request_str(result)
}

///|
pub fn domain_gcdex_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.binary_element_method(domain, "gcdex", left, right)
  let rendered = recipe.render_tuple_result(
    domain,
    result,
    [DecimalInt("0"), DecimalInt("1"), DecimalInt("2")],
    3,
    true,
    true,
  )
  recipe.builder.request_str(rendered)
}

///|
pub fn domain_invert_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "invert")
}

///|
pub fn domain_revert_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "revert")
}

///|
pub fn domain_is_unit_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_unit")
}

///|
pub fn domain_is_zero_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_zero")
}

///|
pub fn domain_is_one_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_one")
}

///|
pub fn domain_is_negative_one_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_negative_one")
}

///|
pub fn domain_is_positive_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_positive")
}

///|
pub fn domain_is_negative_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_negative")
}

///|
pub fn domain_is_nonpositive_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_nonpositive")
}

///|
pub fn domain_is_nonnegative_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_nonnegative")
}

///|
pub fn domain_abs_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "abs")
}

///|
pub fn domain_canonical_unit_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "canonical_unit")
}

///|
pub fn domain_gcd_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "gcd")
}

///|
pub fn domain_lcm_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "lcm")
}

///|
pub fn domain_cofactors_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.binary_element_method(domain, "cofactors", left, right)
  let rendered = recipe.render_tuple_result(
    domain,
    result,
    [DecimalInt("0"), DecimalInt("1"), DecimalInt("2")],
    3,
    false,
    false,
  )
  recipe.builder.request_str(rendered)
}

///|
pub fn domain_numer_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "numer")
}

///|
pub fn domain_denom_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "denom")
}

///|
pub fn domain_quo_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "quo")
}

///|
pub fn domain_rem_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "rem")
}

///|
pub fn domain_div_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let result = recipe.binary_element_method(domain, "div", left, right)
  let rendered = recipe.render_tuple_result(
    domain,
    result,
    [DecimalInt("0"), DecimalInt("1")],
    2,
    false,
    false,
  )
  recipe.builder.request_str(rendered)
}

///|
pub fn domain_exquo_expr(
  spec : String,
  left : String,
  right : String,
) -> String raise {
  domain_binary_element_expr(spec, left, right, "exquo")
}

///|
pub fn domain_factorial_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "factorial")
}

///|
pub fn domain_log_expr(
  spec : String,
  value : String,
  base : String,
) -> String raise {
  domain_binary_element_expr(spec, value, base, "log")
}

///|
pub fn domain_sqrt_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "sqrt")
}

///|
pub fn domain_is_square_expr(spec : String, expr : String) -> Bool raise {
  domain_unary_element_predicate_expr(spec, expr, "is_square")
}

///|
pub fn domain_exsqrt_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "exsqrt")
}

///|
pub fn domain_real_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "real")
}

///|
pub fn domain_imag_expr(spec : String, expr : String) -> String raise {
  domain_unary_element_expr(spec, expr, "imag")
}

///|
pub fn domain_almosteq_expr(
  spec : String,
  left : String,
  right : String,
) -> Bool raise {
  domain_binary_element_predicate_expr(spec, left, right, "almosteq")
}

///|
pub fn domain_evalf_expr(spec : String, expr : String) -> String raise {
  let recipe = DomainRecipe::new()
  let domain = recipe.domain(spec)
  let element = recipe.element(domain, expr)
  let result = recipe.evalf(domain, element)
  recipe.builder.request_str(result)
}

///|
pub fn numberfield_minpoly(expr : String, gen? : String = "x") -> String raise {
  let expr_obj = sympy_sympify_str(expr)
  let gen_obj = sympy_symbol_obj(gen)
  let minpoly = sympy_call_must("sympy.polys.numberfields.minpoly", [
    PyObj(expr_obj),
    PyObj(gen_obj),
  ])
  py_str_enum(minpoly)
}

///|
pub fn numberfield_primitive_coeffs(
  exprs : Array[String],
  gen? : String = "x",
) -> Array[Int] raise {
  let expr_objs : Array[@py.PyObject] = Array::new()
  for expr in exprs {
    expr_objs.push(sympy_sympify_str(expr))
  }
  let list_obj = py_list_from_objects(expr_objs).obj()
  let gen_obj = sympy_symbol_obj(gen)
  let res = sympy_call_must("sympy.polys.numberfields.primitive_element", [
    PyObj(list_obj),
    PyObj(gen_obj),
  ])
  let tuple_items = py_list_to_pyobjects(res)
  guard tuple_items.length() >= 2 else {
    fail("primitive-element-result-shape")
  }
  let coeff_items = py_list_to_pyobjects(
    @py.PyObjectEnum::create(tuple_items[1]),
  )
  let coeffs : Array[Int] = Array::new()
  for item in coeff_items {
    coeffs.push(py_obj_to_int(item))
  }
  coeffs
}

///|
pub fn numberfield_primitive_reps(
  exprs : Array[String],
  gen? : String = "x",
) -> String raise {
  let expr_objs : Array[@py.PyObject] = Array::new()
  for expr in exprs {
    expr_objs.push(sympy_sympify_str(expr))
  }
  let list_obj = py_list_from_objects(expr_objs).obj()
  let gen_obj = sympy_symbol_obj(gen)
  let kwargs : Map[String, LegacyArg] = { "ex": Bool(true) }
  let res = sympy_call_must(
    "sympy.polys.numberfields.primitive_element",
    [PyObj(list_obj), PyObj(gen_obj)],
    kwargs~,
  )
  let tuple_items = py_list_to_pyobjects(res)
  guard tuple_items.length() >= 3 else {
    fail("primitive-element-ex-result-shape")
  }
  let reps_obj = @py.PyObjectEnum::create(tuple_items[2])
  let rows = py_list_to_pyobjects(reps_obj)
  let row_parts : Array[String] = Array::new()
  for row in rows {
    let coeff_objs = py_list_to_pyobjects(@py.PyObjectEnum::create(row))
    let coeff_parts : Array[String] = Array::new()
    for coeff in coeff_objs {
      let q = sympy_call_must("sympy.Rational", [PyObj(coeff)])
      coeff_parts.push(py_str_enum(q))
    }
    let coeff_joined = coeff_parts.join(",")
    row_parts.push("[\{coeff_joined}]")
  }
  let row_joined = row_parts.join(",")
  "[\{row_joined}]"
}

///|
pub fn numberfield_to_number_field_coeffs(
  lhs : String,
  rhs : String,
) -> String raise {
  let lhs_obj = sympy_sympify_str(lhs)
  let rhs_obj = sympy_sympify_str(rhs)
  let res = sympy_call("sympy.polys.numberfields.to_number_field", [
    PyObj(lhs_obj),
    PyObj(rhs_obj),
  ])
  match res {
    Some(obj) => {
      let coeffs = resolve_method_callable(objenum_to_obj(obj), "coeffs")
      let coeff_obj = py_call_noargs(coeffs)
      py_str_enum(coeff_obj).replace_all(old=" ", new="")
    }
    None => "None"
  }
}

///|
fn py_int_array_literal(values : Array[Int]) -> String {
  "[" + values.map(item => item.to_string()).join(", ") + "]"
}

///|
fn py_col_matrix_literal(values : Array[Int]) -> String {
  "[" + values.map(item => "[\{item}]").join(", ") + "]"
}

///|
pub fn make_mod_elt_power_basis(
  def_expr : String,
  col : Array[Int],
  denom? : Int = 1,
) -> String raise {
  let def_code = py_quote_single_polys(def_expr)
  let col_code = py_col_matrix_literal(col)
  let script = "from sympy import Poly, symbols, sympify\n" +
    "from sympy.polys.domains import ZZ\n" +
    "from sympy.polys.matrices import DomainMatrix\n" +
    "from sympy.polys.numberfields.modules import PowerBasis, make_mod_elt\n" +
    "x = symbols('x')\n" +
    "_module = PowerBasis(Poly(sympify(\{def_code}), x))\n" +
    "_col = DomainMatrix(\{col_code}, (\{col.length()}, 1), ZZ)\n" +
    "_elt = make_mod_elt(_module, _col, denom=\{denom})\n" +
    "__result__ = type(_elt).__name__ + ':' + str(_elt)\n"
  py_str_obj(py_exec_polys_result(script, "__result__"))
}

///|
pub fn make_mod_elt_submodule(
  def_expr : String,
  basis : Array[Array[Int]],
  col : Array[Int],
  denom? : Int = 1,
) -> String raise {
  let def_code = py_quote_single_polys(def_expr)
  let rows = "[" + basis.map(py_int_array_literal).join(", ") + "]"
  let col_code = py_col_matrix_literal(col)
  let script = "from sympy import Poly, symbols, sympify\n" +
    "from sympy.polys.domains import ZZ\n" +
    "from sympy.polys.matrices import DomainMatrix\n" +
    "from sympy.polys.numberfields.modules import PowerBasis, make_mod_elt\n" +
    "x = symbols('x')\n" +
    "_power = PowerBasis(Poly(sympify(\{def_code}), x))\n" +
    "_basis = DomainMatrix(\{rows}, (\{basis.length()}, \{basis.length()}), ZZ)\n" +
    "_module = _power.submodule_from_matrix(_basis)\n" +
    "_col = DomainMatrix(\{col_code}, (\{col.length()}, 1), ZZ)\n" +
    "_elt = make_mod_elt(_module, _col, denom=\{denom})\n" +
    "__result__ = type(_elt).__name__ + ':' + str(_elt)\n"
  py_str_obj(py_exec_polys_result(script, "__result__"))
}

///|
pub fn find_min_poly_power_basis(
  def_expr : String,
  col : Array[Int],
  denom? : Int = 1,
  x? : String = "x",
) -> String raise {
  let def_code = py_quote_single_polys(def_expr)
  let x_code = py_quote_single_polys(x)
  let col_code = py_col_matrix_literal(col)
  let script = "from sympy import Poly, QQ, symbols, sympify\n" +
    "from sympy.polys.domains import ZZ\n" +
    "from sympy.polys.matrices import DomainMatrix\n" +
    "from sympy.polys.numberfields.modules import PowerBasis, find_min_poly, make_mod_elt\n" +
    "_x = symbols(\{x_code})\n" +
    "_module = PowerBasis(Poly(sympify(\{def_code}), _x))\n" +
    "_col = DomainMatrix(\{col_code}, (\{col.length()}, 1), ZZ)\n" +
    "_elt = make_mod_elt(_module, _col, denom=\{denom})\n" +
    "__result__ = find_min_poly(_elt, QQ, x=_x).as_expr()\n"
  py_str_obj(py_exec_polys_result(script, "__result__"))
}

///|
pub fn numberfield_field_isomorphism_coeffs(
  lhs : String,
  rhs : String,
) -> String raise {
  let lhs_obj = sympy_sympify_str(lhs)
  let rhs_obj = sympy_sympify_str(rhs)
  let res = sympy_call("sympy.polys.numberfields.field_isomorphism", [
    PyObj(lhs_obj),
    PyObj(rhs_obj),
  ])
  match res {
    Some(obj) => py_str_enum(obj).replace_all(old=" ", new="")
    None => "None"
  }
}

///|
pub fn numberfield_field_isomorphic(lhs : String, rhs : String) -> Bool raise {
  let lhs_obj = sympy_sympify_str(lhs)
  let rhs_obj = sympy_sympify_str(rhs)
  let res = sympy_call("sympy.polys.numberfields.field_isomorphism", [
    PyObj(lhs_obj),
    PyObj(rhs_obj),
  ])
  match res {
    Some(_) => true
    None => false
  }
}

///|
pub fn numberfield_is_rat(expr : String) -> Bool raise {
  let expr_obj = sympy_sympify_str(expr)
  let res = sympy_call_must("sympy.polys.numberfields.utilities.is_rat", [
    PyObj(expr_obj),
  ])
  py_str_enum(res) == "True"
}

///|
pub fn numberfield_is_int(expr : String) -> Bool raise {
  let expr_obj = sympy_sympify_str(expr)
  let res = sympy_call_must("sympy.polys.numberfields.utilities.is_int", [
    PyObj(expr_obj),
  ])
  py_str_enum(res) == "True"
}

///|
pub fn numberfield_get_num_denom(expr : String) -> String raise {
  let expr_obj = sympy_sympify_str(expr)
  let res = sympy_call_must(
    "sympy.polys.numberfields.utilities.get_num_denom",
    [PyObj(expr_obj)],
  )
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("numberfield-get-num-denom") }
  "(\{py_str_obj(items[0])},\{py_str_obj(items[1])})"
}

///|
pub fn numberfield_to_col(coeffs : Array[Int]) -> String raise {
  let res = sympy_call_must("sympy.polys.numberfields.modules.to_col", [
    PyObj(py_list_from_ints(coeffs)),
  ])
  let matrix = resolve_method_callable(objenum_to_obj(res), "to_Matrix")
  py_sympy_enum_str(py_call_noargs(matrix))
}

///|
pub fn numberfield_s_vars(n : Int) -> String raise {
  let res = sympy_call_must(
    "sympy.polys.numberfields.galois_resolvents.s_vars",
    [Int(n)],
  )
  py_sympy_enum_str(res)
}

///|
pub fn numberfield_is_sq_maxrank_HNF(rows : Array[Array[Int]]) -> Bool raise {
  let dm = oracle_domainmatrix_from_ints(rows, "ZZ")
  let res = sympy_call_must(
    "sympy.polys.numberfields.modules.is_sq_maxrank_HNF",
    [PyObj(dm)],
  )
  py_str_enum(res) == "True"
}

///|
pub fn numberfield_supplement_a_subspace(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let dm = oracle_domainmatrix_from_ints(rows, domain_spec)
  let res = sympy_call_must(
    "sympy.polys.numberfields.utilities.supplement_a_subspace",
    [PyObj(dm)],
  )
  oracle_domainmatrix_to_matrix_str(objenum_to_obj(res))
}

///|
fn numberfield_factor_items_text(dict_obj : @py.PyObject) -> String raise {
  let items_call = resolve_method_callable(dict_obj, "items")
  let items_enum = py_call_noargs(items_call)
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let items_list_enum = py_call_one(list_ctor, objenum_to_obj(items_enum))
  let kvs = py_list_to_pyobjects(items_list_enum)
  let entries : Array[(Int, Int)] = []
  for pair in kvs {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      entries.push((py_obj_to_int(pair_items[0]), py_obj_to_int(pair_items[1])))
    }
  }
  entries.sort_by((a, b) => a.0.compare(b.0))
  let parts : Array[String] = []
  for item in entries {
    parts.push("(\{item.0},\{item.1})")
  }
  let body = parts.join(",")
  "[\{body}]"
}

///|
pub fn numberfield_extract_fundamental_discriminant(a : Int) -> String raise {
  let res = sympy_call_must(
    "sympy.polys.numberfields.utilities.extract_fundamental_discriminant",
    [Int(a)],
  )
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else {
    fail("numberfield-extract-fundamental-discriminant")
  }
  let d = numberfield_factor_items_text(items[0])
  let f = numberfield_factor_items_text(items[1])
  "\{d}||\{f}"
}

///|
pub fn numberfield_coeff_search(m : Int, r : Int, count : Int) -> String raise {
  let gen = sympy_call_must("sympy.polys.numberfields.utilities.coeff_search", [
    Int(m),
    Int(r),
  ])
  let builtins = ensure_builtins_module()
  let next_call = resolve_callable(builtins, "next")
  let rows : Array[String] = []
  for _ in 0..<count {
    let row_enum = py_call_one(next_call, objenum_to_obj(gen))
    let values = py_list_to_pyobjects(row_enum)
    let parts : Array[String] = []
    for value in values {
      parts.push(py_obj_to_int(value).to_string())
    }
    let body = parts.join(",")
    rows.push("[\{body}]")
  }
  let body = rows.join(",")
  "[\{body}]"
}

///|
pub fn domainmatrix_add(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a, domain)
  let right = recipe.domainmatrix(b, domain)
  let result = recipe.call_method(left, "__add__", [Ref(right)])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_mul(
  a : Array[Array[Int]],
  scalar : Int,
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let scalar_value = recipe.domain_int(domain, scalar)
  let result = recipe.call_method(matrix, "mul", [Ref(scalar_value)])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_truediv_summary(
  a : Array[Array[Int]],
  domain_spec : String,
  scalar_expr : String,
  fmt? : String = "dense",
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain, fmt~)
  let scalar = recipe.scalar_expr(scalar_expr)
  let result = recipe.call_method(matrix, "__truediv__", [Ref(scalar)])
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_matmul(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a, domain)
  let right = recipe.domainmatrix(b, domain)
  let result = recipe.call_method(left, "matmul", [Ref(right)])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_det(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "det", [])
  recipe.request_str(recipe.render_text(result))
}

///|
pub fn domainmatrix_rref(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "rref", [])
  recipe.request_str(recipe.render_rref(result))
}

///|
pub fn domainmatrix_rref_den(
  a : Array[Array[Int]],
  domain_spec : String,
  rref_method? : String = "auto",
  keep_domain? : Bool = true,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "rref_den", [], kwargs={
    "method": Str(rref_method),
    "keep_domain": Bool(keep_domain),
  })
  recipe.request_str(recipe.render_rref_den(result))
}

///|
pub fn domainmatrix_convert_to(
  a : Array[Array[Int]],
  from_domain_spec : String,
  to_domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let source_domain = recipe.domain(from_domain_spec)
  let target_domain = recipe.domain(to_domain_spec)
  let matrix = recipe.domainmatrix(a, source_domain)
  let result = recipe.call_method(matrix, "convert_to", [Ref(target_domain)])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_convert_to_summary(
  a : Array[Array[Int]],
  from_domain_spec : String,
  to_domain_spec : String,
  fmt? : String = "dense",
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let source_domain = recipe.domain(from_domain_spec)
  let target_domain = recipe.domain(to_domain_spec)
  let matrix = recipe.domainmatrix(a, source_domain, fmt~)
  let result = recipe.call_method(matrix, "convert_to", [Ref(target_domain)])
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_to_field(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "to_field", [])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_diagonal(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "diagonal", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_to_list_flat(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "to_list_flat", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_from_list_flat(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let rows = a.length()
  let cols = if rows == 0 { 0 } else { a[0].length() }
  let flat = recipe.flat_domain_ints(a, domain)
  let shape = recipe.shape(rows, cols)
  let result = recipe.call_method(matrix, "from_list_flat", [
    Ref(flat),
    Ref(shape),
    Ref(domain),
  ])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_to_flat_nz(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "to_flat_nz", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_to_dod(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "to_dod", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_from_dod_roundtrip(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let dod = recipe.call_method(matrix, "to_dod", [])
  let shape = recipe.shape(
    a.length(),
    if a.is_empty() {
      0
    } else {
      a[0].length()
    },
  )
  let result = recipe.call_method(matrix, "from_dod", [
    Ref(dod),
    Ref(shape),
    Ref(domain),
  ])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_to_dok(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "to_dok", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_from_dok_roundtrip(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let dok = recipe.call_method(matrix, "to_dok", [])
  let shape = recipe.shape(
    a.length(),
    if a.is_empty() {
      0
    } else {
      a[0].length()
    },
  )
  let result = recipe.call_method(matrix, "from_dok", [
    Ref(dok),
    Ref(shape),
    Ref(domain),
  ])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_nnz(
  a : Array[Array[Int]],
  domain_spec : String,
) -> Int raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "nnz", [])
  recipe.request_int(result)
}

///|
pub fn domainmatrix_pow(
  a : Array[Array[Int]],
  domain_spec : String,
  n : Int,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "pow", [
    DecimalInt(Show::to_string(n)),
  ])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_lu(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "lu", [])
  recipe.request_str(recipe.render_lu(result))
}

///|
pub fn domainmatrix_qr(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "qr", [])
  recipe.request_str(recipe.render_qr(result))
}

///|
pub fn domainmatrix_lu_solve(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let right_hand_side = recipe.domainmatrix(b, domain)
  let result = recipe.call_method(matrix, "lu_solve", [Ref(right_hand_side)])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_fflu(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "fflu", [])
  recipe.request_str(recipe.render_fflu(result))
}

///|
pub fn domainmatrix_charpoly(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "charpoly", [])
  recipe.request_str(recipe.render_text(result))
}

///|
pub fn domainmatrix_charpoly_factor_blocks(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "charpoly_factor_blocks", [])
  recipe.request_str(recipe.render_text(result))
}

///|
pub fn domainmatrix_charpoly_factor_list(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "charpoly_factor_list", [])
  recipe.request_str(recipe.render_text(result))
}

///|
pub fn domainmatrix_scc(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "scc", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_from_list_sympy_expr(
  rows : Array[Array[String]],
  field? : Bool = false,
  gaussian? : Bool = false,
  modulus? : Int? = None,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let (data, row_count, column_count) = recipe.expr_rows(
    rows, "domainmatrix-from-list-sympy-ragged",
  )
  let result = recipe.call_class_method(
    "from_list_sympy",
    [
      DecimalInt(Show::to_string(row_count)),
      DecimalInt(Show::to_string(column_count)),
      Ref(data),
    ],
    kwargs=structural_domain_options(field, gaussian, modulus),
  )
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_from_matrix_expr(
  rows : Array[Array[String]],
  fmt? : String = "sparse",
  field? : Bool = false,
  gaussian? : Bool = false,
  modulus? : Int? = None,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let matrix = recipe.matrix_from_exprs(rows)
  let kwargs = structural_domain_options(field, gaussian, modulus)
  kwargs["fmt"] = Str(fmt)
  let result = recipe.call_class_method("from_Matrix", [Ref(matrix)], kwargs~)
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_choose_domain(
  a : Array[Array[Int]],
  domain_spec : String,
  field? : Bool = false,
  gaussian? : Bool = false,
  modulus? : Int? = None,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(
    matrix,
    "choose_domain",
    [],
    kwargs=structural_domain_options(field, gaussian, modulus),
  )
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_inv(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "inv", [])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_rowspace(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "rowspace", [])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_columnspace(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "columnspace", [])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_nullspace(
  a : Array[Array[Int]],
  domain_spec : String,
  divide_last? : Bool = false,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "nullspace", [], kwargs={
    "divide_last": Bool(divide_last),
  })
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_clear_denoms(
  a : Array[Array[Int]],
  domain_spec : String,
  convert? : Bool = false,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "clear_denoms", [], kwargs={
    "convert": Bool(convert),
  })
  recipe.request_str(recipe.render_advanced("clear_denoms", result))
}

///|
pub fn domainmatrix_clear_denoms_expr(
  a : Array[Array[String]],
  domain_spec : String,
  convert? : Bool = false,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix_expr(a, domain)
  let result = recipe.call_method(matrix, "clear_denoms", [], kwargs={
    "convert": Bool(convert),
  })
  recipe.request_str(recipe.render_advanced("clear_denoms_expr", result))
}

///|
pub fn domainmatrix_clear_denoms_rowwise_expr(
  a : Array[Array[String]],
  domain_spec : String,
  convert? : Bool = false,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix_expr(a, domain)
  let result = recipe.call_method(matrix, "clear_denoms_rowwise", [], kwargs={
    "convert": Bool(convert),
  })
  recipe.request_str(
    recipe.render_advanced("clear_denoms_rowwise_expr", result),
  )
}

///|
pub fn domainmatrix_adj_det(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "adj_det", [])
  recipe.request_str(recipe.render_advanced("adj_det", result))
}

///|
pub fn domainmatrix_adjugate(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "adjugate", [])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_inv_den(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "inv_den", [])
  recipe.request_str(recipe.render_advanced("inv_den", result))
}

///|
pub fn domainmatrix_solve_den(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a, domain)
  let right = recipe.domainmatrix(b, domain)
  let result = recipe.call_method(left, "solve_den", [Ref(right)])
  recipe.request_str(recipe.render_advanced("solve_den", result))
}

///|
pub fn domainmatrix_solve_den_rref(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a, domain)
  let right = recipe.domainmatrix(b, domain)
  let result = recipe.call_method(left, "solve_den_rref", [Ref(right)])
  recipe.request_str(recipe.render_advanced("solve_den_rref", result))
}

///|
pub fn domainmatrix_content_expr(
  a : Array[Array[String]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix_expr(a, domain)
  let result = recipe.call_method(matrix, "content", [])
  recipe.request_str(recipe.render_text(result))
}

///|
pub fn domainmatrix_primitive_expr(
  a : Array[Array[String]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix_expr(a, domain)
  let result = recipe.call_method(matrix, "primitive", [])
  recipe.request_str(recipe.render_advanced("primitive", result))
}

///|
pub fn domainmatrix_cancel_denom_expr(
  a : Array[Array[String]],
  denom_expr : String,
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix_expr(a, domain)
  let denominator = recipe.domain_expr(domain, denom_expr)
  let result = recipe.call_method(matrix, "cancel_denom", [Ref(denominator)])
  recipe.request_str(recipe.render_advanced("cancel_denom", result))
}

///|
pub fn domainmatrix_cancel_denom_elementwise_expr(
  a : Array[Array[String]],
  denom_expr : String,
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix_expr(a, domain)
  let denominator = recipe.domain_expr(domain, denom_expr)
  let result = recipe.call_method(matrix, "cancel_denom_elementwise", [
    Ref(denominator),
  ])
  recipe.request_str(recipe.render_advanced("cancel_denom_elementwise", result))
}

///|
pub fn domainmatrix_adj_poly_det(
  a : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "adj_poly_det", [])
  recipe.request_str(recipe.render_advanced("adj_poly_det", result))
}

///|
pub fn domainmatrix_eval_poly(
  a : Array[Array[Int]],
  coeffs : Array[String],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(a, domain)
  let coefficients = recipe.domain_expr_list(coeffs, domain)
  let result = recipe.call_method(matrix, "eval_poly", [Ref(coefficients)])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_eval_poly_mul(
  a : Array[Array[Int]],
  coeffs : Array[String],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a, domain)
  let right = recipe.domainmatrix(b, domain)
  let coefficients = recipe.domain_expr_list(coeffs, domain)
  let result = recipe.call_method(left, "eval_poly_mul", [
    Ref(coefficients),
    Ref(right),
  ])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_solve_den_charpoly(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a, domain)
  let right = recipe.domainmatrix(b, domain)
  let result = recipe.call_method(left, "solve_den_charpoly", [Ref(right)])
  recipe.request_str(recipe.render_advanced("solve_den_charpoly", result))
}

///|
pub fn ddm_add(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.ddm(a, domain)
  let right = recipe.ddm(b, domain)
  let result = recipe.call_method(left, "__add__", [Ref(right)])
  recipe.request_str(result)
}

///|
pub fn ddm_mul(
  a : Array[Array[Int]],
  scalar : Int,
  domain_spec : String,
) -> String raise {
  let recipe = DdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.ddm(a, domain)
  let scalar_value = recipe.domain_int(domain, scalar)
  let result = recipe.call_method(matrix, "mul", [Ref(scalar_value)])
  recipe.request_str(result)
}

///|
pub fn ddm_matmul(
  a : Array[Array[Int]],
  b : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.ddm(a, domain)
  let right = recipe.ddm(b, domain)
  let result = recipe.call_method(left, "matmul", [Ref(right)])
  recipe.request_str(result)
}

///|
pub fn ddm_det(a : Array[Array[Int]], domain_spec : String) -> String raise {
  let recipe = DdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.ddm(a, domain)
  let result = recipe.call_method(matrix, "det", [])
  recipe.request_str(result)
}

///|
pub fn ddm_rref(a : Array[Array[Int]], domain_spec : String) -> String raise {
  let recipe = DdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.ddm(a, domain)
  let raw_result = recipe.call_method(matrix, "rref", [])
  let rendered = recipe.render_rref(raw_result)
  recipe.request_str(rendered)
}

///|
pub fn ddm_rank(a : Array[Array[Int]], _domain_spec : String) -> Int raise {
  let recipe = DdmRecipe::new()
  let matrix = recipe.matrix(a)
  let result = recipe.call_method(matrix, "rank", [])
  recipe.request_int(result)
}

///|
pub fn ddm_inv(a : Array[Array[Int]], _domain_spec : String) -> String raise {
  let recipe = DdmRecipe::new()
  let matrix = recipe.matrix(a)
  let result = recipe.call_method(matrix, "inv", [])
  recipe.request_str(result)
}

///|
pub fn ddm_nullspace(
  a : Array[Array[Int]],
  _domain_spec : String,
) -> String raise {
  let recipe = DdmRecipe::new()
  let matrix = recipe.matrix(a)
  let result = recipe.call_method(matrix, "nullspace", [])
  recipe.request_str(result)
}

///|
pub fn domainmatrix_lll(a : Array[Array[Int]]) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("ZZ")
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "lll", [])
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn domainmatrix_lll_transform(a : Array[Array[Int]]) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("ZZ")
  let matrix = recipe.domainmatrix(a, domain)
  let result = recipe.call_method(matrix, "lll_transform", [])
  recipe.request_str(recipe.render_advanced("lll_transform", result))
}

///|
pub fn matrix_hnf_code(rows : Array[Array[Int]]) -> String raise {
  let mat = oracle_matrix_from_ints(rows)
  let hnf = sympy_call_must("sympy.matrices.normalforms.hermite_normal_form", [
    PyObj(mat),
  ])
  matrix_obj_to_int_code(objenum_to_obj(hnf))
}

///|
pub fn domainmatrix_invariant_factors(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(rows, domain)
  let smith = recipe.call_path(
    "sympy.polys.matrices.normalforms.smith_normal_form",
    [Ref(matrix)],
  )
  recipe.request_str(recipe.render_smith("invariant_factors", matrix, smith))
}

///|
pub fn domainmatrix_is_smith_normal_form(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> Bool raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(rows, domain)
  let smith = recipe.call_path(
    "sympy.polys.matrices.normalforms.smith_normal_form",
    [Ref(matrix)],
  )
  recipe.request_bool(
    recipe.render_smith("is_smith_normal_form", matrix, smith),
  )
}

///|
pub fn domainmatrix_smith_normal_form(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(rows, domain)
  let smith = recipe.call_path(
    "sympy.polys.matrices.normalforms.smith_normal_form",
    [Ref(matrix)],
  )
  recipe.request_str(recipe.render_smith("smith_normal_form", matrix, smith))
}

///|
pub fn domainmatrix_smith_normal_decomp(
  rows : Array[Array[Int]],
  _domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("ZZ")
  let matrix = recipe.domainmatrix(rows, domain)
  let result = recipe.call_path("sympy.matrices.normalforms._snd", [Ref(matrix)])
  recipe.request_str(recipe.render_advanced("smith_normal_decomp", result))
}

///|
pub fn domainmatrix_dom_eigenvects_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(rows, domain)
  let result = recipe.call_path("sympy.polys.matrices.eigen.dom_eigenvects", [
    Ref(matrix),
  ])
  recipe.request_str(recipe.render_eigen(result))
}

///|
pub fn domainmatrix_internal_solve_summary(
  a_rows : Array[Array[Int]],
  b_rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let left = recipe.domainmatrix(a_rows, domain)
  let right = recipe.domainmatrix(b_rows, domain)
  let result = recipe.call_method(left, "_solve", [Ref(right)])
  recipe.request_str(recipe.render_advanced("internal_solve", result))
}

///|
pub fn domainmatrix_hstack_summary(
  a_rows : Array[Array[Int]],
  a_domain_spec : String,
  a_fmt : String,
  b_rows : Array[Array[Int]],
  b_domain_spec : String,
  b_fmt : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let a_domain = recipe.domain(a_domain_spec)
  let b_domain = recipe.domain(b_domain_spec)
  let left = recipe.domainmatrix(a_rows, a_domain, fmt=a_fmt)
  let right = recipe.domainmatrix(b_rows, b_domain, fmt=b_fmt)
  let result = recipe.call_method(left, "hstack", [Ref(right)])
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_vstack_summary(
  a_rows : Array[Array[Int]],
  a_domain_spec : String,
  a_fmt : String,
  b_rows : Array[Array[Int]],
  b_domain_spec : String,
  b_fmt : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let a_domain = recipe.domain(a_domain_spec)
  let b_domain = recipe.domain(b_domain_spec)
  let left = recipe.domainmatrix(a_rows, a_domain, fmt=a_fmt)
  let right = recipe.domainmatrix(b_rows, b_domain, fmt=b_fmt)
  let result = recipe.call_method(left, "vstack", [Ref(right)])
  recipe.request_str(recipe.render_summary(result))
}

///|
pub fn domainmatrix_unify_summary(
  a_rows : Array[Array[Int]],
  a_domain_spec : String,
  a_fmt : String,
  b_rows : Array[Array[Int]],
  b_domain_spec : String,
  b_fmt : String,
  fmt? : String = "",
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let a_domain = recipe.domain(a_domain_spec)
  let b_domain = recipe.domain(b_domain_spec)
  let left = recipe.domainmatrix(a_rows, a_domain, fmt=a_fmt)
  let right = recipe.domainmatrix(b_rows, b_domain, fmt=b_fmt)
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if fmt != "" {
    kwargs["fmt"] = Str(fmt)
  }
  let result = recipe.call_method(left, "unify", [Ref(right)], kwargs~)
  recipe.request_str(recipe.render_unify(result))
}

///|
pub fn domainscalar_from_expr(expr : String) -> String raise {
  let args = py_list_from_objects([sympy_sympify_str(expr)]).obj()
  let res = sympy_call_must("sympy.polys.constructor.construct_domain", [
    PyObj(args),
  ])
  let tup = py_list_to_pyobjects(res)
  guard tup.length() >= 2 else { fail("domainscalar-construct-domain") }
  let domain = py_str_obj(tup[0])
  let items = py_list_to_pyobjects(@py.PyObjectEnum::create(tup[1]))
  guard items.length() >= 1 else { fail("domainscalar-construct-items") }
  "\{py_str_obj(items[0])}@\{domain}"
}

///|
pub fn linsolve_sympy_dict_to_dm_summary(
  eqs_coeffs : Array[Map[String, String]],
  eqs_rhs : Array[String],
  syms : Array[String],
) -> String raise {
  let py_rows : Array[@py.PyObject] = Array::new()
  for row in eqs_coeffs {
    let py_row = py_dict_new()
    for sym, coeff in row {
      py_dict_set_obj(py_row, sym, sympy_sympify_str(coeff))
    }
    py_rows.push(py_row.obj())
  }
  let py_rhs : Array[@py.PyObject] = Array::new()
  for rhs in eqs_rhs {
    py_rhs.push(sympy_sympify_str(rhs))
  }
  let py_syms : Array[@py.PyObject] = Array::new()
  for sym in syms {
    py_syms.push(py_string_obj(sym))
  }
  let sdm = sympy_call_must("sympy.polys.matrices.linsolve.sympy_dict_to_dm", [
    PyObj(py_list_from_objects(py_rows).obj()),
    PyObj(py_list_from_objects(py_rhs).obj()),
    PyObj(py_list_from_objects(py_syms).obj()),
  ])
  let sdm_obj = objenum_to_obj(sdm)
  let domain = match py_get_attr(sdm_obj, "domain") {
    Some(obj) => py_str_enum(obj)
    None => fail("linsolve-sympy-dict-to-dm-domain")
  }
  let to_ddm = resolve_method_callable(sdm_obj, "to_ddm")
  let dense = py_str_enum(py_call_noargs(to_ddm))
  "\{dense}@\{domain}|sparse"
}

///|
pub fn solvers_eqs_to_matrix_summary(
  eqs_coeffs : Array[Map[String, String]],
  eqs_rhs : Array[String],
  syms : Array[String],
  domain_spec : String,
) -> String raise {
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let convert = resolve_method_callable(domain_obj, "convert")
  let py_rows : Array[@py.PyObject] = Array::new()
  for row in eqs_coeffs {
    let py_row = py_dict_new()
    for sym, coeff in row {
      let converted = py_call_one(convert, sympy_sympify_str(coeff))
      py_dict_set_obj(py_row, sym, objenum_to_obj(converted))
    }
    py_rows.push(py_row.obj())
  }
  let py_rhs : Array[@py.PyObject] = Array::new()
  for rhs in eqs_rhs {
    let converted = py_call_one(convert, sympy_sympify_str(rhs))
    py_rhs.push(objenum_to_obj(converted))
  }
  let py_syms = sympy_symbols_from_names(syms)
  let dm = sympy_call_must("sympy.polys.solvers.eqs_to_matrix", [
    PyObj(py_list_from_objects(py_rows).obj()),
    PyObj(py_list_from_objects(py_rhs).obj()),
    PyObj(py_list_from_objects(py_syms).obj()),
    PyObj(domain_obj),
  ])
  let dm_obj = objenum_to_obj(dm)
  let domain = match py_get_attr(dm_obj, "domain") {
    Some(obj) => py_str_enum(obj)
    None => fail("solvers-eqs-to-matrix-domain")
  }
  "\{oracle_domainmatrix_to_matrix_str(dm_obj)}@\{domain}"
}

///|
pub fn solvers_sympy_eqs_to_ring_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let py_eqs : Array[@py.PyObject] = Array::new()
  for eq in eqs {
    py_eqs.push(sympy_sympify_str(eq))
  }
  let py_syms = sympy_symbols_from_names(syms)
  let res = sympy_call_must("sympy.polys.solvers.sympy_eqs_to_ring", [
    PyObj(py_list_from_objects(py_eqs).obj()),
    PyObj(py_list_from_objects(py_syms).obj()),
  ])
  let parts = py_list_to_pyobjects(res)
  guard parts.length() >= 2 else { fail("solvers-sympy-eqs-to-ring") }
  "\{py_str_obj(parts[0])}||\{py_str_obj(parts[1])}"
}

///|
fn oracle_linsolve_dict_summary(
  dict_obj : @py.PyObject,
  syms : Array[String],
) -> String raise {
  let items_call = resolve_method_callable(dict_obj, "items")
  let items_enum = py_call_noargs(items_call)
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let items_list = py_call_one(list_ctor, objenum_to_obj(items_enum))
  let coeff_map : Map[String, String] = Map([])
  for pair in py_list_to_pyobjects(items_list) {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      coeff_map[py_str_obj(pair_items[0])] = py_str_obj(pair_items[1])
    }
  }
  let parts : Array[String] = Array::new()
  for sym in syms {
    match coeff_map.get(sym) {
      Some(value) => parts.push("\{sym}:\{value}")
      None => ()
    }
  }
  parts.join(",")
}

///|
pub fn linsolve_linear_eq_to_dict_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let py_eqs : Array[@py.PyObject] = Array::new()
  for eq in eqs {
    py_eqs.push(sympy_sympify_str(eq))
  }
  let py_syms = sympy_symbols_from_names(syms)
  let res = sympy_call_must(
    "sympy.polys.matrices.linsolve._linear_eq_to_dict",
    [
      PyObj(py_list_from_objects(py_eqs).obj()),
      PyObj(py_list_from_objects(py_syms).obj()),
    ],
  )
  let parts = py_list_to_pyobjects(res)
  guard parts.length() >= 2 else { fail("linsolve-linear-eq-to-dict") }
  let coeffs = py_list_to_pyobjects(@py.PyObjectEnum::create(parts[0]))
  let ind = py_list_to_pyobjects(@py.PyObjectEnum::create(parts[1]))
  let rows : Array[String] = Array::new()
  for i in 0..<coeffs.length() {
    rows.push(
      "\{oracle_linsolve_dict_summary(coeffs[i], syms)}||\{py_str_obj(ind[i])}",
    )
  }
  rows.join("|")
}

///|
pub fn linsolve_internal_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let py_eqs : Array[@py.PyObject] = Array::new()
  for eq in eqs {
    py_eqs.push(sympy_sympify_str(eq))
  }
  let py_syms = sympy_symbols_from_names(syms)
  let res = sympy_call("sympy.polys.matrices.linsolve._linsolve", [
    PyObj(py_list_from_objects(py_eqs).obj()),
    PyObj(py_list_from_objects(py_syms).obj()),
  ])
  let res_obj = match res {
    Some(obj) => objenum_to_obj(obj)
    None => return "None"
  }
  let parts : Array[String] = Array::new()
  let dict_summary = oracle_linsolve_dict_summary(res_obj, syms)
  if dict_summary == "" {
    for sym in syms {
      parts.push("\{sym}:0")
    }
    return parts.join("|")
  }
  let sol_map : Map[String, String] = Map([])
  let items_call = resolve_method_callable(res_obj, "items")
  let items_enum = py_call_noargs(items_call)
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let items_list = py_call_one(list_ctor, objenum_to_obj(items_enum))
  for pair in py_list_to_pyobjects(items_list) {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      sol_map[py_str_obj(pair_items[0])] = py_str_obj(pair_items[1])
    }
  }
  for sym in syms {
    match sol_map.get(sym) {
      Some(value) => parts.push("\{sym}:\{value}")
      None => parts.push("\{sym}:0")
    }
  }
  parts.join("|")
}

///|
pub fn solvers_solve_lin_sys_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let py_eqs : Array[@py.PyObject] = Array::new()
  for eq in eqs {
    py_eqs.push(sympy_sympify_str(eq))
  }
  let py_syms = sympy_symbols_from_names(syms)
  let prepared = sympy_call_must("sympy.polys.solvers.sympy_eqs_to_ring", [
    PyObj(py_list_from_objects(py_eqs).obj()),
    PyObj(py_list_from_objects(py_syms).obj()),
  ])
  let parts = py_list_to_pyobjects(prepared)
  guard parts.length() >= 2 else { fail("solvers-solve-lin-sys-prepared") }
  let res = sympy_call(
    "sympy.polys.solvers.solve_lin_sys",
    [PyObj(parts[0]), PyObj(parts[1])],
    kwargs={ "_raw": Bool(false) },
  )
  let res_obj = match res {
    Some(obj) => objenum_to_obj(obj)
    None => return "None"
  }
  oracle_linsolve_dict_summary(res_obj, syms)
}

///|
fn oracle_domainmatrix_to_matrix_str(dm_obj : @py.PyObject) -> String raise {
  let to_matrix = resolve_method_callable(dm_obj, "to_Matrix")
  let mat_enum = py_call_noargs(to_matrix)
  py_str_enum(mat_enum)
}

///|
fn matrix_obj_to_int_code(mat_obj : @py.PyObject) -> String raise {
  let tolist = resolve_method_callable(mat_obj, "tolist")
  let list_enum = py_call_noargs(tolist)
  let row_objs = py_list_to_pyobjects(list_enum)
  let row_codes : Array[String] = Array::new()
  for row_obj in row_objs {
    let cell_objs = py_list_to_pyobjects(@py.PyObjectEnum::create(row_obj))
    let cells : Array[String] = Array::new()
    for cell in cell_objs {
      cells.push(py_obj_to_int(cell).to_string())
    }
    row_codes.push(cells.join(","))
  }
  row_codes.join(";")
}

///|
fn oracle_matrix_from_ints(rows : Array[Array[Int]]) -> @py.PyObject raise {
  let row_count = rows.length()
  let col_count = if row_count == 0 { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != col_count {
      fail("matrix-ragged")
    }
  }
  let py_rows : Array[@py.PyObject] = Array::new()
  for row in rows {
    let py_row : Array[@py.PyObject] = Array::new()
    for v in row {
      py_row.push(py_int_obj(v))
    }
    py_rows.push(py_list_from_objects(py_row).obj())
  }
  let matrix_enum = sympy_call_must("sympy.Matrix", [
    PyObj(py_list_from_objects(py_rows).obj()),
  ])
  objenum_to_obj(matrix_enum)
}

///|
fn oracle_domainmatrix_from_ints(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> @py.PyObject raise {
  let row_count = rows.length()
  let col_count = if row_count == 0 { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != col_count {
      fail("domainmatrix-ragged")
    }
  }
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let convert = resolve_method_callable(domain_obj, "convert")
  let py_rows : Array[@py.PyObject] = Array::new()
  for row in rows {
    let py_row : Array[@py.PyObject] = Array::new()
    for v in row {
      py_row.push(objenum_to_obj(py_call_one(convert, py_int_obj(v))))
    }
    py_rows.push(py_list_from_objects(py_row).obj())
  }
  let data_obj = py_list_from_objects(py_rows).obj()
  let shape_obj = py_tuple_from_objects([
    py_int_obj(row_count),
    py_int_obj(col_count),
  ]).obj()
  let dm_enum = sympy_call_must("sympy.polys.matrices.DomainMatrix", [
    PyObj(data_obj),
    PyObj(shape_obj),
    PyObj(domain_obj),
  ])
  objenum_to_obj(dm_enum)
}

///|
fn oracle_sdm_from_ints(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> @py.PyObject raise {
  let row_count = rows.length()
  let col_count = if row_count == 0 { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != col_count {
      fail("sdm-ragged")
    }
  }
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let convert = resolve_method_callable(domain_obj, "convert")
  let py_rows : Array[@py.PyObject] = Array::new()
  for row in rows {
    let py_row : Array[@py.PyObject] = Array::new()
    for v in row {
      py_row.push(objenum_to_obj(py_call_one(convert, py_int_obj(v))))
    }
    py_rows.push(py_list_from_objects(py_row).obj())
  }
  let shape_obj = py_tuple_from_objects([
    py_int_obj(row_count),
    py_int_obj(col_count),
  ]).obj()
  let sdm = sympy_call_must("sympy.polys.matrices.sdm.SDM.from_list", [
    PyObj(py_list_from_objects(py_rows).obj()),
    PyObj(shape_obj),
    PyObj(domain_obj),
  ])
  objenum_to_obj(sdm)
}

///|
fn oracle_sdm_from_raw(
  raw : @py.PyObject,
  shape : (Int, Int),
  domain_obj : @py.PyObject,
) -> @py.PyObject raise {
  let shape_obj = py_tuple_from_objects([
    py_int_obj(shape.0),
    py_int_obj(shape.1),
  ]).obj()
  let sdm = sympy_call_must("sympy.polys.matrices.sdm.SDM", [
    PyObj(raw),
    PyObj(shape_obj),
    PyObj(domain_obj),
  ])
  objenum_to_obj(sdm)
}

///|
fn oracle_sdm_dense_summary(
  sdm_obj : @py.PyObject,
  domain_spec : String,
) -> String raise {
  let to_ddm = resolve_method_callable(sdm_obj, "to_ddm")
  let dense = py_str_enum(py_call_noargs(to_ddm))
  "\{dense}@\{domain_spec}|sparse"
}

///|
pub fn sdm_transpose_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let a = oracle_sdm_from_ints(rows, domain_spec)
  let raw = sympy_call_must("sympy.polys.matrices.sdm.sdm_transpose", [PyObj(a)])
  let row_count = rows.length()
  let col_count = if row_count == 0 { 0 } else { rows[0].length() }
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let sdm = oracle_sdm_from_raw(
    objenum_to_obj(raw),
    (col_count, row_count),
    domain_obj,
  )
  oracle_sdm_dense_summary(sdm, domain_spec)
}

///|
pub fn sdm_matmul_summary(
  a_rows : Array[Array[Int]],
  b_rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let a = oracle_sdm_from_ints(a_rows, domain_spec)
  let b = oracle_sdm_from_ints(b_rows, domain_spec)
  let m = a_rows.length()
  let o = if b_rows.length() == 0 { 0 } else { b_rows[0].length() }
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let raw = sympy_call_must("sympy.polys.matrices.sdm.sdm_matmul", [
    PyObj(a),
    PyObj(b),
    PyObj(domain_obj),
    Int(m),
    Int(o),
  ])
  let sdm = oracle_sdm_from_raw(objenum_to_obj(raw), (m, o), domain_obj)
  oracle_sdm_dense_summary(sdm, domain_spec)
}

///|
pub fn sdm_rref_den_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let a = oracle_sdm_from_ints(rows, domain_spec)
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let res = sympy_call_must("sympy.polys.matrices.sdm.sdm_rref_den", [
    PyObj(a),
    PyObj(domain_obj),
  ])
  remove_spaces(py_str_enum(res))
}

///|
pub fn sdm_berk_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let a = oracle_sdm_from_ints(rows, domain_spec)
  let domain_obj = oracle_domain_from_spec(domain_spec)
  let n = rows.length()
  let res = sympy_call_must("sympy.polys.matrices.sdm.sdm_berk", [
    PyObj(a),
    Int(n),
    PyObj(domain_obj),
  ])
  remove_spaces(py_str_enum(res))
}

///|
fn oracle_domain_from_spec(spec : String) -> @py.PyObject raise {
  let text = spec.trim().to_owned()
  if (
      text.has_prefix("GF(") ||
      text.has_prefix("FF(") ||
      text.has_prefix("FiniteField(")
    ) &&
    text.has_suffix(")") {
    let left = match find_char_oracle(text, '(') {
      Some(i) => i
      None => fail("domain-spec-gf:\{spec}")
    }
    let raw = text[left + 1:text.length() - 1].to_owned()
    let parsed = parse_gf_descriptor_oracle(raw, spec)
    let p = parsed.0
    let ext_opt = parsed.1
    let gf = match ext_opt {
      Some(k) => {
        let q = int_pow_oracle(p, k)
        sympy_call_must("sympy.polys.domains.GF", [Int(q)])
      }
      None => sympy_call_must("sympy.polys.domains.GF", [Int(p)])
    }
    return objenum_to_obj(gf)
  }
  if text.contains("<") && text.has_suffix(">") {
    let left = match find_matching_open_oracle(text, '<', '>') {
      Some(i) => i
      None => fail("domain-spec-alg")
    }
    let base = text[:left].to_owned()
    let gens = text[left + 1:text.length() - 1].to_owned()
    let base_obj = oracle_domain_from_spec(base)
    let ext_items = split_names(gens)
    let ext_objs : Array[@py.PyObject] = Array::new()
    for item in ext_items {
      ext_objs.push(sympy_sympify_str(item))
    }
    let alg_field = resolve_method_callable(base_obj, "algebraic_field")
    let ext_domain = py_call_with_args(alg_field, ext_objs, py_dict_new())
    return objenum_to_obj(ext_domain)
  }
  if text.contains(".old_poly_ring(") && text.has_suffix(")") {
    let left = match find_substring_oracle(text, ".old_poly_ring(") {
      Some(i) => i
      None => fail("domain-spec-old-poly")
    }
    let base = text[:left].to_owned()
    let gens = text[left + 15:text.length() - 1].to_owned()
    let base_obj = oracle_domain_from_spec(base)
    let symbols = sympy_exprs_from_texts(split_names(gens))
    let ring_method = resolve_method_callable(base_obj, "old_poly_ring")
    let ring = py_call_with_args(ring_method, symbols, py_dict_new())
    return objenum_to_obj(ring)
  }
  if text.contains(".old_frac_field(") && text.has_suffix(")") {
    let left = match find_substring_oracle(text, ".old_frac_field(") {
      Some(i) => i
      None => fail("domain-spec-old-frac")
    }
    let base = text[:left].to_owned()
    let gens = text[left + 16:text.length() - 1].to_owned()
    let base_obj = oracle_domain_from_spec(base)
    let symbols = sympy_exprs_from_texts(split_names(gens))
    let frac_method = resolve_method_callable(base_obj, "old_frac_field")
    let field = py_call_with_args(frac_method, symbols, py_dict_new())
    return objenum_to_obj(field)
  }
  if text.has_suffix("]") && !text.has_suffix("]]") {
    let left = match find_matching_open_oracle(text, '[', ']') {
      Some(i) => i
      None => fail("domain-spec-poly")
    }
    let base = text[:left].to_owned()
    let gens = text[left + 1:text.length() - 1].to_owned()
    let base_obj = oracle_domain_from_spec(base)
    let symbols = sympy_exprs_from_texts(split_names(gens))
    let ring_method = resolve_method_callable(base_obj, "poly_ring")
    let ring = py_call_with_args(ring_method, symbols, py_dict_new())
    return objenum_to_obj(ring)
  }
  if text.contains("(") && text.has_suffix(")") {
    let left = match find_matching_open_oracle(text, '(', ')') {
      Some(i) => i
      None => fail("domain-spec-frac")
    }
    let base = text[:left].to_owned()
    let gens = text[left + 1:text.length() - 1].to_owned()
    let base_obj = oracle_domain_from_spec(base)
    let symbols = sympy_exprs_from_texts(split_names(gens))
    let frac_method = resolve_method_callable(base_obj, "frac_field")
    let field = py_call_with_args(frac_method, symbols, py_dict_new())
    return objenum_to_obj(field)
  }
  let domains = ensure_domains_module_oracle()
  let state = py_gil_ensure()
  let attr = domains.get_attr(text, print_err=false)
  py_gil_release(state)
  match attr {
    Some(obj) => objenum_to_obj(obj)
    None => fail("domain-spec-unknown:\{text}")
  }
}

///|
fn find_char_oracle(text : String, needle : UInt16) -> Int? {
  for i in 0..<text.length() {
    if text[i] == needle {
      return Some(i)
    }
  }
  None
}

///|
fn find_substring_oracle(text : String, needle : String) -> Int? {
  let width = needle.length()
  if width == 0 || width > text.length() {
    return None
  }
  let mut i = 0
  while i + width <= text.length() {
    if text[i:i + width].to_owned() == needle {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn find_matching_open_oracle(
  text : String,
  open_char : UInt16,
  close_char : UInt16,
) -> Int? {
  if text.is_empty() || text[text.length() - 1] != close_char {
    return None
  }
  let mut depth = 0
  let mut i = text.length()
  while i > 0 {
    i -= 1
    let ch = text[i]
    if ch == close_char {
      depth += 1
    } else if ch == open_char {
      depth -= 1
      if depth == 0 {
        return Some(i)
      }
    }
  }
  None
}

///|
fn parse_gf_descriptor_oracle(raw : String, spec : String) -> (Int, Int?) raise {
  let body = raw.trim().to_owned()
  if body.contains("**") {
    let parts : Array[String] = Array::new()
    for p in body.split("**") {
      parts.push(p.trim().to_owned())
    }
    if parts.length() != 2 {
      fail("domain-spec-gf:\{spec}")
    }
    let p = @string.parse_int(parts[0]) catch {
      _ => fail("domain-spec-gf:\{spec}")
    }
    let k = @string.parse_int(parts[1]) catch {
      _ => fail("domain-spec-gf:\{spec}")
    }
    return (p, Some(k))
  }
  if body.contains(",") {
    let parts : Array[String] = Array::new()
    for p in body.split(",") {
      parts.push(p.trim().to_owned())
    }
    if parts.length() != 2 {
      fail("domain-spec-gf:\{spec}")
    }
    let p = @string.parse_int(parts[0]) catch {
      _ => fail("domain-spec-gf:\{spec}")
    }
    let k = @string.parse_int(parts[1]) catch {
      _ => fail("domain-spec-gf:\{spec}")
    }
    return (p, Some(k))
  }
  let p = @string.parse_int(body) catch { _ => fail("domain-spec-gf:\{spec}") }
  (p, None)
}

///|
fn sympy_exprs_from_texts(items : Array[String]) -> Array[@py.PyObject] raise {
  let exprs : Array[@py.PyObject] = Array::new()
  for item in items {
    exprs.push(sympy_sympify_str(item))
  }
  exprs
}

///|
fn int_pow_oracle(base : Int, exp : Int) -> Int {
  let mut result = 1
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result * b
    }
    e = e / 2
    if e > 0 {
      b = b * b
    }
  }
  result
}

///|
fn split_names(text : String) -> Array[String] {
  let raw = text.trim().to_owned()
  if raw == "" {
    return []
  }
  let out : Array[String] = Array::new()
  for name in raw.split(",") {
    out.push(name.trim().to_owned())
  }
  out
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
  let args : Array[LegacyArg] = [PyObj(py_list_from_objects(items).obj())]
  let kwargs : Map[String, LegacyArg] = { "multiple": Bool(false) }
  let res = sympy_call_must(
    "sympy.polys.polyutils._sort_factors",
    args,
    kwargs~,
  )
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
  let args : Array[LegacyArg] = [PyObj(py_list_from_objects(items).obj())]
  let kwargs : Map[String, LegacyArg] = { "multiple": Bool(true) }
  let res = sympy_call_must(
    "sympy.polys.polyutils._sort_factors",
    args,
    kwargs~,
  )
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
let builtins_cache : Ref[@py.PyModule?] = { val: None }

///|
let sympy_cache : Ref[@py.PyModule?] = { val: None }

///|
let operator_cache : Ref[@py.PyModule?] = { val: None }

///|
let domains_cache : Ref[@py.PyModule?] = { val: None }

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
fn ensure_domains_module_oracle() -> @py.PyModule raise {
  ensure_python()
  match domains_cache.val {
    Some(mod) => mod
    None => {
      let state = py_gil_ensure()
      let mod = match @py.pyimport("sympy.polys.domains") {
        Some(m) => m
        None => {
          py_gil_release(state)
          fail("sympy-polys-domains-missing")
        }
      }
      py_gil_release(state)
      domains_cache.val = Some(mod)
      mod
    }
  }
}

///|
fn ensure_distributedmodules_module_oracle() -> @py.PyModule raise {
  ensure_python()
  let state = py_gil_ensure()
  let mod = match @py.pyimport("sympy.polys.distributedmodules") {
    Some(m) => m
    None => {
      py_gil_release(state)
      fail("sympy-polys-distributedmodules-missing")
    }
  }
  py_gil_release(state)
  mod
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
fn py_list_from_ints(values : Array[Int]) -> @py.PyObject {
  let items : Array[@py.PyObject] = []
  for value in values {
    items.push(py_int_obj(value))
  }
  py_list_from_objects(items).obj()
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
fn py_bool_obj(value : Bool) -> @py.PyObject {
  let state = py_gil_ensure()
  let obj = @py.PyBool::from(value).obj()
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
  args : Array[LegacyArg],
  kwargs? : Map[String, LegacyArg] = {},
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
fn sorted_py_iter_str(obj : @py.PyObjectEnum) -> String raise {
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let list_enum = py_call_one(list_ctor, objenum_to_obj(obj))
  let items = py_list_to_pyobjects(list_enum)
  let parts : Array[String] = []
  for item in items {
    parts.push(py_str_obj(item))
  }
  parts.sort()
  parts.join(" | ")
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
    _ => @string.parse_int(py_str_obj(obj))
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
  let res = sympy_call_must("sympy.sympify", [Str(expr_str)])
  objenum_to_obj(res)
}

///|
fn sympy_symbol_obj(name : String) -> @py.PyObject raise {
  let res = sympy_call_must("sympy.symbols", [Str(name)])
  objenum_to_obj(res)
}

///|
fn sympy_poly_from_expr(
  expr : String,
  gens : Array[String],
) -> @py.PyObject raise {
  let expr_obj = sympy_sympify_str(expr)
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_obj))
  for g in gens {
    args.push(PyObj(sympy_symbol_obj(g)))
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
  let res = sympy_call_must("sympy.expand", [PyObj(acc)])
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
  extension? : Array[String] = [],
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let modulus_opt = if modulus == 0 { None } else { Some(modulus) }
  let expr_obj = expr_to_sympy(expr)
  let sympy = ensure_sympy_module_oracle()
  let use_gfext = !gfext_modulus.is_empty()
  let kwargs_map : Map[String, LegacyArg] = Map([])
  if use_gfext {
    match modulus_opt {
      Some(m) =>
        kwargs_map["domain"] = PyObj(
          sympy_domain_gfext(m, gfext_modulus, gfext_gen),
        )
      None => fail("gfext-modulus-missing")
    }
  } else {
    match modulus_opt {
      Some(m) => kwargs_map["modulus"] = Int(m)
      None => ()
    }
  }
  if !extension.is_empty() {
    let ext_objs : Array[@py.PyObject] = Array::new()
    for item in extension {
      ext_objs.push(sympy_sympify_str(item))
    }
    kwargs_map["extension"] = PyObj(py_list_from_objects(ext_objs).obj())
  }
  let res = sympy_call_must(
    "sympy.factor_list",
    [PyObj(expr_obj)],
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
fn nf_anp_oracle_coeffs_obj(
  coeffs : Array[Int],
  domain : String,
) -> @py.PyObject raise {
  let items : Array[@py.PyObject] = []
  for coeff in coeffs {
    items.push(sympy_domain_elem(@symnum.BigRational::from_int(coeff), domain))
  }
  py_list_from_objects(items).obj()
}

///|
fn nf_anp_oracle_coeffs_text(value : @py.PyObjectEnum) -> String raise {
  let items = py_list_to_pyobjects(value)
  "[" + items.map(item => py_str_obj(item)).join(", ") + "]"
}

///|
pub fn init_normal_ANP(
  rep : Array[Int],
  mod : Array[Int],
  domain? : String = "QQ",
) -> String raise {
  let res = sympy_call_must("sympy.polys.polyclasses.init_normal_ANP", [
    PyObj(nf_anp_oracle_coeffs_obj(rep, domain)),
    PyObj(nf_anp_oracle_coeffs_obj(mod, domain)),
    PyObj(sympy_domain_obj(domain)),
  ])
  let res_obj = objenum_to_obj(res)
  let rep_attr = match py_get_attr(res_obj, "rep") {
    Some(v) => v
    None => fail("init_normal_ANP-rep")
  }
  let mod_attr = match py_get_attr(res_obj, "mod") {
    Some(v) => v
    None => fail("init_normal_ANP-mod")
  }
  let dom_attr = match py_get_attr(res_obj, "dom") {
    Some(v) => v
    None => fail("init_normal_ANP-dom")
  }
  "ANP(\{nf_anp_oracle_coeffs_text(rep_attr)}, \{nf_anp_oracle_coeffs_text(mod_attr)}, \{py_str_enum(dom_attr)})"
}

///|
pub fn tschirnhausen_transformation(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  max_tries? : Int = 30,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let kwargs : Map[String, LegacyArg] = { "max_tries": Int(max_tries) }
  let res = sympy_call_must(
    "sympy.polys.numberfields.galoisgroups.tschirnhausen_transformation",
    [PyObj(poly)],
    kwargs~,
  )
  let items = py_list_to_pyobjects(res)
  guard items.length() >= 2 else { fail("tschirnhausen tuple") }
  "(\{oracle_poly_element_as_expr(items[0])}, \{oracle_poly_element_as_expr(items[1])})"
}

///|
pub fn get_resolvent_by_lookup(
  expr : @symcore.Expr,
  number : Int,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let res = sympy_call_must(
    "sympy.polys.numberfields.galois_resolvents.get_resolvent_by_lookup",
    [PyObj(poly), Int(number)],
  )
  py_sympy_enum_str(res)
}

///|
pub fn define_resolvents() -> String raise {
  let res = sympy_call_must(
    "sympy.polys.numberfields.galois_resolvents.define_resolvents",
    [],
  )
  let dict_obj = objenum_to_obj(res)
  let items_call = resolve_method_callable(dict_obj, "items")
  let items_enum = py_call_noargs(items_call)
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let items_list_enum = py_call_one(list_ctor, objenum_to_obj(items_enum))
  let kvs = py_list_to_pyobjects(items_list_enum)
  let parts : Array[String] = []
  for pair in kvs {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 {
      let key = remove_spaces(py_str_obj(pair_items[0]))
      let value_items = py_list_to_pyobjects(
        @py.PyObjectEnum::create(pair_items[1]),
      )
      if value_items.length() >= 3 {
        let vars = py_list_to_pyobjects(
          @py.PyObjectEnum::create(value_items[1]),
        )
        let perms = py_list_to_pyobjects(
          @py.PyObjectEnum::create(value_items[2]),
        )
        parts.push("\{key}:\{vars.length()}:\{perms.length()}")
      }
    }
  }
  parts.sort()
  parts.join("|")
}

///|
pub fn sparse_symmetrize_resolvent_coeffs(
  degree : Int,
  number : Int,
) -> String raise {
  let res = sympy_call_must(
    "sympy.polys.numberfields.galois_resolvents.define_resolvents",
    [],
  )
  let dict_obj = objenum_to_obj(res)
  let items_call = resolve_method_callable(dict_obj, "items")
  let items_enum = py_call_noargs(items_call)
  let builtins = ensure_builtins_module()
  let list_ctor = resolve_callable(builtins, "list")
  let items_list_enum = py_call_one(list_ctor, objenum_to_obj(items_enum))
  let kvs = py_list_to_pyobjects(items_list_enum)
  let target = "(\{degree},\{number})"
  for pair in kvs {
    let pair_items = py_list_to_pyobjects(@py.PyObjectEnum::create(pair))
    if pair_items.length() >= 2 &&
      remove_spaces(py_str_obj(pair_items[0])) == target {
      let value_items = py_list_to_pyobjects(
        @py.PyObjectEnum::create(pair_items[1]),
      )
      guard value_items.length() >= 3 else { fail("resolvent spec tuple") }
      let symm = sympy_call_must(
        "sympy.polys.numberfields.galois_resolvents.sparse_symmetrize_resolvent_coeffs",
        [PyObj(value_items[0]), PyObj(value_items[1]), PyObj(value_items[2])],
      )
      let symm_items = py_list_to_pyobjects(symm)
      guard symm_items.length() >= 1 else { fail("resolvent symmetrize tuple") }
      let coeff_objs = py_list_to_pyobjects(
        @py.PyObjectEnum::create(symm_items[0]),
      )
      let coeffs : Array[String] = []
      for coeff in coeff_objs {
        coeffs.push(py_str_obj(coeff))
      }
      return coeffs.join("|")
    }
  }
  fail("resolvent key not found")
}

///|
pub fn generate_lambda_lookup(
  verbose? : Bool = false,
  trial_run? : Bool = false,
) -> String raise {
  let kwargs : Map[String, LegacyArg] = {
    "verbose": Bool(verbose),
    "trial_run": Bool(trial_run),
  }
  let res = sympy_call_must(
    "sympy.polys.numberfields.galois_resolvents.generate_lambda_lookup",
    [],
    kwargs~,
  )
  py_str_enum(res)
}

///|
pub fn has_square_disc(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> Bool raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let poly = call_sympy_poly(expr_obj, gens_list, "", None)
  let res = sympy_call_must(
    "sympy.polys.numberfields.galoisgroups.has_square_disc",
    [PyObj(poly)],
  )
  py_str_enum(res) == "True"
}

///|
pub fn isolate(expr : @symcore.Expr, eps? : String = "") -> String raise {
  let args : Array[LegacyArg] = [PyObj(expr_to_sympy(expr))]
  if eps != "" {
    args.push(PyObj(sympy_sympify_str(eps)))
  }
  let res = sympy_call_must("sympy.polys.numberfields.utilities.isolate", args)
  py_sympy_enum_str(res)
}

///|
pub fn round_two(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let gen_objs = sympy_symbols_from_names(gens)
  let poly = call_sympy_poly(expr_to_sympy(expr), gen_objs, "", None)
  let res = sympy_call_must("sympy.polys.numberfields.basis.round_two", [
    PyObj(poly),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn prime_decomp(
  p : Int,
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let gen_objs = sympy_symbols_from_names(gens)
  let poly = call_sympy_poly(expr_to_sympy(expr), gen_objs, "", None)
  let res = sympy_call_must("sympy.polys.numberfields.primes.prime_decomp", [
    Int(p),
    PyObj(poly),
  ])
  py_sympy_enum_str(res)
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
    let poly = call_sympy_poly(
      expr_obj,
      [],
      "",
      None,
      domain_obj=Some(domain_obj),
    )
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
        let res = sympy_call_must("sympy.sqf_list", [PyObj(expr_obj)])
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
  let args0 : Array[LegacyArg] = Array::new()
  let py_polys = py_list_from_objects(expr_objs)
  args0.push(PyObj(py_polys.obj()))
  for g in gens {
    args0.push(PyObj(g))
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if order != "" {
    kwargs["order"] = Str(order)
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
fn groebner_ring_polys(
  exprs : Array[@symcore.Expr],
  gens : Array[String],
  order : String,
) -> (@py.PyObject, Array[@py.PyObject]) raise {
  let kwargs : Map[String, LegacyArg] = Map([])
  if order != "" {
    kwargs["order"] = Str(order)
  }
  let ring_res = sympy_call_must(
    "sympy.polys.rings.ring",
    [Str(gens.join(",")), PyObj(sympy_domain_obj("QQ"))],
    kwargs~,
  )
  let items = py_list_to_pyobjects(ring_res)
  guard items.length() >= 1 else { fail("groebner-ring-result") }
  let ring = items[0]
  let from_expr = resolve_method_callable(ring, "from_expr")
  let polys : Array[@py.PyObject] = []
  for expr in exprs {
    let poly = py_call_one(from_expr, expr_to_sympy(expr))
    polys.push(objenum_to_obj(poly))
  }
  (ring, polys)
}

///|
fn groebner_ring_list_string(value : @py.PyObjectEnum) -> String raise {
  let items = py_list_to_pyobjects(value)
  let parts : Array[String] = []
  for item in items {
    parts.push(py_str_obj(item))
  }
  parts.sort()
  parts.join(" | ")
}

///|
pub fn matrix_fglm(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  source_order? : String = "grlex",
  target_order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys(exprs, gens, source_order)
  let source = sympy_call_must("sympy.polys.groebnertools.groebner", [
    PyObj(py_list_from_objects(polys).obj()),
    PyObj(ring),
  ])
  let target_order_obj = groebner_order_obj(gens, target_order)
  let res = sympy_call_must("sympy.polys.fglmtools.matrix_fglm", [
    PyObj(objenum_to_obj(source)),
    PyObj(ring),
    PyObj(target_order_obj),
  ])
  groebner_ring_list_string(res)
}

///|
fn py_bool_text(value : @py.PyObjectEnum) -> String {
  if py_str_enum(value) == "True" {
    "true"
  } else {
    "false"
  }
}

///|
pub fn groebnertools_spoly(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys([f, g], gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.spoly", [
    PyObj(polys[0]),
    PyObj(polys[1]),
    PyObj(ring),
  ])
  py_str_enum(res)
}

///|
pub fn groebnertools_gcd(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = ["x"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([f, g], gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.groebner_gcd", [
    PyObj(polys[0]),
    PyObj(polys[1]),
  ])
  py_str_enum(res)
}

///|
pub fn groebnertools_lcm(
  f : @symcore.Expr,
  g : @symcore.Expr,
  gens? : Array[String] = ["x"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([f, g], gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.groebner_lcm", [
    PyObj(polys[0]),
    PyObj(polys[1]),
  ])
  py_str_enum(res)
}

///|
fn groebner_monomial_obj(monomial : Array[Int]) -> @py.PyObject {
  let items : Array[@py.PyObject] = []
  for exp in monomial {
    items.push(py_int_obj(exp))
  }
  py_tuple_from_objects(items).obj()
}

///|
fn groebner_signature_obj(monomial : Array[Int], index : Int) -> @py.PyObject {
  py_tuple_from_objects([groebner_monomial_obj(monomial), py_int_obj(index)]).obj()
}

///|
fn groebner_order_obj(
  gens : Array[String],
  order : String,
) -> @py.PyObject raise {
  let (ring, _) = groebner_ring_polys([], gens, order)
  match py_get_attr(ring, "order") {
    Some(value) => objenum_to_obj(value)
    None => fail("groebner-ring-order-missing")
  }
}

///|
fn groebner_lbp_obj(
  signature : @py.PyObject,
  polynomial : @py.PyObject,
  number : Int,
) -> @py.PyObject {
  py_tuple_from_objects([signature, polynomial, py_int_obj(number)]).obj()
}

///|
fn groebner_lbp_result_string(value : @py.PyObjectEnum) -> String raise {
  let items = py_list_to_pyobjects(value)
  guard items.length() == 3 else { fail("groebner-lbp-result") }
  "\{py_str_obj(items[0])}|\{py_str_obj(items[1])}|\{py_str_obj(items[2])}"
}

///|
fn groebner_term_obj(monomial : Array[Int], coeff : Int) -> @py.PyObject raise {
  py_tuple_from_objects([
    groebner_monomial_obj(monomial),
    sympy_domain_elem(@symnum.BigRational::from_int(coeff), "QQ"),
  ]).obj()
}

///|
pub fn groebnertools_sig_cmp(
  a_monomial : Array[Int],
  a_index : Int,
  b_monomial : Array[Int],
  b_index : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let res = sympy_call_must("sympy.polys.groebnertools.sig_cmp", [
    PyObj(groebner_signature_obj(a_monomial, a_index)),
    PyObj(groebner_signature_obj(b_monomial, b_index)),
    PyObj(groebner_order_obj(gens, order)),
  ])
  py_str_enum(res)
}

///|
pub fn groebnertools_sig_mult(
  monomial : Array[Int],
  index : Int,
  multiplier : Array[Int],
) -> String raise {
  let res = sympy_call_must("sympy.polys.groebnertools.sig_mult", [
    PyObj(groebner_signature_obj(monomial, index)),
    PyObj(groebner_monomial_obj(multiplier)),
  ])
  py_str_enum(res)
}

///|
pub fn groebnertools_lbp_cmp(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([f_expr, g_expr], gens, order)
  let f = groebner_lbp_obj(
    groebner_signature_obj(f_monomial, f_index),
    polys[0],
    f_number,
  )
  let g = groebner_lbp_obj(
    groebner_signature_obj(g_monomial, g_index),
    polys[1],
    g_number,
  )
  let res = sympy_call_must("sympy.polys.groebnertools.lbp_cmp", [
    PyObj(f),
    PyObj(g),
  ])
  py_str_enum(res)
}

///|
pub fn groebnertools_lbp_sub(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([f_expr, g_expr], gens, order)
  let f = groebner_lbp_obj(
    groebner_signature_obj(f_monomial, f_index),
    polys[0],
    f_number,
  )
  let g = groebner_lbp_obj(
    groebner_signature_obj(g_monomial, g_index),
    polys[1],
    g_number,
  )
  let res = sympy_call_must("sympy.polys.groebnertools.lbp_sub", [
    PyObj(f),
    PyObj(g),
  ])
  groebner_lbp_result_string(res)
}

///|
pub fn groebnertools_lbp_mul_term(
  monomial : Array[Int],
  index : Int,
  expr : @symcore.Expr,
  number : Int,
  term_monomial : Array[Int],
  term_coeff : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([expr], gens, order)
  let f = groebner_lbp_obj(
    groebner_signature_obj(monomial, index),
    polys[0],
    number,
  )
  let res = sympy_call_must("sympy.polys.groebnertools.lbp_mul_term", [
    PyObj(f),
    PyObj(groebner_term_obj(term_monomial, term_coeff)),
  ])
  groebner_lbp_result_string(res)
}

///|
pub fn groebnertools_critical_s_poly(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys([f_expr, g_expr], gens, order)
  let f = groebner_lbp_obj(
    groebner_signature_obj(f_monomial, f_index),
    polys[0],
    f_number,
  )
  let g = groebner_lbp_obj(
    groebner_signature_obj(g_monomial, g_index),
    polys[1],
    g_number,
  )
  let cp = sympy_call_must("sympy.polys.groebnertools.critical_pair", [
    PyObj(f),
    PyObj(g),
    PyObj(ring),
  ])
  let res = sympy_call_must("sympy.polys.groebnertools.s_poly", [
    PyObj(objenum_to_obj(cp)),
  ])
  groebner_lbp_result_string(res)
}

///|
pub fn groebnertools_is_rewritable_or_comparable_one(
  sign_monomial : Array[Int],
  sign_index : Int,
  number : Int,
  h_monomial : Array[Int],
  h_index : Int,
  h_expr : @symcore.Expr,
  h_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([h_expr], gens, order)
  let h = groebner_lbp_obj(
    groebner_signature_obj(h_monomial, h_index),
    polys[0],
    h_number,
  )
  let basis = py_list_from_objects([h]).obj()
  let res = sympy_call_must(
    "sympy.polys.groebnertools.is_rewritable_or_comparable",
    [
      PyObj(groebner_signature_obj(sign_monomial, sign_index)),
      Int(number),
      PyObj(basis),
    ],
  )
  py_bool_text(res)
}

///|
pub fn groebnertools_f5_reduce_one(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  h_monomial : Array[Int],
  h_index : Int,
  h_expr : @symcore.Expr,
  h_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (_, polys) = groebner_ring_polys([f_expr, h_expr], gens, order)
  let f = groebner_lbp_obj(
    groebner_signature_obj(f_monomial, f_index),
    polys[0],
    f_number,
  )
  let h = groebner_lbp_obj(
    groebner_signature_obj(h_monomial, h_index),
    polys[1],
    h_number,
  )
  let res = sympy_call_must("sympy.polys.groebnertools.f5_reduce", [
    PyObj(f),
    PyObj(py_list_from_objects([h]).obj()),
  ])
  groebner_lbp_result_string(res)
}

///|
pub fn red_groebner(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys(exprs, gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.red_groebner", [
    PyObj(py_list_from_objects(polys).obj()),
    PyObj(ring),
  ])
  groebner_ring_list_string(res)
}

///|
pub fn is_groebner(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys(exprs, gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.is_groebner", [
    PyObj(py_list_from_objects(polys).obj()),
    PyObj(ring),
  ])
  py_bool_text(res)
}

///|
pub fn is_minimal(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys(exprs, gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.is_minimal", [
    PyObj(py_list_from_objects(polys).obj()),
    PyObj(ring),
  ])
  py_bool_text(res)
}

///|
pub fn is_reduced(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let (ring, polys) = groebner_ring_polys(exprs, gens, order)
  let res = sympy_call_must("sympy.polys.groebnertools.is_reduced", [
    PyObj(py_list_from_objects(polys).obj()),
    PyObj(ring),
  ])
  py_bool_text(res)
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
        _ => @string.parse_int(py_str_obj(exp_obj))
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
fn call_sympy_poly(
  expr : @py.PyObject,
  gens : Array[@py.PyObject],
  domain : String,
  modulus : Int?,
  domain_obj? : @py.PyObject? = None,
) -> @py.PyObject raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr))
  for g in gens {
    args.push(PyObj(g))
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  match domain_obj {
    Some(obj) => kwargs["domain"] = PyObj(obj)
    None => if domain != "" { kwargs["domain"] = Str(domain) }
  }
  if domain_obj is None {
    match modulus {
      Some(m) => kwargs["modulus"] = Int(m)
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
  let use_poly = gens0 is Some(_) ||
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
    let res = sympy_call_must("sympy.gcd", [PyObj(a), PyObj(b)])
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
  let mut gens_list = match gens0 {
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
  if var_obj is Some(var_sym) && gens_list.length() > 0 {
    let var_name = py_str_obj(var_sym)
    let mut idx_opt : Int? = None
    for i in 0..<gens_list.length() {
      if py_str_obj(gens_list[i]) == var_name {
        idx_opt = Some(i)
        break
      }
    }
    match idx_opt {
      Some(i) =>
        if i != 0 {
          let reordered : Array[@py.PyObject] = Array::new()
          reordered.push(gens_list[i])
          for j in 0..<gens_list.length() {
            if j != i {
              reordered.push(gens_list[j])
            }
          }
          gens_list = reordered
        }
      None => ()
    }
  }
  if gens_list.length() > 0 &&
    (domain != "" || modulus_opt is Some(_) || use_gfext) {
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
    let args0 : Array[LegacyArg] = Array::new()
    args0.push(PyObj(p_obj))
    args0.push(PyObj(q_obj))
    match var_obj {
      Some(v) => args0.push(PyObj(v))
      None => ()
    }
    let kwargs_map : Map[String, LegacyArg] = Map([])
    match modulus_opt {
      Some(m) => kwargs_map["modulus"] = Int(m)
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
  let use_poly = gens0 is Some(_) ||
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
    sympy_call_must("sympy.div", [PyObj(p_obj), PyObj(q_obj)])
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
  let args : Array[LegacyArg] = Array::new()
  let list_items : Array[LegacyArg] = Array::new()
  for p in polys {
    list_items.push(PyObj(expr_to_sympy(p)))
  }
  args.push(List(list_items))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for g in gens_list {
      args.push(PyObj(g))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
  let args : Array[LegacyArg] = Array::new()
  let list_items : Array[LegacyArg] = Array::new()
  for p in polys {
    list_items.push(PyObj(expr_to_sympy(p)))
  }
  args.push(List(list_items))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for g in gens_list {
      args.push(PyObj(g))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
    let pow = sympy_call_must("sympy.Pow", [PyObj(gens_list[i]), Int(exp)])
    let mul = resolve_method_callable(acc, "__mul__")
    let acc_enum = py_call_one(mul, objenum_to_obj(pow))
    acc = objenum_to_obj(acc_enum)
  }
  py_sympy_expr_str(acc)
}

///|
pub fn reduced(
  f : @symcore.Expr,
  divisors : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(f)))
  let list_items : Array[LegacyArg] = Array::new()
  for g in divisors {
    list_items.push(PyObj(expr_to_sympy(g)))
  }
  args.push(List(list_items))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for g in gens_list {
      args.push(PyObj(g))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(f)))
  args.push(PyObj(expr_to_sympy(g)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(f)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(f)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(f)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
  }
  let res = sympy_call_must("sympy.polys.polytools.discriminant", args, kwargs~)
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = Int(modulus)
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
  let res = sympy_call_must("sympy.interpolate", [PyObj(data_obj), PyObj(sym)])
  py_sympy_enum_str(res)
}

///|
pub fn interpolate_values(
  values : Array[@symnum.BigRational],
  x? : String = "x",
) -> String raise {
  let data_obj = py_list_from_rationals(values)
  let sym = sympy_symbol_obj(x)
  let res = sympy_call_must("sympy.interpolate", [PyObj(data_obj), PyObj(sym)])
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
  let res = sympy_call_must("sympy.interpolate", [PyObj(dict_obj), PyObj(sym)])
  py_sympy_enum_str(res)
}

///|
pub fn rational_interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  x? : String = "x",
) -> String raise {
  let data_obj = sympy_points_obj(points)
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(data_obj))
  args.push(Int(deg_num))
  let kwargs : Map[String, LegacyArg] = Map([])
  if x != "" {
    kwargs["X"] = PyObj(sympy_symbol_obj(x))
  }
  let res = sympy_call_must("sympy.rational_interpolate", args, kwargs~)
  let res_obj = objenum_to_obj(res)
  let frac = sympy_call_must("sympy.fraction", [PyObj(res_obj)])
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
      if c == 1 {
        gen
      } else {
        "\{c}*\{gen}"
      }
    } else {
      let base = "\{gen}**\{i}"
      if c == 1 {
        base
      } else {
        "\{c}*\{base}"
      }
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
  let poly_args : Array[LegacyArg] = [PyObj(expr_obj), PyObj(gen_obj)]
  let poly_kwargs : Map[String, LegacyArg] = { "modulus": Int(modulus) }
  let poly_enum = sympy_call_must("sympy.Poly", poly_args, kwargs=poly_kwargs)
  let poly_obj = objenum_to_obj(poly_enum)
  let ext_enum = sympy_call_must(
    "sympy.polys.agca.extensions.FiniteExtension",
    [PyObj(poly_obj)],
  )
  objenum_to_obj(ext_enum)
}

///|
fn sympy_number_obj_oracle(n : @symnum.BigRational) -> @py.PyObject raise {
  if n.is_integral() {
    let num_str = n.numerator().to_string()
    objenum_to_obj(sympy_call_must("sympy.Integer", [Str(num_str)]))
  } else {
    let num_str = n.numerator().to_string()
    let den_str = n.denominator().to_string()
    objenum_to_obj(
      sympy_call_must("sympy.Rational", [Str(num_str), Str(den_str)]),
    )
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
fn sdm_oracle_tuple_obj(values : Array[Int]) -> @py.PyObject {
  let items : Array[@py.PyObject] = []
  for value in values {
    items.push(py_int_obj(value))
  }
  py_tuple_from_objects(items).obj()
}

///|
fn sdm_oracle_coeff_obj(value : Int, domain : String) -> @py.PyObject raise {
  sympy_domain_elem(@symnum.BigRational::from_int(value), domain)
}

///|
fn sdm_oracle_term_obj(
  term : (Array[Int], Int),
  domain : String,
) -> @py.PyObject raise {
  py_tuple_from_objects([
    sdm_oracle_tuple_obj(term.0),
    sdm_oracle_coeff_obj(term.1, domain),
  ]).obj()
}

///|
fn sdm_oracle_terms_obj(
  terms : Array[(Array[Int], Int)],
  domain : String,
) -> @py.PyObject raise {
  let items : Array[@py.PyObject] = []
  for term in terms {
    items.push(sdm_oracle_term_obj(term, domain))
  }
  py_list_from_objects(items).obj()
}

///|
fn sdm_oracle_basis_obj(
  basis : Array[Array[(Array[Int], Int)]],
  domain : String,
) -> @py.PyObject raise {
  let items : Array[@py.PyObject] = []
  for term_list in basis {
    items.push(sdm_oracle_terms_obj(term_list, domain))
  }
  py_list_from_objects(items).obj()
}

///|
fn sdm_oracle_dict_obj(
  terms : Array[(Array[Int], Int)],
  domain : String,
) -> @py.PyObject raise {
  let dict = py_dict_new()
  let setitem = resolve_method_callable(dict.obj(), "__setitem__")
  for term in terms {
    let key = sdm_oracle_tuple_obj(term.0)
    let value = sdm_oracle_coeff_obj(term.1, domain)
    let pair = py_tuple_from_objects([key, value])
    let _ = py_call_object_allow_none(setitem, pair, print_err=true)
  }
  dict.obj()
}

///|
fn sdm_oracle_order_obj(name : String) -> @py.PyObject raise {
  let sympy = ensure_sympy_module_oracle()
  match sympy.get_attr(name, print_err=false) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-order-missing:\{name}")
  }
}

///|
fn sdm_oracle_nf_obj(name : String) -> @py.PyObject raise {
  let dm_mod = ensure_distributedmodules_module_oracle()
  let function_name = match name {
    "buchberger" => "sdm_nf_buchberger"
    "reduced" | "buchberger_reduced" => "sdm_nf_buchberger_reduced"
    _ => "sdm_nf_mora"
  }
  resolve_callable(dm_mod, function_name).obj()
}

///|
fn sdm_oracle_call(
  name : String,
  args : Array[LegacyArg],
) -> @py.PyObjectEnum raise {
  sympy_call_must("sympy.polys.distributedmodules.\{name}", args)
}

///|
fn sdm_oracle_compact(name : String, args : Array[LegacyArg]) -> String raise {
  remove_spaces(py_dense_str(sdm_oracle_call(name, args)))
}

///|
pub fn sdm_monomial_mul(m : Array[Int], x : Array[Int]) -> String raise {
  sdm_oracle_compact("sdm_monomial_mul", [
    PyObj(sdm_oracle_tuple_obj(m)),
    PyObj(sdm_oracle_tuple_obj(x)),
  ])
}

///|
pub fn sdm_monomial_deg(m : Array[Int]) -> Int raise {
  let res = sdm_oracle_call("sdm_monomial_deg", [PyObj(sdm_oracle_tuple_obj(m))])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn sdm_monomial_lcm(a : Array[Int], b : Array[Int]) -> String raise {
  sdm_oracle_compact("sdm_monomial_lcm", [
    PyObj(sdm_oracle_tuple_obj(a)),
    PyObj(sdm_oracle_tuple_obj(b)),
  ])
}

///|
pub fn sdm_monomial_divides(a : Array[Int], b : Array[Int]) -> Bool raise {
  let res = sdm_oracle_call("sdm_monomial_divides", [
    PyObj(sdm_oracle_tuple_obj(a)),
    PyObj(sdm_oracle_tuple_obj(b)),
  ])
  py_str_enum(res) == "True"
}

///|
pub fn sdm_LC(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_LC", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_LM(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_LM", [PyObj(sdm_oracle_terms_obj(f, domain))])
}

///|
pub fn sdm_LT(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_LT", [PyObj(sdm_oracle_terms_obj(f, domain))])
}

///|
pub fn sdm_to_dict(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_to_dict", [PyObj(sdm_oracle_terms_obj(f, domain))])
}

///|
pub fn sdm_strip(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_strip", [PyObj(sdm_oracle_terms_obj(f, domain))])
}

///|
pub fn sdm_sort(
  f : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_sort", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sdm_oracle_order_obj(order)),
  ])
}

///|
pub fn sdm_from_dict(
  f : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_from_dict", [
    PyObj(sdm_oracle_dict_obj(f, domain)),
    PyObj(sdm_oracle_order_obj(order)),
  ])
}

///|
pub fn sdm_from_vector(
  exprs : Array[String],
  gens : Array[String],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let kwargs : Map[String, LegacyArg] = Map([])
  kwargs["gens"] = PyObj(
    py_list_from_objects(sympy_symbols_from_names(gens)).obj(),
  )
  let res = sympy_call_must(
    "sympy.polys.distributedmodules.sdm_from_vector",
    [
      PyObj(py_list_from_objects(sympy_exprs_from_texts(exprs)).obj()),
      PyObj(sdm_oracle_order_obj(order)),
      PyObj(sympy_domain_obj(domain)),
    ],
    kwargs~,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn sdm_to_vector(
  f : Array[(Array[Int], Int)],
  gens : Array[String],
  n? : Int = 0,
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(py_list_from_objects(sympy_symbols_from_names(gens)).obj()),
    PyObj(sympy_domain_obj(domain)),
  ]
  if n != 0 {
    args.push(Int(n))
  }
  let res = sympy_call_must(
    "sympy.polys.distributedmodules.sdm_to_vector", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn sdm_add(
  f : Array[(Array[Int], Int)],
  g : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_add", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sdm_oracle_terms_obj(g, domain)),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_zero() -> String raise {
  sdm_oracle_compact("sdm_zero", [])
}

///|
pub fn sdm_mul_term(
  f : Array[(Array[Int], Int)],
  monom : Array[Int],
  coeff : Int,
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let term = py_tuple_from_objects([
    sdm_oracle_tuple_obj(monom),
    sdm_oracle_coeff_obj(coeff, domain),
  ])
  sdm_oracle_compact("sdm_mul_term", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(term.obj()),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_spoly(
  f : Array[(Array[Int], Int)],
  g : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_spoly", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sdm_oracle_terms_obj(g, domain)),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_nf_mora(
  f : Array[(Array[Int], Int)],
  basis : Array[Array[(Array[Int], Int)]],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_nf_mora", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sdm_oracle_basis_obj(basis, domain)),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_nf_buchberger(
  f : Array[(Array[Int], Int)],
  basis : Array[Array[(Array[Int], Int)]],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_nf_buchberger", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sdm_oracle_basis_obj(basis, domain)),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_nf_buchberger_reduced(
  f : Array[(Array[Int], Int)],
  basis : Array[Array[(Array[Int], Int)]],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_nf_buchberger_reduced", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
    PyObj(sdm_oracle_basis_obj(basis, domain)),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_groebner(
  generators : Array[Array[(Array[Int], Int)]],
  normal_form? : String = "mora",
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  sdm_oracle_compact("sdm_groebner", [
    PyObj(sdm_oracle_basis_obj(generators, domain)),
    PyObj(sdm_oracle_nf_obj(normal_form)),
    PyObj(sdm_oracle_order_obj(order)),
    PyObj(sympy_domain_obj(domain)),
  ])
}

///|
pub fn sdm_deg(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> Int raise {
  let res = sdm_oracle_call("sdm_deg", [PyObj(sdm_oracle_terms_obj(f, domain))])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn sdm_ecart(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> Int raise {
  let res = sdm_oracle_call("sdm_ecart", [
    PyObj(sdm_oracle_terms_obj(f, domain)),
  ])
  py_obj_to_int(objenum_to_obj(res))
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
pub fn dup_routh_hurwitz(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.rootconditions.dup_routh_hurwitz",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_schur_conditions(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.rootconditions.dup_schur_conditions",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_add_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_add_term",
    [DupCoeffs(f), DomainNumber(c), CallInt(k), DomainObject],
    domain,
  )
}

///|
pub fn dup_sub_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_sub_term",
    [DupCoeffs(f), DomainNumber(c), CallInt(k), DomainObject],
    domain,
  )
}

///|
pub fn dup_mul_term(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  k : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_mul_term",
    [DupCoeffs(f), DomainNumber(c), CallInt(k), DomainObject],
    domain,
  )
}

///|
pub fn dup_add_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_add_ground",
    [DupCoeffs(f), DomainNumber(c), DomainObject],
    domain,
  )
}

///|
pub fn dup_sub_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_sub_ground",
    [DupCoeffs(f), DomainNumber(c), DomainObject],
    domain,
  )
}

///|
pub fn dup_mul_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_mul_ground",
    [DupCoeffs(f), DomainNumber(c), DomainObject],
    domain,
  )
}

///|
pub fn dup_quo_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_quo_ground",
    [DupCoeffs(f), DomainNumber(c), DomainObject],
    domain,
  )
}

///|
pub fn dup_exquo_ground(
  f : Array[@symnum.BigRational],
  c : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_exquo_ground",
    [DupCoeffs(f), RawNumber(c), DomainObject],
    domain,
  )
}

///|
pub fn dup_lshift(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_lshift",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_rshift(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_rshift",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_neg(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_neg",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_abs(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_abs",
    [RawDupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_add(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_add",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_sub(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_sub",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_mul(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_mul",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_sqr(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_sqr",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_pow(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_pow",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_series_mul(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_series_mul",
    [DupCoeffs(f), DupCoeffs(g), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_series_sqr(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_series_sqr",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_series_pow(
  f : Array[@symnum.BigRational],
  n : Int,
  prec : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_series_pow",
    [DupCoeffs(f), CallInt(n), CallInt(prec), DomainObject],
    domain,
  )
}

///|
pub fn dup_rr_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_rr_div",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_ff_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_ff_div",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_div(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_div",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_rem(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_rem",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_quo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_quo",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_exquo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_exquo",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dup_pexquo(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_pexquo",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
fn euclidtools_dup_call(
  name : String,
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain : String,
) -> String raise {
  dense_recipe_call(
    "sympy.polys.euclidtools.\{name}",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
fn euclidtools_dmp_call(
  name : String,
  f : DenseData,
  g : DenseData,
  u : Int,
  domain : String,
) -> String raise {
  dense_recipe_call(
    "sympy.polys.euclidtools.\{name}",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
fn euclidtools_dup_unary_call(
  name : String,
  f : Array[@symnum.BigRational],
  domain : String,
) -> String raise {
  dense_recipe_call(
    "sympy.polys.euclidtools.\{name}",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
fn euclidtools_dmp_unary_call(
  name : String,
  f : DenseData,
  u : Int,
  domain : String,
) -> String raise {
  dense_recipe_call(
    "sympy.polys.euclidtools.\{name}",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_half_gcdex(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_half_gcdex", f, g, domain)
}

///|
pub fn dmp_half_gcdex(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_half_gcdex", f, g, u, domain)
}

///|
pub fn dup_gcdex(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_gcdex", f, g, domain)
}

///|
pub fn dmp_gcdex(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_gcdex", f, g, u, domain)
}

///|
pub fn dup_invert(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_invert", f, g, domain)
}

///|
pub fn dmp_invert(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_invert", f, g, u, domain)
}

///|
pub fn dup_euclidean_prs(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_euclidean_prs", f, g, domain)
}

///|
pub fn dmp_euclidean_prs(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_euclidean_prs", f, g, u, domain)
}

///|
pub fn dup_primitive_prs(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_primitive_prs", f, g, domain)
}

///|
pub fn dmp_primitive_prs(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_primitive_prs", f, g, u, domain)
}

///|
pub fn dup_inner_subresultants(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_inner_subresultants", f, g, domain)
}

///|
pub fn dmp_inner_subresultants(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_inner_subresultants", f, g, u, domain)
}

///|
pub fn dup_subresultants(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_subresultants", f, g, domain)
}

///|
pub fn dmp_subresultants(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_subresultants", f, g, u, domain)
}

///|
pub fn dup_prs_resultant(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_prs_resultant", f, g, domain)
}

///|
pub fn dmp_prs_resultant(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_prs_resultant", f, g, u, domain)
}

///|
pub fn dup_resultant(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_resultant", f, g, domain)
}

///|
pub fn dmp_resultant(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_resultant", f, g, u, domain)
}

///|
pub fn dmp_zz_modular_resultant(
  f : DenseData,
  g : DenseData,
  p : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.euclidtools.dmp_zz_modular_resultant",
    [DenseValue(f), DenseValue(g), CallInt(p), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_zz_collins_resultant(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  let name = if u == 0 { "dmp_resultant" } else { "dmp_zz_collins_resultant" }
  euclidtools_dmp_call(name, f, g, u, domain)
}

///|
pub fn dmp_qq_collins_resultant(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  let name = if u == 0 { "dmp_resultant" } else { "dmp_qq_collins_resultant" }
  euclidtools_dmp_call(name, f, g, u, domain)
}

///|
pub fn dup_discriminant(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_unary_call("dup_discriminant", f, domain)
}

///|
pub fn dmp_discriminant(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_unary_call("dmp_discriminant", f, u, domain)
}

///|
pub fn dup_rr_prs_gcd(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_rr_prs_gcd", f, g, domain)
}

///|
pub fn dup_ff_prs_gcd(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_ff_prs_gcd", f, g, domain)
}

///|
pub fn dup_zz_heu_gcd(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_zz_heu_gcd", f, g, domain)
}

///|
pub fn dup_qq_heu_gcd(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_qq_heu_gcd", f, g, domain)
}

///|
pub fn dup_inner_gcd(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_inner_gcd", f, g, domain)
}

///|
pub fn dup_gcd(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_gcd", f, g, domain)
}

///|
pub fn dup_rr_lcm(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_rr_lcm", f, g, domain)
}

///|
pub fn dup_ff_lcm(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dup_call("dup_ff_lcm", f, g, domain)
}

///|
pub fn dup_lcm(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_lcm", f, g, domain)
}

///|
pub fn dup_cancel(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dup_call("dup_cancel", f, g, domain)
}

///|
pub fn dmp_rr_prs_gcd(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_rr_prs_gcd", f, g, u, domain)
}

///|
pub fn dmp_ff_prs_gcd(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_ff_prs_gcd", f, g, u, domain)
}

///|
pub fn dmp_zz_heu_gcd(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_zz_heu_gcd", f, g, u, domain)
}

///|
pub fn dmp_qq_heu_gcd(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_qq_heu_gcd", f, g, u, domain)
}

///|
pub fn dmp_inner_gcd(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_inner_gcd", f, g, u, domain)
}

///|
pub fn dmp_gcd(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_gcd", f, g, u, domain)
}

///|
pub fn dmp_rr_lcm(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_rr_lcm", f, g, u, domain)
}

///|
pub fn dmp_ff_lcm(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  euclidtools_dmp_call("dmp_ff_lcm", f, g, u, domain)
}

///|
pub fn dmp_lcm(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_lcm", f, g, u, domain)
}

///|
pub fn dmp_content(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_unary_call("dmp_content", f, u, domain)
}

///|
pub fn dmp_primitive(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_unary_call("dmp_primitive", f, u, domain)
}

///|
pub fn dmp_cancel(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  euclidtools_dmp_call("dmp_cancel", f, g, u, domain)
}

///|
pub fn dmp_add_term(
  f : DenseData,
  c : DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_add_term",
    [DenseValue(f), DenseValue(c), CallInt(k), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_sub_term(
  f : DenseData,
  c : DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_sub_term",
    [DenseValue(f), DenseValue(c), CallInt(k), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_mul_term(
  f : DenseData,
  c : DenseData,
  k : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_mul_term",
    [DenseValue(f), DenseValue(c), CallInt(k), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_add_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_add_ground",
    [DenseValue(f), DomainNumber(c), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_sub_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_sub_ground",
    [DenseValue(f), DomainNumber(c), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_mul_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_mul_ground",
    [DenseValue(f), DomainNumber(c), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_quo_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_quo_ground",
    [DenseValue(f), DomainNumber(c), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_exquo_ground(
  f : DenseData,
  c : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_exquo_ground",
    [DenseValue(f), DomainNumber(c), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_abs(f : DenseData, u : Int, domain? : String = "ZZ") -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_abs",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_neg(f : DenseData, u : Int, domain? : String = "ZZ") -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_neg",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_add(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_add",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_sub(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_sub",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_mul(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_mul",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_sqr(f : DenseData, u : Int, domain? : String = "ZZ") -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_sqr",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_pow(
  f : DenseData,
  n : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_pow",
    [DenseValue(f), CallInt(n), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_add_mul(
  f : DenseData,
  g : DenseData,
  h : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_add_mul",
    [DenseValue(f), DenseValue(g), DenseValue(h), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_sub_mul(
  f : DenseData,
  g : DenseData,
  h : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_sub_mul",
    [DenseValue(f), DenseValue(g), DenseValue(h), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_pdiv(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_pdiv",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_prem(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_prem",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_pquo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_pquo",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_pexquo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_pexquo",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_rr_div(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_rr_div",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_ff_div(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_ff_div",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_div(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_div",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_rem(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_rem",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_quo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_quo",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_exquo(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_exquo",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_max_norm(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_max_norm",
    [DupCoeffs(f), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dmp_max_norm(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_max_norm",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dup_l1_norm(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_l1_norm",
    [DupCoeffs(f), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dmp_l1_norm(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_l1_norm",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dup_l2_norm_squared(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_l2_norm_squared",
    [DupCoeffs(f), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dmp_l2_norm_squared(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_l2_norm_squared",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dup_expand(
  polys : Array[Array[@symnum.BigRational]],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dup_expand",
    [DupCollection(polys), DomainObject],
    domain,
  )
}

///|
pub fn dmp_expand(
  polys : Array[DenseData],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densearith.dmp_expand",
    [DenseCollection(polys), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_from_sympy(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dup_from_sympy",
    [RawDupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_from_list(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dup_from_list",
    [RawDupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_pretty(
  f : Array[@symnum.BigRational],
  sym : String,
  ascending? : Bool = false,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dup_pretty",
    [DupCoeffs(f), CallStr(sym)],
    domain,
    kwargs={ "ascending": CallBool(ascending) },
    result_kind=ScalarResult,
  )
}

///|
fn sympy_poly_obj_from_expr_oracle(
  expr : @symcore.Expr,
  gens : Array[String],
) -> @py.PyObject raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  call_sympy_poly(expr_obj, gens_list, "", None)
}

///|
pub fn dispersionset_expr(
  p : @symcore.Expr,
  q? : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let p_obj = sympy_poly_obj_from_expr_oracle(p, gens)
  let args : Array[LegacyArg] = [PyObj(p_obj)]
  match q {
    Some(expr) => {
      let q_obj = sympy_poly_obj_from_expr_oracle(expr, gens)
      args.push(PyObj(q_obj))
    }
    None => ()
  }
  let res = sympy_call_must("sympy.polys.dispersion.dispersionset", args)
  let builtins = ensure_builtins_module()
  let sorted_call = resolve_callable(builtins, "sorted")
  let sorted_res = py_call_one(sorted_call, objenum_to_obj(res))
  let items = py_list_to_pyobjects(sorted_res)
  let parts : Array[String] = []
  for item in items {
    parts.push(py_obj_to_int(item).to_string())
  }
  let body = parts.join(",")
  "[\{body}]"
}

///|
pub fn dispersion_expr(
  p : @symcore.Expr,
  q? : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let p_obj = sympy_poly_obj_from_expr_oracle(p, gens)
  let args : Array[LegacyArg] = [PyObj(p_obj)]
  match q {
    Some(expr) => {
      let q_obj = sympy_poly_obj_from_expr_oracle(expr, gens)
      args.push(PyObj(q_obj))
    }
    None => ()
  }
  let res = sympy_call_must("sympy.polys.dispersion.dispersion", args)
  py_str_enum(res)
}

///|
pub fn dmp_from_sympy(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_from_sympy",
    [RawDenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_exclude(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_exclude",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_include(
  f : DenseData,
  jlist : Array[Int],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_include",
    [DenseValue(f), CallIntList(jlist), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_terms_gcd(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dup_terms_gcd",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dmp_terms_gcd(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_terms_gcd",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_list_terms(
  f : DenseData,
  u : Int,
  order? : String = "",
  domain? : String = "ZZ",
) -> String raise {
  let kwargs : Map[String, DenseCallArg] = Map([])
  if order != "" {
    kwargs["order"] = CallStr(order)
  }
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_list_terms",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
    kwargs~,
  )
}

///|
pub fn dup_slice(
  f : Array[@symnum.BigRational],
  m : Int,
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dup_slice",
    [DupCoeffs(f), CallInt(m), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_truncate(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dup_truncate",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dmp_slice(
  f : DenseData,
  m : Int,
  n : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_slice",
    [DenseValue(f), CallInt(m), CallInt(n), CallInt(u), DomainObject],
    domain,
  )
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
  dense_recipe_call(
    "sympy.polys.densebasic.dmp_slice_in",
    [
      DenseValue(f),
      CallInt(m),
      CallInt(n),
      CallInt(j),
      CallInt(u),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn symmetrize(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  formal? : Bool = false,
  symbols? : Array[String] = [],
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(expr)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if formal {
    kwargs["formal"] = Bool(true)
  }
  if !symbols.is_empty() {
    let sym_objs = sympy_symbols_from_names(symbols)
    let list = py_list_from_objects(sym_objs)
    kwargs["symbols"] = PyObj(list.obj())
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_list.obj()))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if formal {
    kwargs["formal"] = Bool(true)
  }
  if !symbols.is_empty() {
    let sym_objs = sympy_symbols_from_names(symbols)
    let list = py_list_from_objects(sym_objs)
    kwargs["symbols"] = PyObj(list.obj())
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(expr)))
  if !gens.is_empty() {
    let gens_list = sympy_symbols_from_names(gens)
    for gen in gens_list {
      args.push(PyObj(gen))
    }
  }
  let kwargs : Map[String, LegacyArg] = Map([])
  if wrt != "" {
    kwargs["wrt"] = PyObj(sympy_symbol_obj(wrt))
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(expr)))
  if !roots.is_empty() {
    let root_objs = sympy_symbols_from_names(roots)
    let list = py_list_from_objects(root_objs)
    args.push(PyObj(list.obj()))
  }
  if gen != "" {
    args.push(PyObj(sympy_symbol_obj(gen)))
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
fn densetools_call(
  name : String,
  args : Array[DenseCallArg],
  domain : String,
) -> String raise {
  dense_recipe_call("sympy.polys.densetools.\{name}", args, domain)
}

///|
pub fn dup_integrate(
  f : Array[@symnum.BigRational],
  m : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_integrate",
    [DupCoeffs(f), CallInt(m), DomainObject],
    domain,
  )
}

///|
pub fn dmp_integrate(
  f : DenseData,
  m : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_integrate",
    [DenseValue(f), CallInt(m), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_integrate_in(
  f : DenseData,
  m : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_integrate_in",
    [DenseValue(f), CallInt(m), CallInt(j), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_diff(
  f : Array[@symnum.BigRational],
  m : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_diff", [DupCoeffs(f), CallInt(m), DomainObject], domain)
}

///|
pub fn dmp_diff(
  f : DenseData,
  m : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_diff",
    [DenseValue(f), CallInt(m), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_diff_in(
  f : DenseData,
  m : Int,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_diff_in",
    [DenseValue(f), CallInt(m), CallInt(j), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_eval(
  f : Array[@symnum.BigRational],
  a : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_eval",
    [DupCoeffs(f), DomainNumber(a), DomainObject],
    domain,
  )
}

///|
pub fn dmp_eval(
  f : DenseData,
  a : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_eval",
    [DenseValue(f), DomainNumber(a), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_eval_in(
  f : DenseData,
  a : @symnum.BigRational,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_eval_in",
    [DenseValue(f), DomainNumber(a), CallInt(j), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_monic(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_monic", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_ground_monic(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_ground_monic",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_content(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_content", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_ground_content(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_ground_content",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_primitive(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_primitive", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_ground_primitive(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_ground_primitive",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_trunc(
  f : Array[@symnum.BigRational],
  p : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_trunc",
    [DupCoeffs(f), DomainNumber(p), DomainObject],
    domain,
  )
}

///|
pub fn dmp_trunc(
  f : DenseData,
  p : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_trunc",
    [DenseValue(f), DenseValue(p), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_ground_trunc(
  f : DenseData,
  p : @symnum.BigRational,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_ground_trunc",
    [DenseValue(f), DomainNumber(p), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_extract(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_extract",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dmp_ground_extract(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_ground_extract",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_real_imag(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_real_imag", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dup_mirror(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_mirror", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dup_scale(
  f : Array[@symnum.BigRational],
  a : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_scale",
    [DupCoeffs(f), DomainNumber(a), DomainObject],
    domain,
  )
}

///|
pub fn dup_shift(
  f : Array[@symnum.BigRational],
  a : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_shift",
    [DupCoeffs(f), DomainNumber(a), DomainObject],
    domain,
  )
}

///|
pub fn dmp_shift(
  f : DenseData,
  a : Array[@symnum.BigRational],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_shift",
    [DenseValue(f), DupCoeffs(a), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_transform(
  f : Array[@symnum.BigRational],
  p : Array[@symnum.BigRational],
  q : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_transform",
    [DupCoeffs(f), DupCoeffs(p), DupCoeffs(q), DomainObject],
    domain,
  )
}

///|
pub fn dup_compose(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_compose",
    [DupCoeffs(f), DupCoeffs(g), DomainObject],
    domain,
  )
}

///|
pub fn dmp_compose(
  f : DenseData,
  g : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_compose",
    [DenseValue(f), DenseValue(g), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_eval_tail(
  f : DenseData,
  values : Array[@symnum.BigRational],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_eval_tail",
    [DenseValue(f), DupCoeffs(values), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_diff_eval_in(
  f : DenseData,
  m : Int,
  a : @symnum.BigRational,
  j : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dmp_diff_eval_in",
    [
      DenseValue(f),
      CallInt(m),
      DomainNumber(a),
      CallInt(j),
      CallInt(u),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn dup_sign_variations(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_sign_variations", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dup_clear_denoms(
  f : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  densetools_call("dup_clear_denoms", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_clear_denoms(
  f : DenseData,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  densetools_call(
    "dmp_clear_denoms",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_revert(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "QQ",
) -> String raise {
  densetools_call(
    "dup_revert",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dmp_revert(
  f : DenseData,
  n : Int,
  u : Int,
  domain? : String = "QQ",
) -> String raise {
  densetools_call(
    "dmp_revert",
    [DenseValue(f), CallInt(n), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_series_compose(
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  densetools_call(
    "dup_series_compose",
    [DupCoeffs(f), DupCoeffs(g), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_series_reversion(
  f : Array[@symnum.BigRational],
  n : Int,
  domain? : String = "QQ",
) -> String raise {
  densetools_call(
    "dup_series_reversion",
    [DupCoeffs(f), CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dup_decompose(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  densetools_call("dup_decompose", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_alg_inject_exprs(
  f : Array[String],
  u : Int,
  domain_spec? : String = "QQ<sqrt(2)>",
) -> String raise {
  densetools_call(
    "dmp_alg_inject",
    [FromSympyExprs(f), CallInt(u), DomainObject],
    domain_spec,
  )
}

///|
pub fn dmp_lift_exprs(
  f : Array[String],
  u : Int,
  domain_spec? : String = "QQ<sqrt(2)>",
) -> String raise {
  densetools_call(
    "dmp_lift",
    [FromSympyExprs(f), CallInt(u), DomainObject],
    domain_spec,
  )
}

///|
fn sqf_dense_call(
  name : String,
  args : Array[DenseCallArg],
  domain : String,
  result_kind? : DenseResultKind = DenseResult,
) -> String raise {
  dense_recipe_call(
    "sympy.polys.sqfreetools.\{name}",
    args,
    domain,
    result_kind~,
  )
}

///|
fn sqf_dense_bool_call(
  name : String,
  args : Array[DenseCallArg],
  domain : String,
) -> Bool raise {
  dense_recipe_bool_call("sympy.polys.sqfreetools.\{name}", args, domain)
}

///|
pub fn dup_sqf_p(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> Bool raise {
  sqf_dense_bool_call("dup_sqf_p", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_sqf_p(f : DenseData, u : Int, domain? : String = "ZZ") -> Bool raise {
  sqf_dense_bool_call(
    "dmp_sqf_p",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_sqf_part(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  sqf_dense_call("dup_sqf_part", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_sqf_part(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  sqf_dense_call(
    "dmp_sqf_part",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_sqf_list(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
  all? : Bool = false,
) -> String raise {
  sqf_dense_call(
    "dup_sqf_list",
    [DupCoeffs(f), DomainObject, CallBool(all)],
    domain,
  )
}

///|
pub fn dmp_sqf_list(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
  all? : Bool = false,
) -> String raise {
  sqf_dense_call(
    "dmp_sqf_list",
    [DenseValue(f), CallInt(u), DomainObject, CallBool(all)],
    domain,
  )
}

///|
pub fn dup_sqf_list_include(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
  all? : Bool = false,
) -> String raise {
  sqf_dense_call(
    "dup_sqf_list_include",
    [DupCoeffs(f), DomainObject, CallBool(all)],
    domain,
  )
}

///|
pub fn dmp_sqf_list_include(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
  all? : Bool = false,
) -> String raise {
  sqf_dense_call(
    "dmp_sqf_list_include",
    [DenseValue(f), CallInt(u), DomainObject, CallBool(all)],
    domain,
  )
}

///|
pub fn dup_gff_list(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  sqf_dense_call("dup_gff_list", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_gff_list(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  sqf_dense_call(
    "dmp_gff_list",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
fn fact_dense_call(
  name : String,
  args : Array[DenseCallArg],
  domain : String,
  result_kind? : DenseResultKind = DenseResult,
) -> String raise {
  dense_recipe_call(
    "sympy.polys.factortools.\{name}",
    args,
    domain,
    result_kind~,
  )
}

///|
fn fact_dense_bool_call(
  name : String,
  args : Array[DenseCallArg],
  domain : String,
) -> Bool raise {
  dense_recipe_bool_call("sympy.polys.factortools.\{name}", args, domain)
}

///|
pub fn dup_factor_list_include(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dup_factor_list_include",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dmp_factor_list(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_factor_list",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_factor_list_include(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_factor_list_include",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_trial_division(
  f : Array[@symnum.BigRational],
  factors : Array[Array[@symnum.BigRational]],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dup_trial_division",
    [DupCoeffs(f), DupCollection(factors), DomainObject],
    domain,
  )
}

///|
pub fn dmp_trial_division(
  f : DenseData,
  factors : Array[DenseData],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_trial_division",
    [DenseValue(f), DenseCollection(factors), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_irreducible_p(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> Bool raise {
  fact_dense_bool_call(
    "dup_irreducible_p",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dmp_irreducible_p(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> Bool raise {
  fact_dense_bool_call(
    "dmp_irreducible_p",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_gf_factor(f : Array[Int], p : Int) -> String raise {
  let domain = "GF(" + Show::to_string(p) + ")"
  fact_dense_call(
    "dup_gf_factor",
    [DomainIntCoeffs(f), DomainObject],
    domain,
    result_kind=DenseReprResult,
  )
}

///|
pub fn dup_ext_factor_shape_exprs(
  f : Array[String],
  domain_spec? : String = "QQ<sqrt(2)>",
) -> String raise {
  fact_dense_call(
    "dup_ext_factor",
    [FromSympyExprs(f), DomainObject],
    domain_spec,
    result_kind=ExtFactorShapeResult,
  )
}

///|
pub fn dup_qq_i_factor(
  f : Array[@symnum.BigRational],
  domain? : String = "QQ_I",
) -> String raise {
  fact_dense_call("dup_qq_i_factor", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dup_zz_i_factor(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ_I",
) -> String raise {
  fact_dense_call("dup_zz_i_factor", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_qq_i_factor(
  f : DenseData,
  u : Int,
  domain? : String = "QQ_I",
) -> String raise {
  fact_dense_call(
    "dmp_qq_i_factor",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dmp_zz_i_factor(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ_I",
) -> String raise {
  fact_dense_call(
    "dmp_zz_i_factor",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_zz_zassenhaus(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call("dup_zz_zassenhaus", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dup_zz_hensel_step(
  m : Int,
  f : Array[@symnum.BigRational],
  g : Array[@symnum.BigRational],
  h : Array[@symnum.BigRational],
  s : Array[@symnum.BigRational],
  t : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dup_zz_hensel_step",
    [
      CallInt(m),
      DupCoeffs(f),
      DupCoeffs(g),
      DupCoeffs(h),
      DupCoeffs(s),
      DupCoeffs(t),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn dup_zz_hensel_lift(
  p : Int,
  f : Array[@symnum.BigRational],
  f_list : Array[Array[@symnum.BigRational]],
  l : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dup_zz_hensel_lift",
    [CallInt(p), DupCoeffs(f), DupCollection(f_list), CallInt(l), DomainObject],
    domain,
  )
}

///|
pub fn dmp_zz_wang_non_divisors(
  values : Array[@symnum.BigRational],
  cs : @symnum.BigRational,
  ct : @symnum.BigRational,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_wang_non_divisors",
    [DupCoeffs(values), DomainNumber(cs), DomainNumber(ct), DomainObject],
    domain,
  )
}

///|
pub fn dmp_zz_wang_test_points(
  f : DenseData,
  factors : Array[(DenseData, Int)],
  ct : @symnum.BigRational,
  eval_points : Array[@symnum.BigRational],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_wang_test_points",
    [
      DenseValue(f),
      DenseFactorPairs(factors),
      DomainNumber(ct),
      DupCoeffs(eval_points),
      CallInt(u),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn dmp_zz_wang_lead_coeffs(
  f : DenseData,
  factors : Array[(DenseData, Int)],
  cs : @symnum.BigRational,
  values : Array[@symnum.BigRational],
  univar_factors : Array[Array[@symnum.BigRational]],
  eval_points : Array[@symnum.BigRational],
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_wang_lead_coeffs",
    [
      DenseValue(f),
      DenseFactorPairs(factors),
      DomainNumber(cs),
      DupCoeffs(values),
      DupCollection(univar_factors),
      DupCoeffs(eval_points),
      CallInt(u),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn dmp_zz_wang_hensel_lifting(
  f : DenseData,
  factors : Array[Array[@symnum.BigRational]],
  lead_coeffs : Array[DenseData],
  eval_points : Array[@symnum.BigRational],
  p : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_wang_hensel_lifting",
    [
      DenseValue(f),
      DupCollection(factors),
      DenseCollection(lead_coeffs),
      DupCoeffs(eval_points),
      CallInt(p),
      CallInt(u),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn dmp_zz_wang(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_wang",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_zz_diophantine(
  factors : Array[Array[@symnum.BigRational]],
  m : Int,
  p : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dup_zz_diophantine",
    [DupCollection(factors), CallInt(m), CallInt(p), DomainObject],
    domain,
  )
}

///|
pub fn dmp_zz_diophantine(
  factors : Array[DenseData],
  c : DenseData,
  eval_points : Array[@symnum.BigRational],
  d : Int,
  p : Int,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_diophantine",
    [
      DenseCollection(factors),
      DenseValue(c),
      DupCoeffs(eval_points),
      CallInt(d),
      CallInt(p),
      CallInt(u),
      DomainObject,
    ],
    domain,
  )
}

///|
pub fn dup_zz_factor_sqf(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call("dup_zz_factor_sqf", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dup_zz_factor(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call("dup_zz_factor", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_zz_factor(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_factor",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_zz_mignotte_bound(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call("dup_zz_mignotte_bound", [DupCoeffs(f), DomainObject], domain)
}

///|
pub fn dmp_zz_mignotte_bound(
  f : DenseData,
  u : Int,
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dmp_zz_mignotte_bound",
    [DenseValue(f), CallInt(u), DomainObject],
    domain,
  )
}

///|
pub fn dup_zz_irreducible_p(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> Bool raise {
  fact_dense_bool_call(
    "dup_zz_irreducible_p",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_zz_cyclotomic_poly(n : Int, domain? : String = "ZZ") -> String raise {
  fact_dense_call("dup_zz_cyclotomic_poly", [CallInt(n), DomainObject], domain)
}

///|
pub fn dup_zz_cyclotomic_factor(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
) -> String raise {
  fact_dense_call(
    "dup_zz_cyclotomic_factor",
    [DupCoeffs(f), DomainObject],
    domain,
  )
}

///|
pub fn dup_cyclotomic_p(
  f : Array[@symnum.BigRational],
  domain? : String = "ZZ",
  irreducible? : Bool = false,
) -> Bool raise {
  fact_dense_bool_call(
    "dup_cyclotomic_p",
    [DupCoeffs(f), DomainObject, CallBool(irreducible)],
    domain,
  )
}

///|
pub fn python_gcd(a : Int, b : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.domains.groundtypes.python_gcd", [
    Int(a),
    Int(b),
  ])
  remove_spaces(py_sympy_enum_str(res))
}

///|
pub fn python_lcm(a : Int, b : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.domains.groundtypes.python_lcm", [
    Int(a),
    Int(b),
  ])
  remove_spaces(py_sympy_enum_str(res))
}

///|
pub fn python_gcdex(a : Int, b : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.domains.groundtypes.python_gcdex", [
    Int(a),
    Int(b),
  ])
  remove_spaces(py_sympy_enum_str(res))
}

///|
pub fn dmp_norm_exprs(
  f : Array[String],
  u : Int,
  domain_spec? : String = "QQ<sqrt(3)>",
) -> String raise {
  sqf_dense_call(
    "dmp_norm",
    [FromSympyExprs(f), CallInt(u), DomainObject],
    domain_spec,
    result_kind=AlgebraicDenseResult,
  )
}

///|
pub fn dup_sqf_norm_exprs(
  f : Array[String],
  domain_spec? : String = "QQ<sqrt(3)>",
) -> String raise {
  sqf_dense_call(
    "dup_sqf_norm",
    [FromSympyExprs(f), DomainObject],
    domain_spec,
    result_kind=AlgebraicDenseResult,
  )
}

///|
pub fn dmp_sqf_norm_exprs(
  f : Array[String],
  u : Int,
  domain_spec? : String = "QQ<sqrt(3)>",
) -> String raise {
  sqf_dense_call(
    "dmp_sqf_norm",
    [FromSympyExprs(f), CallInt(u), DomainObject],
    domain_spec,
    result_kind=AlgebraicDenseResult,
  )
}

///|
pub fn gf_strip(f : Array[Int]) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_strip", [IntList(f)])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_trunc(f : Array[Int], p : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_trunc", [
    IntList(f),
    Int(p),
  ])
  remove_spaces(py_dense_str(res))
}

///|
fn gf_int_dict_obj(values : Map[Int, Int]) -> @py.PyObject raise {
  let dict = py_dict_new()
  let setitem = resolve_method_callable(dict.obj(), "__setitem__")
  for key, value in values {
    let tup = py_tuple_from_objects([py_int_obj(key), py_int_obj(value)])
    let _ = py_call_object_allow_none(setitem, tup, print_err=true)
  }
  dict.obj()
}

///|
fn gf_zz_call(name : String, args : Array[LegacyArg]) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.\{name}", args)
  remove_spaces(py_dense_str(res))
}

///|
fn gf_zz_unary(name : String, f : Array[Int], p : Int) -> String raise {
  gf_zz_call(name, [IntList(f), Int(p), PyObj(sympy_domain_obj("ZZ"))])
}

///|
pub fn gf_int(a : Int, p : Int) -> Int raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_int", [Int(a), Int(p)])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn gf_normal(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_normal", f, p)
}

///|
pub fn gf_from_dict(values : Map[Int, Int], p : Int) -> String raise {
  gf_zz_call("gf_from_dict", [
    PyObj(gf_int_dict_obj(values)),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_to_dict(
  f : Array[Int],
  p : Int,
  symmetric? : Bool = true,
) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_to_dict", [
    IntList(f),
    Int(p),
    Bool(symmetric),
  ])
  py_str_enum(res)
}

///|
pub fn gf_from_int_poly(f : Array[Int], p : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_from_int_poly", [
    IntList(f),
    Int(p),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_to_int_poly(
  f : Array[Int],
  p : Int,
  symmetric? : Bool = true,
) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_to_int_poly", [
    IntList(f),
    Int(p),
    Bool(symmetric),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_neg(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_neg", f, p)
}

///|
pub fn gf_add_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_add_ground", [
    IntList(f),
    Int(a),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_sub_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_sub_ground", [
    IntList(f),
    Int(a),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_mul_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_mul_ground", [
    IntList(f),
    Int(a),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_quo_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_quo_ground", [
    IntList(f),
    Int(a),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_add(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_add", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_sub(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_sub", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_mul(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_mul", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_sqr(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_sqr", f, p)
}

///|
pub fn gf_add_mul(
  f : Array[Int],
  g : Array[Int],
  h : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_add_mul", [
    IntList(f),
    IntList(g),
    IntList(h),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_sub_mul(
  f : Array[Int],
  g : Array[Int],
  h : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_sub_mul", [
    IntList(f),
    IntList(g),
    IntList(h),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
fn gf_factor_powers_obj(factors : Array[(Array[Int], Int)]) -> @py.PyObject {
  let items : Array[@py.PyObject] = []
  for factor in factors {
    let coeffs : Array[@py.PyObject] = []
    for coeff in factor.0 {
      coeffs.push(py_int_obj(coeff))
    }
    let pair = py_tuple_from_objects([
      py_list_from_objects(coeffs).obj(),
      py_int_obj(factor.1),
    ])
    items.push(pair.obj())
  }
  py_list_from_objects(items).obj()
}

///|
fn gf_int_matrix_obj(matrix : Array[Array[Int]]) -> @py.PyObject {
  let rows : Array[@py.PyObject] = []
  for row in matrix {
    let items : Array[@py.PyObject] = []
    for coeff in row {
      items.push(py_int_obj(coeff))
    }
    rows.push(py_list_from_objects(items).obj())
  }
  py_list_from_objects(rows).obj()
}

///|
fn gf_bool_call(name : String, args : Array[LegacyArg]) -> Bool raise {
  let res = sympy_call_must("sympy.polys.galoistools.\{name}", args)
  match res {
    PyBool(v) => py_str_obj(v.obj()) == "True"
    _ => py_str_enum(res) == "True"
  }
}

///|
pub fn gf_expand(
  factors : Array[(Array[Int], Int)],
  p : Int,
  lc? : Int = 1,
) -> String raise {
  let factor_obj = gf_factor_powers_obj(factors)
  let input_obj = if lc == 1 {
    factor_obj
  } else {
    py_tuple_from_objects([py_int_obj(lc), factor_obj]).obj()
  }
  gf_zz_call("gf_expand", [
    PyObj(input_obj),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_div(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_div", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_exquo(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_exquo", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_lshift(f : Array[Int], n : Int) -> String raise {
  gf_zz_call("gf_lshift", [IntList(f), Int(n), PyObj(sympy_domain_obj("ZZ"))])
}

///|
pub fn gf_rshift(f : Array[Int], n : Int) -> String raise {
  gf_zz_call("gf_rshift", [IntList(f), Int(n), PyObj(sympy_domain_obj("ZZ"))])
}

///|
pub fn gf_pow(f : Array[Int], n : Int, p : Int) -> String raise {
  gf_zz_call("gf_pow", [
    IntList(f),
    Int(n),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_pow_mod(
  f : Array[Int],
  n : Int,
  g : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_pow_mod", [
    IntList(f),
    Int(n),
    IntList(g),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_diff(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_diff", f, p)
}

///|
pub fn gf_eval(f : Array[Int], a : Int, p : Int) -> Int raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_eval", [
    IntList(f),
    Int(a),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn gf_multi_eval(
  f : Array[Int],
  values : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_multi_eval", [
    IntList(f),
    IntList(values),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_compose(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_compose", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_compose_mod(
  g : Array[Int],
  h : Array[Int],
  f : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_compose_mod", [
    IntList(g),
    IntList(h),
    IntList(f),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_frobenius_monomial_base(g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_frobenius_monomial_base", [
    IntList(g),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_frobenius_map(
  f : Array[Int],
  g : Array[Int],
  b : Array[Array[Int]],
  p : Int,
) -> String raise {
  gf_zz_call("gf_frobenius_map", [
    IntList(f),
    IntList(g),
    PyObj(gf_int_matrix_obj(b)),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_gcd(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_gcd", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_lcm(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_lcm", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_cofactors(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_cofactors", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_gcdex(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(IntList(f))
  args.push(IntList(g))
  args.push(Int(p))
  args.push(PyObj(sympy_domain_obj("ZZ")))
  let res = sympy_call_must("sympy.polys.galoistools.gf_gcdex", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_trace_map(
  a : Array[Int],
  b : Array[Int],
  c : Array[Int],
  n : Int,
  f : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_trace_map", [
    IntList(a),
    IntList(b),
    IntList(c),
    Int(n),
    IntList(f),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_irred_p_ben_or(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_irred_p_ben_or", [
    IntList(f),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_irred_p_rabin(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_irred_p_rabin", [
    IntList(f),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_irreducible_p(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_irreducible_p", [
    IntList(f),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_sqf_p(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_sqf_p", [IntList(f), Int(p), PyObj(sympy_domain_obj("ZZ"))])
}

///|
pub fn gf_sqf_part(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_sqf_part", f, p)
}

///|
pub fn gf_sqf_list(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_sqf_list", f, p)
}

///|
pub fn gf_Qmatrix(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_Qmatrix", f, p)
}

///|
pub fn gf_Qbasis(q : Array[Array[Int]], p : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_Qbasis", [
    PyObj(gf_int_matrix_obj(q)),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_berlekamp(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_berlekamp", f, p)
}

///|
pub fn gf_ddf_zassenhaus(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_ddf_zassenhaus", f, p)
}

///|
pub fn gf_edf_zassenhaus(f : Array[Int], n : Int, p : Int) -> String raise {
  gf_zz_call("gf_edf_zassenhaus", [
    IntList(f),
    Int(n),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_ddf_shoup(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_ddf_shoup", f, p)
}

///|
pub fn gf_edf_shoup(f : Array[Int], n : Int, p : Int) -> String raise {
  gf_zz_call("gf_edf_shoup", [
    IntList(f),
    Int(n),
    Int(p),
    PyObj(sympy_domain_obj("ZZ")),
  ])
}

///|
pub fn gf_zassenhaus(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_zassenhaus", f, p)
}

///|
pub fn gf_shoup(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_shoup", f, p)
}

///|
pub fn gf_factor_sqf(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_factor_sqf", f, p)
}

///|
pub fn gf_factor(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_factor", f, p)
}

///|
pub fn gf_crt(u : Array[Int], m : Array[Int]) -> Int raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_crt", [
    IntList(u),
    IntList(m),
    PyObj(sympy_domain_obj("ZZ")),
  ])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn gf_crt1(m : Array[Int]) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_crt1", [
    IntList(m),
    PyObj(sympy_domain_obj("ZZ")),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_crt2(
  u : Array[Int],
  m : Array[Int],
  p : Int,
  e : Array[Int],
  s : Array[Int],
) -> Int raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_crt2", [
    IntList(u),
    IntList(m),
    Int(p),
    IntList(e),
    IntList(s),
    PyObj(sympy_domain_obj("ZZ")),
  ])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn gf_value(f : Array[Int], a : Int) -> Int raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_value", [
    IntList(f),
    Int(a),
  ])
  py_obj_to_int(objenum_to_obj(res))
}

///|
pub fn linear_congruence(a : Int, b : Int, m : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.linear_congruence", [
    Int(a),
    Int(b),
    Int(m),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn csolve_prime(f : Array[Int], p : Int, e? : Int = 1) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.csolve_prime", [
    IntList(f),
    Int(p),
    Int(e),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn gf_csolve(f : Array[Int], n : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.galoistools.gf_csolve", [
    IntList(f),
    Int(n),
  ])
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_quartic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_quintic(
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_quintic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_binomial(
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_binomial", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn roots_cyclotomic(
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(poly))
  let res = sympy_call_must("sympy.polys.polyroots.roots_cyclotomic", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn preprocess_roots(
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
  let res = sympy_call_must("sympy.polys.polyroots.preprocess_roots", [
    PyObj(poly),
  ])
  let items = py_list_to_pyobjects(res)
  guard items.length() == 2 else { fail("preprocess-roots-result-shape") }
  let as_expr = resolve_method_callable(items[1], "as_expr")
  let poly_expr = py_call_noargs(as_expr)
  let coeff_text = remove_spaces(py_str_obj(items[0]))
  let poly_text = remove_spaces(py_str_enum(poly_expr))
  "\{coeff_text}||\{poly_text}"
}

///|
pub fn root_factors(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let gens_list = if gens.is_empty() {
    sympy_default_gens([expr_obj])
  } else {
    sympy_symbols_from_names(gens)
  }
  let args : Array[LegacyArg] = [PyObj(expr_obj)]
  for gen in gens_list {
    args.push(PyObj(gen))
  }
  let res = sympy_call_must("sympy.polys.polyroots.root_factors", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn rootof(
  expr : @symcore.Expr,
  index : Int,
  radicals? : Bool = true,
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(expr)))
  args.push(Int(index))
  let kwargs : Map[String, LegacyArg] = Map([])
  if !radicals {
    kwargs["radicals"] = Bool(false)
  }
  let res = sympy_call_must("sympy.polys.rootoftools.rootof", args, kwargs~)
  py_sympy_enum_str(res)
}

///|
pub fn dup_cauchy_upper_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_cauchy_upper_bound", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_cauchy_lower_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_cauchy_lower_bound", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_mignotte_sep_bound_squared", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_sturm(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must("sympy.polys.rootisolation.dup_sturm", args)
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_root_upper_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_root_upper_bound", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_root_lower_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_root_lower_bound", args,
  )
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
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_elem(s, domain)))
  args.push(PyObj(sympy_domain_elem(t, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let kwargs : Map[String, LegacyArg] = Map([])
  match steps {
    Some(k) => kwargs["steps"] = Int(k)
    None => ()
  }
  match eps {
    Some(e) => kwargs["eps"] = PyObj(sympy_domain_elem(e, domain))
    None => ()
  }
  match disjoint {
    Some(d) => kwargs["disjoint"] = PyObj(sympy_domain_elem(d, domain))
    None => ()
  }
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_refine_real_root",
    args,
    kwargs~,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_outer_refine_real_root(
  coeffs : Array[@symnum.BigRational],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  domain? : String = "QQ",
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_elem(s, domain)))
  args.push(PyObj(sympy_domain_elem(t, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let kwargs : Map[String, LegacyArg] = Map([])
  match steps {
    Some(k) => kwargs["steps"] = Int(k)
    None => ()
  }
  match eps {
    Some(e) => kwargs["eps"] = PyObj(sympy_domain_elem(e, domain))
    None => ()
  }
  match disjoint {
    Some(d) => kwargs["disjoint"] = PyObj(sympy_domain_elem(d, domain))
    None => ()
  }
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_outer_refine_real_root",
    args,
    kwargs~,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_isolate_real_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_isolate_real_roots_sqf", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_inner_isolate_real_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_inner_isolate_real_roots", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_inner_isolate_positive_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_inner_isolate_positive_roots", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_inner_isolate_negative_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_inner_isolate_negative_roots", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_isolate_real_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_isolate_real_roots", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_count_real_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
  inf? : @symnum.BigRational,
  sup? : @symnum.BigRational,
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let kwargs : Map[String, LegacyArg] = Map([])
  match inf {
    Some(v) => kwargs["inf"] = PyObj(sympy_domain_elem(v, domain))
    None => ()
  }
  match sup {
    Some(v) => kwargs["sup"] = PyObj(sympy_domain_elem(v, domain))
    None => ()
  }
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_count_real_roots",
    args,
    kwargs~,
  )
  py_sympy_enum_str(res)
}

///|
pub fn dup_count_complex_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_count_complex_roots", args,
  )
  py_sympy_enum_str(res)
}

///|
pub fn dup_isolate_complex_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_isolate_complex_roots_sqf", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_isolate_all_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_isolate_all_roots_sqf", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_isolate_all_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_rationals_domain(coeffs, domain)))
  args.push(PyObj(sympy_domain_obj(domain)))
  let res = sympy_call_must(
    "sympy.polys.rootisolation.dup_isolate_all_roots", args,
  )
  remove_spaces(py_dense_str(res))
}

///|
pub fn res_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.res", args)
  py_sympy_enum_str(res)
}

///|
pub fn res_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.res_q", args)
  py_sympy_enum_str(res)
}

///|
pub fn res_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.res_z", args)
  py_sympy_enum_str(res)
}

///|
pub fn subresultants_rem_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must(
    "sympy.polys.subresultants_qq_zz.subresultants_rem", args,
  )
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
fn subresultants_list_call_qq_zz(
  name : String,
  p : @symcore.Expr,
  q : @symcore.Expr,
  x : String,
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.\{name}", args)
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn subresultants_sylv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("subresultants_sylv", p, q, x)
}

///|
pub fn subresultants_bezout_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("subresultants_bezout", p, q, x)
}

///|
pub fn subresultants_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("subresultants_amv", p, q, x)
}

///|
pub fn subresultants_amv_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("subresultants_amv_q", p, q, x)
}

///|
pub fn subresultants_vv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("subresultants_vv", p, q, x)
}

///|
pub fn subresultants_vv_2_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("subresultants_vv_2", p, q, x)
}

///|
pub fn modified_subresultants_sylv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("modified_subresultants_sylv", p, q, x)
}

///|
pub fn modified_subresultants_bezout_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("modified_subresultants_bezout", p, q, x)
}

///|
pub fn modified_subresultants_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("modified_subresultants_amv", p, q, x)
}

///|
pub fn euclid_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.euclid_q", args)
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn euclid_pg_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("euclid_pg", p, q, x)
}

///|
pub fn euclid_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("euclid_amv", p, q, x)
}

///|
pub fn sturm_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.sturm_q", args)
  let items = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in items {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn sturm_pg_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("sturm_pg", p, q, x)
}

///|
pub fn sturm_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_list_call_qq_zz("sturm_amv", p, q, x)
}

///|
pub fn sign_seq_qq_zz(
  polys : Array[@symcore.Expr],
  x? : String = "x",
) -> String raise {
  let items : Array[@py.PyObject] = Array::new()
  for p in polys {
    items.push(expr_to_sympy(p))
  }
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_objects(items).obj()))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.sign_seq", args)
  let values = py_list_to_pyobjects(res)
  values.map(v => py_str_obj(v)).join(",")
}

///|
pub fn process_matrix_output_qq_zz(
  polys : Array[@symcore.Expr],
  x? : String = "x",
) -> String raise {
  let items : Array[@py.PyObject] = Array::new()
  for p in polys {
    items.push(expr_to_sympy(p))
  }
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(py_list_from_objects(items).obj()))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must(
    "sympy.polys.subresultants_qq_zz.process_matrix_output", args,
  )
  let values = py_list_to_pyobjects(res)
  let parts : Array[String] = Array::new()
  for item in values {
    parts.push(py_sympy_expr_str(item))
  }
  parts.join(" | ")
}

///|
pub fn compute_sign_qq_zz(base : Int, expo : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.compute_sign", [
    Int(base),
    Int(expo),
  ])
  py_str_enum(res)
}

///|
pub fn backward_eye_qq_zz(n : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.backward_eye", [
    Int(n),
  ])
  py_str_enum(res)
}

///|
pub fn sylvester_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
  kind? : Int = 1,
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  args.push(Int(kind))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.sylvester", args)
  py_str_enum(res)
}

///|
pub fn correct_sign_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
  rdel? : Int = 1,
  cdel? : Int = 0,
) -> String raise {
  let p_obj = expr_to_sympy(p)
  let q_obj = expr_to_sympy(q)
  let x_obj = sympy_symbol_obj(x)
  let s1 = sympy_call_must("sympy.polys.subresultants_qq_zz.sylvester", [
    PyObj(p_obj),
    PyObj(q_obj),
    PyObj(x_obj),
    Int(1),
  ])
  let deg_f = sympy_call_must("sympy.polys.polytools.degree", [
    PyObj(p_obj),
    PyObj(x_obj),
  ])
  let deg_g = sympy_call_must("sympy.polys.polytools.degree", [
    PyObj(q_obj),
    PyObj(x_obj),
  ])
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.correct_sign", [
    PyObj(objenum_to_obj(deg_f)),
    PyObj(objenum_to_obj(deg_g)),
    PyObj(objenum_to_obj(s1)),
    Int(rdel),
    Int(cdel),
  ])
  py_str_enum(res)
}

///|
fn subres_oracle_row_matrix(values : Array[Int]) -> @py.PyObject raise {
  let row = py_list_from_ints(values)
  let rows = py_list_from_objects([row]).obj()
  objenum_to_obj(sympy_call_must("sympy.Matrix", [PyObj(rows)]))
}

///|
fn subres_oracle_matrix(values : Array[Array[Int]]) -> @py.PyObject raise {
  let rows : Array[@py.PyObject] = []
  for row in values {
    rows.push(py_list_from_ints(row))
  }
  let py_rows = py_list_from_objects(rows).obj()
  objenum_to_obj(sympy_call_must("sympy.Matrix", [PyObj(py_rows)]))
}

///|
pub fn create_ma_qq_zz(
  deg_f : Int,
  deg_g : Int,
  row1 : Array[Int],
  row2 : Array[Int],
  col_num : Int,
) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.create_ma", [
    Int(deg_f),
    Int(deg_g),
    PyObj(subres_oracle_row_matrix(row1)),
    PyObj(subres_oracle_row_matrix(row2)),
    Int(col_num),
  ])
  py_str_enum(res)
}

///|
pub fn rotate_r_qq_zz(row : Array[Int], k : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.rotate_r", [
    PyObj(py_list_from_ints(row)),
    Int(k),
  ])
  py_str_enum(res)
}

///|
pub fn rotate_l_qq_zz(row : Array[Int], k : Int) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.rotate_l", [
    PyObj(py_list_from_ints(row)),
    Int(k),
  ])
  py_str_enum(res)
}

///|
pub fn row2poly_qq_zz(
  row : Array[Int],
  deg : Int,
  x? : String = "x",
) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.row2poly", [
    PyObj(py_list_from_ints(row)),
    Int(deg),
    PyObj(sympy_symbol_obj(x)),
  ])
  let as_expr = resolve_method_callable(objenum_to_obj(res), "as_expr")
  let expr = py_call_noargs(as_expr)
  py_str_enum(expr)
}

///|
pub fn pivot_qq_zz(
  matrix : Array[Array[Int]],
  i : Int,
  j : Int,
) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.pivot", [
    PyObj(subres_oracle_matrix(matrix)),
    Int(i),
    Int(j),
  ])
  py_str_enum(res)
}

///|
pub fn find_degree_qq_zz(
  matrix : Array[Array[Int]],
  deg_f : Int,
) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.find_degree", [
    PyObj(subres_oracle_matrix(matrix)),
    Int(deg_f),
  ])
  py_str_enum(res)
}

///|
pub fn final_touches_qq_zz(
  matrix : Array[Array[Int]],
  r : Int,
  deg_g : Int,
) -> String raise {
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.final_touches", [
    PyObj(subres_oracle_matrix(matrix)),
    Int(r),
    Int(deg_g),
  ])
  py_str_enum(res)
}

///|
pub fn bezout_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
  kind? : String = "bz",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  args.push(Str(kind))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.bezout", args)
  py_str_enum(res)
}

///|
pub fn rem_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.rem_z", args)
  py_sympy_enum_str(res)
}

///|
pub fn quo_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  let args : Array[LegacyArg] = Array::new()
  args.push(PyObj(expr_to_sympy(p)))
  args.push(PyObj(expr_to_sympy(q)))
  args.push(PyObj(sympy_symbol_obj(x)))
  let res = sympy_call_must("sympy.polys.subresultants_qq_zz.quo_z", args)
  py_sympy_enum_str(res)
}

///|
pub fn itermonomials_total(
  variables : Array[String],
  max_degree : Int,
  min_degree? : Int = 0,
) -> String raise {
  let vars = py_list_from_objects(sympy_symbols_from_names(variables)).obj()
  let res = sympy_call_must("sympy.polys.monomials.itermonomials", [
    PyObj(vars),
    Int(max_degree),
    Int(min_degree),
  ])
  sorted_py_iter_str(res)
}

///|
pub fn itermonomials_bounded(
  variables : Array[String],
  max_degrees : Array[Int],
  min_degrees : Array[Int],
) -> String raise {
  let vars = py_list_from_objects(sympy_symbols_from_names(variables)).obj()
  let res = sympy_call_must("sympy.polys.monomials.itermonomials", [
    PyObj(vars),
    PyObj(py_list_from_ints(max_degrees)),
    PyObj(py_list_from_ints(min_degrees)),
  ])
  sorted_py_iter_str(res)
}

///|
pub fn monomial_ldiv(a : Array[Int], b : Array[Int]) -> String raise {
  let res = sympy_call_must("sympy.polys.monomials.monomial_ldiv", [
    PyObj(py_list_from_ints(a)),
    PyObj(py_list_from_ints(b)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn monomial_deg(a : Array[Int]) -> String raise {
  let res = sympy_call_must("sympy.polys.monomials.monomial_deg", [
    PyObj(py_list_from_ints(a)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn term_div_zz(
  a_monom : Array[Int],
  a_coeff : Int,
  b_monom : Array[Int],
  b_coeff : Int,
) -> String raise {
  let a_term = py_tuple_from_objects([
    py_list_from_ints(a_monom),
    py_int_obj(a_coeff),
  ]).obj()
  let b_term = py_tuple_from_objects([
    py_list_from_ints(b_monom),
    py_int_obj(b_coeff),
  ]).obj()
  let res = sympy_call_must("sympy.polys.monomials.term_div", [
    PyObj(a_term),
    PyObj(b_term),
    PyObj(oracle_domain_from_spec("ZZ")),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn cyclotomic_poly(n : Int, x? : String = "x") -> String raise {
  let res = sympy_call_must("sympy.polys.specialpolys.cyclotomic_poly", [
    Int(n),
    PyObj(sympy_symbol_obj(x)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn swinnerton_dyer_poly(n : Int, x? : String = "x") -> String raise {
  let res = sympy_call_must("sympy.polys.specialpolys.swinnerton_dyer_poly", [
    Int(n),
    PyObj(sympy_symbol_obj(x)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn symmetric_poly(n : Int, gens : Array[String]) -> String raise {
  let args : Array[LegacyArg] = [Int(n)]
  for gen in gens {
    args.push(PyObj(sympy_symbol_obj(gen)))
  }
  let res = sympy_call_must("sympy.polys.specialpolys.symmetric_poly", args)
  py_sympy_enum_str(res)
}

///|
pub fn interpolating_poly(n : Int, x? : String = "x") -> String raise {
  let res = sympy_call_must("sympy.polys.specialpolys.interpolating_poly", [
    Int(n),
    PyObj(sympy_symbol_obj(x)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn interpolating_poly_values(
  n : Int,
  x : String,
  xs : Array[Int],
  ys : Array[Int],
) -> String raise {
  let res = sympy_call_must("sympy.polys.specialpolys.interpolating_poly", [
    Int(n),
    PyObj(sympy_symbol_obj(x)),
    PyObj(py_list_from_ints(xs)),
    PyObj(py_list_from_ints(ys)),
  ])
  py_sympy_enum_str(res)
}

///|
fn fateman_poly_tuple(path : String, n : Int) -> Array[String] raise {
  let res = sympy_call_must(path, [Int(n)])
  let items = py_list_to_pyobjects(res)
  let out : Array[String] = []
  for item in items {
    out.push(py_sympy_expr_str(item))
  }
  out
}

///|
pub fn fateman_poly_F_1(n : Int) -> Array[String] raise {
  fateman_poly_tuple("sympy.polys.specialpolys.fateman_poly_F_1", n)
}

///|
pub fn fateman_poly_F_2(n : Int) -> Array[String] raise {
  fateman_poly_tuple("sympy.polys.specialpolys.fateman_poly_F_2", n)
}

///|
pub fn fateman_poly_F_3(n : Int) -> Array[String] raise {
  fateman_poly_tuple("sympy.polys.specialpolys.fateman_poly_F_3", n)
}

///|
fn dmp_fateman_poly_tuple(
  path : String,
  n : Int,
  domain : String,
) -> String raise {
  let res = sympy_call_must(path, [Int(n), PyObj(sympy_domain_obj(domain))])
  remove_spaces(py_dense_str(res))
}

///|
pub fn dmp_fateman_poly_F_1(n : Int, domain? : String = "ZZ") -> String raise {
  dmp_fateman_poly_tuple(
    "sympy.polys.specialpolys.dmp_fateman_poly_F_1", n, domain,
  )
}

///|
pub fn dmp_fateman_poly_F_2(n : Int, domain? : String = "ZZ") -> String raise {
  dmp_fateman_poly_tuple(
    "sympy.polys.specialpolys.dmp_fateman_poly_F_2", n, domain,
  )
}

///|
pub fn dmp_fateman_poly_F_3(n : Int, domain? : String = "ZZ") -> String raise {
  dmp_fateman_poly_tuple(
    "sympy.polys.specialpolys.dmp_fateman_poly_F_3", n, domain,
  )
}

///|
fn special_poly_tuple(path : String) -> Array[String] raise {
  let res = sympy_call_must(path, [])
  let items = py_list_to_pyobjects(res)
  let out : Array[String] = []
  for item in items {
    out.push(py_sympy_expr_str(item))
  }
  out
}

///|
pub fn f_polys() -> Array[String] raise {
  special_poly_tuple("sympy.polys.specialpolys.f_polys")
}

///|
pub fn w_polys() -> Array[String] raise {
  special_poly_tuple("sympy.polys.specialpolys.w_polys")
}

///|
fn named_unary_poly(path : String, n : Int, x : String) -> String raise {
  let res = sympy_call_must(path, [Int(n), PyObj(sympy_symbol_obj(x))])
  py_sympy_enum_str(res)
}

///|
fn orth_dup_unary(path : String, n : Int, domain : String) -> String raise {
  let res = sympy_call_must(path, [Int(n), PyObj(sympy_domain_obj(domain))])
  remove_spaces(py_dense_str(res))
}

///|
fn orth_dup_param(
  path : String,
  n : Int,
  param : @symnum.BigRational,
  domain : String,
) -> String raise {
  let res = sympy_call_must(path, [
    Int(n),
    PyObj(sympy_domain_elem(param, domain)),
    PyObj(sympy_domain_obj(domain)),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_jacobi(
  n : Int,
  a : @symnum.BigRational,
  b : @symnum.BigRational,
  domain? : String = "QQ",
) -> String raise {
  let res = sympy_call_must("sympy.polys.orthopolys.dup_jacobi", [
    Int(n),
    PyObj(sympy_domain_elem(a, domain)),
    PyObj(sympy_domain_elem(b, domain)),
    PyObj(sympy_domain_obj(domain)),
  ])
  remove_spaces(py_dense_str(res))
}

///|
pub fn dup_gegenbauer(
  n : Int,
  a : @symnum.BigRational,
  domain? : String = "QQ",
) -> String raise {
  orth_dup_param("sympy.polys.orthopolys.dup_gegenbauer", n, a, domain)
}

///|
pub fn dup_chebyshevt(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("sympy.polys.orthopolys.dup_chebyshevt", n, domain)
}

///|
pub fn dup_chebyshevu(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("sympy.polys.orthopolys.dup_chebyshevu", n, domain)
}

///|
pub fn dup_hermite(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("sympy.polys.orthopolys.dup_hermite", n, domain)
}

///|
pub fn dup_hermite_prob(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("sympy.polys.orthopolys.dup_hermite_prob", n, domain)
}

///|
pub fn dup_legendre(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("sympy.polys.orthopolys.dup_legendre", n, domain)
}

///|
pub fn dup_laguerre(
  n : Int,
  alpha : @symnum.BigRational,
  domain? : String = "QQ",
) -> String raise {
  orth_dup_param("sympy.polys.orthopolys.dup_laguerre", n, alpha, domain)
}

///|
pub fn dup_spherical_bessel_fn(
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  orth_dup_unary("sympy.polys.orthopolys.dup_spherical_bessel_fn", n, domain)
}

///|
pub fn dup_spherical_bessel_fn_minus(
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  orth_dup_unary(
    "sympy.polys.orthopolys.dup_spherical_bessel_fn_minus", n, domain,
  )
}

///|
pub fn chebyshevt_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.orthopolys.chebyshevt_poly", n, x)
}

///|
pub fn chebyshevu_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.orthopolys.chebyshevu_poly", n, x)
}

///|
pub fn hermite_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.orthopolys.hermite_poly", n, x)
}

///|
pub fn hermite_prob_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.orthopolys.hermite_prob_poly", n, x)
}

///|
pub fn legendre_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.orthopolys.legendre_poly", n, x)
}

///|
pub fn laguerre_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.orthopolys.laguerre_poly", n, x)
}

///|
pub fn gegenbauer_poly(
  n : Int,
  a : @symnum.BigRational,
  x? : String = "x",
) -> String raise {
  let res = sympy_call_must("sympy.polys.orthopolys.gegenbauer_poly", [
    Int(n),
    PyObj(sympy_number_obj_oracle(a)),
    PyObj(sympy_symbol_obj(x)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn spherical_bessel_fn(n : Int, x? : String = "x") -> String raise {
  let res = sympy_call_must("sympy.polys.orthopolys.spherical_bessel_fn", [
    Int(n),
    PyObj(sympy_symbol_obj(x)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn jacobi_poly(
  n : Int,
  a : Int,
  b : Int,
  x? : String = "x",
) -> String raise {
  let res = sympy_call_must("sympy.polys.orthopolys.jacobi_poly", [
    Int(n),
    Int(a),
    Int(b),
    PyObj(sympy_symbol_obj(x)),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn dup_bernoulli(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("sympy.polys.appellseqs.dup_bernoulli", n, domain)
}

///|
pub fn dup_bernoulli_c(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("sympy.polys.appellseqs.dup_bernoulli_c", n, domain)
}

///|
pub fn dup_genocchi(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("sympy.polys.appellseqs.dup_genocchi", n, domain)
}

///|
pub fn dup_euler(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("sympy.polys.appellseqs.dup_euler", n, domain)
}

///|
pub fn dup_andre(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("sympy.polys.appellseqs.dup_andre", n, domain)
}

///|
pub fn bernoulli_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.appellseqs.bernoulli_poly", n, x)
}

///|
pub fn bernoulli_c_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.appellseqs.bernoulli_c_poly", n, x)
}

///|
pub fn genocchi_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.appellseqs.genocchi_poly", n, x)
}

///|
pub fn euler_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.appellseqs.euler_poly", n, x)
}

///|
pub fn andre_poly(n : Int, x? : String = "x") -> String raise {
  named_unary_poly("sympy.polys.appellseqs.andre_poly", n, x)
}

///|
pub fn construct_domain_domain(exprs : Array[@symcore.Expr]) -> String raise {
  let py_exprs : Array[@py.PyObject] = []
  for expr in exprs {
    py_exprs.push(expr_to_sympy(expr))
  }
  let res = sympy_call_must("sympy.polys.constructor.construct_domain", [
    PyObj(py_list_from_objects(py_exprs).obj()),
  ])
  let parts = py_list_to_pyobjects(res)
  guard parts.length() >= 1 else { fail("construct-domain-result-shape") }
  py_str_obj(parts[0])
}

///|
fn ring_series_oracle_poly(
  coeffs : Array[Int],
) -> (@py.PyObject, @py.PyObject, @py.PyObject) raise {
  let ring_tuple = sympy_call_must("sympy.polys.rings.ring", [
    Str("x"),
    PyObj(oracle_domain_from_spec("QQ")),
  ])
  let parts = py_list_to_pyobjects(ring_tuple)
  guard parts.length() >= 2 else { fail("ring-series-ring-shape") }
  let ring_obj = parts[0]
  let x_obj = parts[1]
  let reversed : Array[Int] = []
  let mut i = coeffs.length()
  while i > 0 {
    i = i - 1
    reversed.push(coeffs[i])
  }
  let from_list = resolve_method_callable(ring_obj, "from_list")
  let poly = objenum_to_obj(py_call_one(from_list, py_list_from_ints(reversed)))
  (ring_obj, x_obj, poly)
}

///|
fn ring_series_xy_oracle_poly(
  coeffs : Array[Int],
) -> (@py.PyObject, @py.PyObject, @py.PyObject, @py.PyObject) raise {
  let ring_tuple = sympy_call_must("sympy.polys.rings.ring", [
    Str("x,y"),
    PyObj(oracle_domain_from_spec("QQ")),
  ])
  let parts = py_list_to_pyobjects(ring_tuple)
  guard parts.length() >= 3 else { fail("ring-series-xy-ring-shape") }
  let ring_obj = parts[0]
  let x_obj = parts[1]
  let y_obj = parts[2]
  let zero = match py_get_attr(ring_obj, "zero") {
    Some(obj) => objenum_to_obj(obj)
    None => fail("ring-series-zero")
  }
  let ring_call = resolve_method_callable(ring_obj, "__call__")
  let builtins = ensure_builtins_module()
  let pow_fn = resolve_callable(builtins, "pow")
  let operator = ensure_operator_module()
  let add_fn = resolve_callable(operator, "add")
  let mul_fn = resolve_callable(operator, "mul")
  let mut poly = zero
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if coeff == 0 {
      continue
    }
    let mut term = objenum_to_obj(py_call_one(ring_call, py_int_obj(coeff)))
    if i > 0 {
      let power = py_call_two(pow_fn, x_obj, py_int_obj(i))
      term = objenum_to_obj(py_call_two(mul_fn, term, objenum_to_obj(power)))
    }
    poly = objenum_to_obj(py_call_two(add_fn, poly, term))
  }
  (ring_obj, x_obj, y_obj, poly)
}

///|
fn ring_series_unary_prec(
  name : String,
  coeffs : Array[Int],
  prec : Int,
) -> String raise {
  let (_, x_obj, poly) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.\{name}", [
    PyObj(poly),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_mul_ring_series(
  left : Array[Int],
  right : Array[Int],
  prec : Int,
) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(left)
  let (_, _, q) = ring_series_oracle_poly(right)
  let res = sympy_call_must("sympy.polys.ring_series.rs_mul", [
    PyObj(p),
    PyObj(q),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_square_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_square", coeffs, prec)
}

///|
pub fn rs_pow_ring_series(
  coeffs : Array[Int],
  n : Int,
  prec : Int,
) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_pow", [
    PyObj(p),
    Int(n),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_diff_ring_series(coeffs : Array[Int]) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_diff", [
    PyObj(p),
    PyObj(x_obj),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_integrate_ring_series(coeffs : Array[Int]) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_integrate", [
    PyObj(p),
    PyObj(x_obj),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_subs_ring_series(
  coeffs : Array[Int],
  replacement : Array[Int],
  prec : Int,
) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let (_, _, q) = ring_series_oracle_poly(replacement)
  let rules = py_dict_new()
  rules.setByObj(x_obj, q)
  let res = sympy_call_must("sympy.polys.ring_series.rs_subs", [
    PyObj(p),
    PyObj(rules.obj()),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_series_inversion_ring_series(
  coeffs : Array[Int],
  prec : Int,
) -> String raise {
  ring_series_unary_prec("rs_series_inversion", coeffs, prec)
}

///|
pub fn rs_is_puiseux_ring_series(coeffs : Array[Int]) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_is_puiseux", [
    PyObj(p),
    PyObj(x_obj),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_nth_root_ring_series(
  coeffs : Array[Int],
  n : Int,
  prec : Int,
) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_nth_root", [
    PyObj(p),
    Int(n),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_exp_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_exp", coeffs, prec)
}

///|
pub fn rs_log_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_log", coeffs, prec)
}

///|
pub fn rs_sin_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_sin", coeffs, prec)
}

///|
pub fn rs_cos_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_cos", coeffs, prec)
}

///|
pub fn rs_tan_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_tan", coeffs, prec)
}

///|
pub fn rs_sinh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_sinh", coeffs, prec)
}

///|
pub fn rs_cosh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_cosh", coeffs, prec)
}

///|
pub fn rs_tanh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_tanh", coeffs, prec)
}

///|
pub fn rs_atan_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_atan", coeffs, prec)
}

///|
pub fn rs_atanh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_atanh", coeffs, prec)
}

///|
pub fn rs_asin_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_asin", coeffs, prec)
}

///|
pub fn rs_asinh_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_asinh", coeffs, prec)
}

///|
pub fn rs_LambertW_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  ring_series_unary_prec("rs_LambertW", coeffs, prec)
}

///|
fn ring_series_callable_obj(name : String) -> @py.PyObject raise {
  let ring_series_mod = match @py.pyimport("sympy.polys.ring_series") {
    Some(mod) => mod
    None => fail("ring-series-import")
  }
  let callable : @py.PyCallable = match
    ring_series_mod.get_attr(name, print_err=true) {
    Some(PyCallable(callable)) => callable
    Some(other) =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("ring-series-\{name}-callable")
      }
    None => fail("ring-series-\{name}-missing")
  }
  callable.obj()
}

///|
pub fn rs_fun_tan_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let tan_callable = ring_series_callable_obj("rs_tan")
  let res = sympy_call_must("sympy.polys.ring_series.rs_fun", [
    PyObj(p),
    PyObj(tan_callable),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_puiseux_tan_ring_series(
  coeffs : Array[Int],
  prec : Int,
) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let tan_callable = ring_series_callable_obj("rs_tan")
  let res = sympy_call_must("sympy.polys.ring_series.rs_puiseux", [
    PyObj(tan_callable),
    PyObj(p),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_puiseux2_mul_ring_series(
  left : Array[Int],
  right : Array[Int],
  prec : Int,
) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(left)
  let (_, _, q) = ring_series_oracle_poly(right)
  let mul_callable = ring_series_callable_obj("rs_mul")
  let res = sympy_call_must("sympy.polys.ring_series.rs_puiseux2", [
    PyObj(mul_callable),
    PyObj(p),
    PyObj(q),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_series_expr(
  expr : @symcore.Expr,
  sym : String,
  prec : Int,
) -> String raise {
  let res = sympy_call_must("sympy.polys.ring_series.rs_series", [
    PyObj(expr_to_sympy(expr)),
    PyObj(expr_to_sympy(Symbol(sym))),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn series_pprint_oracle(
  coeffs : Array[Int],
  prec : Int,
  sym? : String = "x",
  ascending? : Bool = true,
) -> String raise {
  let kwargs : Map[String, LegacyArg] = Map([])
  kwargs.set("sym", Str(sym))
  kwargs.set("ascending", Bool(ascending))
  let res = sympy_call_must(
    "sympy.polys.series.base.series_pprint",
    [PyObj(py_list_from_ints(coeffs)), Int(prec)],
    kwargs~,
  )
  py_sympy_enum_str(res)
}

///|
pub fn rs_hadamard_exp_ring_series(
  coeffs : Array[Int],
  inverse? : Bool = false,
) -> String raise {
  let (_, _, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_hadamard_exp", [
    PyObj(p),
    Bool(inverse),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_newton_ring_series(coeffs : Array[Int], prec : Int) -> String raise {
  let (_, x_obj, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_newton", [
    PyObj(p),
    PyObj(x_obj),
    Int(prec),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_compose_add_ring_series(
  left : Array[Int],
  right : Array[Int],
) -> String raise {
  let (_, _, p) = ring_series_oracle_poly(left)
  let (_, _, q) = ring_series_oracle_poly(right)
  let res = sympy_call_must("sympy.polys.ring_series.rs_compose_add", [
    PyObj(p),
    PyObj(q),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn rs_series_reversion_ring_series(
  coeffs : Array[Int],
  n : Int,
) -> String raise {
  let (_, x_obj, y_obj, p) = ring_series_xy_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.rs_series_reversion", [
    PyObj(p),
    PyObj(x_obj),
    Int(n),
    PyObj(y_obj),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn mul_xin_ring_series(coeffs : Array[Int], n : Int) -> String raise {
  let (_, _, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.mul_xin", [
    PyObj(p),
    Int(0),
    Int(n),
  ])
  py_sympy_enum_str(res)
}

///|
pub fn pow_xin_ring_series(coeffs : Array[Int], n : Int) -> String raise {
  let (_, _, p) = ring_series_oracle_poly(coeffs)
  let res = sympy_call_must("sympy.polys.ring_series.pow_xin", [
    PyObj(p),
    Int(0),
    Int(n),
  ])
  py_sympy_enum_str(res)
}
