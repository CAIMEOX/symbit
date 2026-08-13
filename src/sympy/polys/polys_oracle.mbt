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
  let recipe = LinSolveRecipe::new()
  let rows = recipe.sympified_rows(eqs_coeffs)
  let rhs = recipe.expressions(eqs_rhs)
  let symbols = recipe.string_list(syms)
  let matrix = recipe.call_linsolve("sympy_dict_to_dm", [
    Ref(rows),
    Ref(rhs),
    Ref(symbols),
  ])
  recipe.request_str(recipe.render(recipe.dense_renderer, matrix))
}

///|
pub fn solvers_eqs_to_matrix_summary(
  eqs_coeffs : Array[Map[String, String]],
  eqs_rhs : Array[String],
  syms : Array[String],
  domain_spec : String,
) -> String raise {
  let recipe = LinSolveRecipe::new()
  let domain = recipe.domain_recipe.domain(domain_spec)
  let convert = recipe.domain_recipe.builder.getattr(domain, "convert")
  let (symbols, symbol_lookup) = recipe.symbols(syms)
  let rows = recipe.converted_rows(eqs_coeffs, symbol_lookup, convert)
  let rhs = recipe.converted_values(eqs_rhs, convert)
  let matrix = recipe.call_solvers("eqs_to_matrix", [
    Ref(rows),
    Ref(rhs),
    Ref(symbols),
    Ref(domain),
  ])
  recipe.request_str(recipe.render(recipe.matrix_renderer, matrix))
}

///|
pub fn solvers_sympy_eqs_to_ring_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let recipe = LinSolveRecipe::new()
  let equations = recipe.expressions(eqs)
  let (symbols, _) = recipe.symbols(syms)
  let result = recipe.call_solvers("sympy_eqs_to_ring", [
    Ref(equations),
    Ref(symbols),
  ])
  recipe.request_str(recipe.render(recipe.ring_renderer, result))
}

///|
pub fn linsolve_linear_eq_to_dict_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let recipe = LinSolveRecipe::new()
  let equations = recipe.expressions(eqs)
  let (symbols, _) = recipe.symbols(syms)
  let result = recipe.call_linsolve("_linear_eq_to_dict", [
    Ref(equations),
    Ref(symbols),
  ])
  recipe.request_str(
    recipe.render(recipe.linear_dict_renderer, result, syms~, with_syms=true),
  )
}

///|
pub fn linsolve_internal_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let recipe = LinSolveRecipe::new()
  let equations = recipe.expressions(eqs)
  let (symbols, _) = recipe.symbols(syms)
  let result = recipe.call_linsolve(
    "_linsolve",
    [Ref(equations), Ref(symbols)],
    allow_none=true,
  )
  recipe.request_str(
    recipe.render(recipe.internal_renderer, result, syms~, with_syms=true),
  )
}

///|
pub fn solvers_solve_lin_sys_summary(
  eqs : Array[String],
  syms : Array[String],
) -> String raise {
  let recipe = LinSolveRecipe::new()
  let equations = recipe.expressions(eqs)
  let (symbols, _) = recipe.symbols(syms)
  let prepared = recipe.call_solvers("sympy_eqs_to_ring", [
    Ref(equations),
    Ref(symbols),
  ])
  let pair = recipe.require_pair(prepared, "solvers-solve-lin-sys-prepared")
  let ring_equations = recipe.domain_recipe.builder.getitem(
    pair,
    DecimalInt("0"),
  )
  let ring = recipe.domain_recipe.builder.getitem(pair, DecimalInt("1"))
  let result = recipe.call_solvers(
    "solve_lin_sys",
    [Ref(ring_equations), Ref(ring)],
    kwargs={ "_raw": Bool(false) },
    allow_none=true,
  )
  recipe.request_str(
    recipe.render(recipe.solve_renderer, result, syms~, with_syms=true),
  )
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
pub fn sdm_transpose_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = MatrixSdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let (matrix, row_count, column_count) = recipe.sdm(rows, domain)
  let raw = recipe.call_path("sympy.polys.matrices.sdm.sdm_transpose", [
    Ref(matrix),
  ])
  let result = recipe.sdm_from_raw(raw, column_count, row_count, domain)
  recipe.request_str(recipe.render_dense_summary(result, domain_spec))
}

///|
pub fn sdm_matmul_summary(
  a_rows : Array[Array[Int]],
  b_rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = MatrixSdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let (left, row_count, _) = recipe.sdm(a_rows, domain)
  let (right, _, column_count) = recipe.sdm(b_rows, domain)
  let raw = recipe.call_path("sympy.polys.matrices.sdm.sdm_matmul", [
    Ref(left),
    Ref(right),
    Ref(domain),
    DecimalInt(Show::to_string(row_count)),
    DecimalInt(Show::to_string(column_count)),
  ])
  let result = recipe.sdm_from_raw(raw, row_count, column_count, domain)
  recipe.request_str(recipe.render_dense_summary(result, domain_spec))
}

///|
pub fn sdm_rref_den_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = MatrixSdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let (matrix, _, _) = recipe.sdm(rows, domain)
  let result = recipe.call_path("sympy.polys.matrices.sdm.sdm_rref_den", [
    Ref(matrix),
    Ref(domain),
  ])
  recipe.request_str(recipe.render_compact(result))
}

///|
pub fn sdm_berk_summary(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = MatrixSdmRecipe::new()
  let domain = recipe.domain(domain_spec)
  let (matrix, row_count, _) = recipe.sdm(rows, domain)
  let result = recipe.call_path("sympy.polys.matrices.sdm.sdm_berk", [
    Ref(matrix),
    DecimalInt(Show::to_string(row_count)),
    Ref(domain),
  ])
  recipe.request_str(recipe.render_compact(result))
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
fn sympy_domain_obj(name : String) -> @py.PyObject raise {
  let sympy = ensure_sympy_module_oracle()
  match sympy.get_attr(name, print_err=false) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-domain-missing:\{name}")
  }
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
pub fn sdm_monomial_mul(m : Array[Int], x : Array[Int]) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let result = recipe.call("sdm_monomial_mul", [
    Ref(recipe.monomial(m)),
    Ref(recipe.monomial(x)),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_monomial_deg(m : Array[Int]) -> Int raise {
  let recipe = DistributedSdmRecipe::new()
  let result = recipe.call("sdm_monomial_deg", [Ref(recipe.monomial(m))])
  recipe.request_int(result)
}

///|
pub fn sdm_monomial_lcm(a : Array[Int], b : Array[Int]) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let result = recipe.call("sdm_monomial_lcm", [
    Ref(recipe.monomial(a)),
    Ref(recipe.monomial(b)),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_monomial_divides(a : Array[Int], b : Array[Int]) -> Bool raise {
  let recipe = DistributedSdmRecipe::new()
  let result = recipe.call("sdm_monomial_divides", [
    Ref(recipe.monomial(a)),
    Ref(recipe.monomial(b)),
  ])
  recipe.request_bool(result)
}

///|
pub fn sdm_LC(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_LC", [
    Ref(recipe.terms(f, domain_value)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_LM(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_LM", [Ref(recipe.terms(f, domain_value))])
  recipe.request_compact(result)
}

///|
pub fn sdm_LT(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_LT", [Ref(recipe.terms(f, domain_value))])
  recipe.request_compact(result)
}

///|
pub fn sdm_to_dict(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_to_dict", [Ref(recipe.terms(f, domain_value))])
  recipe.request_compact(result)
}

///|
pub fn sdm_strip(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_strip", [Ref(recipe.terms(f, domain_value))])
  recipe.request_compact(result)
}

///|
pub fn sdm_sort(
  f : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_sort", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.order(order)),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_from_dict(
  f : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_from_dict", [
    Ref(recipe.term_dict(f, domain_value)),
    Ref(recipe.order(order)),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_from_vector(
  exprs : Array[String],
  gens : Array[String],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  kwargs["gens"] = Ref(recipe.symbols(gens))
  let result = recipe.call(
    "sdm_from_vector",
    [
      Ref(recipe.expressions(exprs)),
      Ref(recipe.order(order)),
      Ref(domain_value),
    ],
    kwargs~,
  )
  recipe.request_compact(result)
}

///|
pub fn sdm_to_vector(
  f : Array[(Array[Int], Int)],
  gens : Array[String],
  n? : Int = 0,
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let args : Array[@recipe.RecipeArg] = [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.symbols(gens)),
    Ref(domain_value),
  ]
  if n != 0 {
    args.push(DecimalInt(Show::to_string(n)))
  }
  let result = recipe.call("sdm_to_vector", args)
  recipe.request_compact(result)
}

///|
pub fn sdm_add(
  f : Array[(Array[Int], Int)],
  g : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_add", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.terms(g, domain_value)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_zero() -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let result = recipe.call("sdm_zero", [])
  recipe.request_compact(result)
}

///|
pub fn sdm_mul_term(
  f : Array[(Array[Int], Int)],
  monom : Array[Int],
  coeff : Int,
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_mul_term", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.term((monom, coeff), domain_value)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_spoly(
  f : Array[(Array[Int], Int)],
  g : Array[(Array[Int], Int)],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_spoly", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.terms(g, domain_value)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_nf_mora(
  f : Array[(Array[Int], Int)],
  basis : Array[Array[(Array[Int], Int)]],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_nf_mora", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.basis(basis, domain_value)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_nf_buchberger(
  f : Array[(Array[Int], Int)],
  basis : Array[Array[(Array[Int], Int)]],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_nf_buchberger", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.basis(basis, domain_value)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_nf_buchberger_reduced(
  f : Array[(Array[Int], Int)],
  basis : Array[Array[(Array[Int], Int)]],
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_nf_buchberger_reduced", [
    Ref(recipe.terms(f, domain_value)),
    Ref(recipe.basis(basis, domain_value)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_groebner(
  generators : Array[Array[(Array[Int], Int)]],
  normal_form? : String = "mora",
  order? : String = "lex",
  domain? : String = "QQ",
) -> String raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_groebner", [
    Ref(recipe.basis(generators, domain_value)),
    Ref(recipe.normal_form(normal_form)),
    Ref(recipe.order(order)),
    Ref(domain_value),
  ])
  recipe.request_compact(result)
}

///|
pub fn sdm_deg(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> Int raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_deg", [Ref(recipe.terms(f, domain_value))])
  recipe.request_int(result)
}

///|
pub fn sdm_ecart(
  f : Array[(Array[Int], Int)],
  domain? : String = "QQ",
) -> Int raise {
  let recipe = DistributedSdmRecipe::new()
  let domain_value = recipe.domain(domain)
  let result = recipe.call("sdm_ecart", [Ref(recipe.terms(f, domain_value))])
  recipe.request_int(result)
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
  galois_recipe_string_call("gf_strip", [CallIntList(f)])
}

///|
pub fn gf_trunc(f : Array[Int], p : Int) -> String raise {
  galois_recipe_string_call("gf_trunc", [CallIntList(f), CallInt(p)])
}

///|
fn gf_zz_call(name : String, args : Array[DenseCallArg]) -> String raise {
  galois_recipe_string_call(name, args)
}

///|
fn gf_zz_unary(name : String, f : Array[Int], p : Int) -> String raise {
  gf_zz_call(name, [CallIntList(f), CallInt(p), DomainObject])
}

///|
pub fn gf_int(a : Int, p : Int) -> Int raise {
  galois_recipe_int_call("gf_int", [CallInt(a), CallInt(p)])
}

///|
pub fn gf_normal(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_normal", f, p)
}

///|
pub fn gf_from_dict(values : Map[Int, Int], p : Int) -> String raise {
  gf_zz_call("gf_from_dict", [CallIntDict(values), CallInt(p), DomainObject])
}

///|
pub fn gf_to_dict(
  f : Array[Int],
  p : Int,
  symmetric? : Bool = true,
) -> String raise {
  galois_recipe_string_call(
    "gf_to_dict",
    [CallIntList(f), CallInt(p), CallBool(symmetric)],
    raw=true,
  )
}

///|
pub fn gf_from_int_poly(f : Array[Int], p : Int) -> String raise {
  galois_recipe_string_call("gf_from_int_poly", [CallIntList(f), CallInt(p)])
}

///|
pub fn gf_to_int_poly(
  f : Array[Int],
  p : Int,
  symmetric? : Bool = true,
) -> String raise {
  galois_recipe_string_call("gf_to_int_poly", [
    CallIntList(f),
    CallInt(p),
    CallBool(symmetric),
  ])
}

///|
pub fn gf_neg(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_neg", f, p)
}

///|
pub fn gf_add_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_add_ground", [
    CallIntList(f),
    CallInt(a),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_sub_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_sub_ground", [
    CallIntList(f),
    CallInt(a),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_mul_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_mul_ground", [
    CallIntList(f),
    CallInt(a),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_quo_ground(f : Array[Int], a : Int, p : Int) -> String raise {
  gf_zz_call("gf_quo_ground", [
    CallIntList(f),
    CallInt(a),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_add(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_add", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_sub(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_sub", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_mul(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_mul", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
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
    CallIntList(f),
    CallIntList(g),
    CallIntList(h),
    CallInt(p),
    DomainObject,
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
    CallIntList(f),
    CallIntList(g),
    CallIntList(h),
    CallInt(p),
    DomainObject,
  ])
}

///|
fn gf_bool_call(name : String, args : Array[DenseCallArg]) -> Bool raise {
  galois_recipe_bool_call(name, args)
}

///|
pub fn gf_expand(
  factors : Array[(Array[Int], Int)],
  p : Int,
  lc? : Int = 1,
) -> String raise {
  gf_zz_call("gf_expand", [
    FactorPowersWithLeadingCoefficient(factors, lc),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_div(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_div", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_exquo(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_exquo", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_lshift(f : Array[Int], n : Int) -> String raise {
  gf_zz_call("gf_lshift", [CallIntList(f), CallInt(n), DomainObject])
}

///|
pub fn gf_rshift(f : Array[Int], n : Int) -> String raise {
  gf_zz_call("gf_rshift", [CallIntList(f), CallInt(n), DomainObject])
}

///|
pub fn gf_pow(f : Array[Int], n : Int, p : Int) -> String raise {
  gf_zz_call("gf_pow", [CallIntList(f), CallInt(n), CallInt(p), DomainObject])
}

///|
pub fn gf_pow_mod(
  f : Array[Int],
  n : Int,
  g : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_pow_mod", [
    CallIntList(f),
    CallInt(n),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_diff(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_diff", f, p)
}

///|
pub fn gf_eval(f : Array[Int], a : Int, p : Int) -> Int raise {
  galois_recipe_int_call("gf_eval", [
    CallIntList(f),
    CallInt(a),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_multi_eval(
  f : Array[Int],
  values : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_multi_eval", [
    CallIntList(f),
    CallIntList(values),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_compose(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_compose", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_compose_mod(
  g : Array[Int],
  h : Array[Int],
  f : Array[Int],
  p : Int,
) -> String raise {
  gf_zz_call("gf_compose_mod", [
    CallIntList(g),
    CallIntList(h),
    CallIntList(f),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_frobenius_monomial_base(g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_frobenius_monomial_base", [
    CallIntList(g),
    CallInt(p),
    DomainObject,
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
    CallIntList(f),
    CallIntList(g),
    CallIntMatrix(b),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_gcd(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_gcd", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_lcm(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_lcm", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_cofactors(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_cofactors", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_gcdex(f : Array[Int], g : Array[Int], p : Int) -> String raise {
  gf_zz_call("gf_gcdex", [
    CallIntList(f),
    CallIntList(g),
    CallInt(p),
    DomainObject,
  ])
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
    CallIntList(a),
    CallIntList(b),
    CallIntList(c),
    CallInt(n),
    CallIntList(f),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_irred_p_ben_or(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_irred_p_ben_or", [CallIntList(f), CallInt(p), DomainObject])
}

///|
pub fn gf_irred_p_rabin(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_irred_p_rabin", [CallIntList(f), CallInt(p), DomainObject])
}

///|
pub fn gf_irreducible_p(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_irreducible_p", [CallIntList(f), CallInt(p), DomainObject])
}

///|
pub fn gf_sqf_p(f : Array[Int], p : Int) -> Bool raise {
  gf_bool_call("gf_sqf_p", [CallIntList(f), CallInt(p), DomainObject])
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
  gf_zz_call("gf_Qbasis", [CallIntMatrix(q), CallInt(p), DomainObject])
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
    CallIntList(f),
    CallInt(n),
    CallInt(p),
    DomainObject,
  ])
}

///|
pub fn gf_ddf_shoup(f : Array[Int], p : Int) -> String raise {
  gf_zz_unary("gf_ddf_shoup", f, p)
}

///|
pub fn gf_edf_shoup(f : Array[Int], n : Int, p : Int) -> String raise {
  gf_zz_call("gf_edf_shoup", [
    CallIntList(f),
    CallInt(n),
    CallInt(p),
    DomainObject,
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
  galois_recipe_int_call("gf_crt", [
    CallIntList(u),
    CallIntList(m),
    DomainObject,
  ])
}

///|
pub fn gf_crt1(m : Array[Int]) -> String raise {
  gf_zz_call("gf_crt1", [CallIntList(m), DomainObject])
}

///|
pub fn gf_crt2(
  u : Array[Int],
  m : Array[Int],
  p : Int,
  e : Array[Int],
  s : Array[Int],
) -> Int raise {
  galois_recipe_int_call("gf_crt2", [
    CallIntList(u),
    CallIntList(m),
    CallInt(p),
    CallIntList(e),
    CallIntList(s),
    DomainObject,
  ])
}

///|
pub fn gf_value(f : Array[Int], a : Int) -> Int raise {
  galois_recipe_int_call("gf_value", [CallIntList(f), CallInt(a)])
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
  galois_recipe_string_call("gf_csolve", [CallIntList(f), CallInt(n)])
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
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_cauchy_upper_bound",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_cauchy_lower_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_cauchy_lower_bound",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_mignotte_sep_bound_squared",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_sturm(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_sturm",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_root_upper_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_root_upper_bound",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_root_lower_bound(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_root_lower_bound",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
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
  let kwargs : Map[String, DenseCallArg] = Map([])
  match steps {
    Some(k) => kwargs["steps"] = CallInt(k)
    None => ()
  }
  match eps {
    Some(e) => kwargs["eps"] = DomainNumber(e)
    None => ()
  }
  match disjoint {
    Some(d) => kwargs["disjoint"] = DomainNumber(d)
    None => ()
  }
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_refine_real_root",
    [DupCoeffs(coeffs), DomainNumber(s), DomainNumber(t), DomainObject],
    domain,
    kwargs~,
  )
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
  let kwargs : Map[String, DenseCallArg] = Map([])
  match steps {
    Some(k) => kwargs["steps"] = CallInt(k)
    None => ()
  }
  match eps {
    Some(e) => kwargs["eps"] = DomainNumber(e)
    None => ()
  }
  match disjoint {
    Some(d) => kwargs["disjoint"] = DomainNumber(d)
    None => ()
  }
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_outer_refine_real_root",
    [DupCoeffs(coeffs), DomainNumber(s), DomainNumber(t), DomainObject],
    domain,
    kwargs~,
  )
}

///|
pub fn dup_isolate_real_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_isolate_real_roots_sqf",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_inner_isolate_real_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_inner_isolate_real_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_inner_isolate_positive_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_inner_isolate_positive_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_inner_isolate_negative_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_inner_isolate_negative_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_isolate_real_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_isolate_real_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_count_real_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
  inf? : @symnum.BigRational,
  sup? : @symnum.BigRational,
) -> String raise {
  let kwargs : Map[String, DenseCallArg] = Map([])
  match inf {
    Some(v) => kwargs["inf"] = DomainNumber(v)
    None => ()
  }
  match sup {
    Some(v) => kwargs["sup"] = DomainNumber(v)
    None => ()
  }
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_count_real_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
    kwargs~,
    result_kind=ScalarResult,
  )
}

///|
pub fn dup_count_complex_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_count_complex_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
    result_kind=ScalarResult,
  )
}

///|
pub fn dup_isolate_complex_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_isolate_complex_roots_sqf",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_isolate_all_roots_sqf(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_isolate_all_roots_sqf",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn dup_isolate_all_roots(
  coeffs : Array[@symnum.BigRational],
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "rootisolation",
    "dup_isolate_all_roots",
    [DupCoeffs(coeffs), DomainObject],
    domain,
  )
}

///|
pub fn res_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_poly_call("res", p, q, x)
}

///|
pub fn res_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_poly_call("res_q", p, q, x)
}

///|
pub fn res_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_poly_call("res_z", p, q, x)
}

///|
pub fn subresultants_rem_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_rem", p, q, x)
}

///|
pub fn subresultants_sylv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_sylv", p, q, x)
}

///|
pub fn subresultants_bezout_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_bezout", p, q, x)
}

///|
pub fn subresultants_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_amv", p, q, x)
}

///|
pub fn subresultants_amv_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_amv_q", p, q, x)
}

///|
pub fn subresultants_vv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_vv", p, q, x)
}

///|
pub fn subresultants_vv_2_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("subresultants_vv_2", p, q, x)
}

///|
pub fn modified_subresultants_sylv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("modified_subresultants_sylv", p, q, x)
}

///|
pub fn modified_subresultants_bezout_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("modified_subresultants_bezout", p, q, x)
}

///|
pub fn modified_subresultants_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("modified_subresultants_amv", p, q, x)
}

///|
pub fn euclid_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("euclid_q", p, q, x)
}

///|
pub fn euclid_pg_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("euclid_pg", p, q, x)
}

///|
pub fn euclid_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("euclid_amv", p, q, x)
}

///|
pub fn sturm_q_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("sturm_q", p, q, x)
}

///|
pub fn sturm_pg_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("sturm_pg", p, q, x)
}

///|
pub fn sturm_amv_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_sequence_call("sturm_amv", p, q, x)
}

///|
pub fn sign_seq_qq_zz(
  polys : Array[@symcore.Expr],
  x? : String = "x",
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let expressions = recipe.polys.expression_list(polys)
  let generator = recipe.polys.literal_symbol(x)
  let result = recipe.call("sign_seq", [Ref(expressions), Ref(generator)])
  recipe.request_sequence(result, false)
}

///|
pub fn process_matrix_output_qq_zz(
  polys : Array[@symcore.Expr],
  x? : String = "x",
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let expressions = recipe.polys.expression_list(polys)
  let generator = recipe.polys.literal_symbol(x)
  let result = recipe.call("process_matrix_output", [
    Ref(expressions),
    Ref(generator),
  ])
  recipe.request_sequence(result, true)
}

///|
pub fn compute_sign_qq_zz(base : Int, expo : Int) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let result = recipe.call("compute_sign", [
    DecimalInt(Show::to_string(base)),
    DecimalInt(Show::to_string(expo)),
  ])
  recipe.request_raw(result)
}

///|
pub fn backward_eye_qq_zz(n : Int) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let result = recipe.call("backward_eye", [DecimalInt(Show::to_string(n))])
  recipe.request_raw(result)
}

///|
pub fn sylvester_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
  kind? : Int = 1,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let (left, right, generator) = recipe.pair(p, q, x)
  let result = recipe.call("sylvester", [
    Ref(left),
    Ref(right),
    Ref(generator),
    DecimalInt(Show::to_string(kind)),
  ])
  recipe.request_raw(result)
}

///|
pub fn correct_sign_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
  rdel? : Int = 1,
  cdel? : Int = 0,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let (left, right, generator) = recipe.pair(p, q, x)
  let sylvester = recipe.call("sylvester", [
    Ref(left),
    Ref(right),
    Ref(generator),
    DecimalInt("1"),
  ])
  let degree = recipe_sympy_callable(
    recipe.polys.builder,
    "sympy.polys.polytools.degree",
  )
  let deg_f = recipe.polys.builder.require_non_none(
    recipe.polys.builder.call(degree, [Ref(left), Ref(generator)]),
    message="sympy-call-none:sympy.polys.polytools.degree",
  )
  let deg_g = recipe.polys.builder.require_non_none(
    recipe.polys.builder.call(degree, [Ref(right), Ref(generator)]),
    message="sympy-call-none:sympy.polys.polytools.degree",
  )
  let result = recipe.call("correct_sign", [
    Ref(deg_f),
    Ref(deg_g),
    Ref(sylvester),
    DecimalInt(Show::to_string(rdel)),
    DecimalInt(Show::to_string(cdel)),
  ])
  recipe.request_raw(result)
}

///|
pub fn create_ma_qq_zz(
  deg_f : Int,
  deg_g : Int,
  row1 : Array[Int],
  row2 : Array[Int],
  col_num : Int,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let first_row = recipe.row_matrix(row1)
  let second_row = recipe.row_matrix(row2)
  let result = recipe.call("create_ma", [
    DecimalInt(Show::to_string(deg_f)),
    DecimalInt(Show::to_string(deg_g)),
    Ref(first_row),
    Ref(second_row),
    DecimalInt(Show::to_string(col_num)),
  ])
  recipe.request_raw(result)
}

///|
pub fn rotate_r_qq_zz(row : Array[Int], k : Int) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let values = recipe.int_list(row)
  let result = recipe.call("rotate_r", [
    Ref(values),
    DecimalInt(Show::to_string(k)),
  ])
  recipe.request_raw(result)
}

///|
pub fn rotate_l_qq_zz(row : Array[Int], k : Int) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let values = recipe.int_list(row)
  let result = recipe.call("rotate_l", [
    Ref(values),
    DecimalInt(Show::to_string(k)),
  ])
  recipe.request_raw(result)
}

///|
pub fn row2poly_qq_zz(
  row : Array[Int],
  deg : Int,
  x? : String = "x",
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let values = recipe.int_list(row)
  let generator = recipe.polys.literal_symbol(x)
  let result = recipe.call("row2poly", [
    Ref(values),
    DecimalInt(Show::to_string(deg)),
    Ref(generator),
  ])
  let as_expr = recipe.polys.builder.getattr(result, "as_expr")
  let expression = recipe.polys.builder.require_non_none(
    recipe.polys.builder.call(as_expr, []),
    message="sympy-call-none:row2poly.as_expr",
  )
  recipe.request_raw(expression)
}

///|
pub fn pivot_qq_zz(
  matrix : Array[Array[Int]],
  i : Int,
  j : Int,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let matrix_value = recipe.matrix(matrix)
  let result = recipe.call("pivot", [
    Ref(matrix_value),
    DecimalInt(Show::to_string(i)),
    DecimalInt(Show::to_string(j)),
  ])
  recipe.request_raw(result)
}

///|
pub fn find_degree_qq_zz(
  matrix : Array[Array[Int]],
  deg_f : Int,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let matrix_value = recipe.matrix(matrix)
  let result = recipe.call("find_degree", [
    Ref(matrix_value),
    DecimalInt(Show::to_string(deg_f)),
  ])
  recipe.request_raw(result)
}

///|
pub fn final_touches_qq_zz(
  matrix : Array[Array[Int]],
  r : Int,
  deg_g : Int,
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let matrix_value = recipe.matrix(matrix)
  let result = recipe.call("final_touches", [
    Ref(matrix_value),
    DecimalInt(Show::to_string(r)),
    DecimalInt(Show::to_string(deg_g)),
  ])
  recipe.request_raw(result)
}

///|
pub fn bezout_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
  kind? : String = "bz",
) -> String raise {
  let recipe = SubresultantsRecipe::new()
  let (left, right, generator) = recipe.pair(p, q, x)
  let result = recipe.call("bezout", [
    Ref(left),
    Ref(right),
    Ref(generator),
    Str(kind),
  ])
  recipe.request_raw(result)
}

///|
pub fn rem_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_poly_call("rem_z", p, q, x)
}

///|
pub fn quo_z_qq_zz(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "x",
) -> String raise {
  subresultants_pair_poly_call("quo_z", p, q, x)
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
  function_name : String,
  n : Int,
  domain : String,
) -> String raise {
  polys_prefix_recipe_call(
    "specialpolys",
    function_name,
    [CallInt(n), DomainObject],
    domain,
  )
}

///|
pub fn dmp_fateman_poly_F_1(n : Int, domain? : String = "ZZ") -> String raise {
  dmp_fateman_poly_tuple("dmp_fateman_poly_F_1", n, domain)
}

///|
pub fn dmp_fateman_poly_F_2(n : Int, domain? : String = "ZZ") -> String raise {
  dmp_fateman_poly_tuple("dmp_fateman_poly_F_2", n, domain)
}

///|
pub fn dmp_fateman_poly_F_3(n : Int, domain? : String = "ZZ") -> String raise {
  dmp_fateman_poly_tuple("dmp_fateman_poly_F_3", n, domain)
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
fn orth_dup_unary(
  module_name : String,
  function_name : String,
  n : Int,
  domain : String,
) -> String raise {
  polys_prefix_recipe_call(
    module_name,
    function_name,
    [CallInt(n), DomainObject],
    domain,
  )
}

///|
fn orth_dup_param(
  module_name : String,
  function_name : String,
  n : Int,
  param : @symnum.BigRational,
  domain : String,
) -> String raise {
  polys_prefix_recipe_call(
    module_name,
    function_name,
    [CallInt(n), DomainNumber(param), DomainObject],
    domain,
  )
}

///|
pub fn dup_jacobi(
  n : Int,
  a : @symnum.BigRational,
  b : @symnum.BigRational,
  domain? : String = "QQ",
) -> String raise {
  polys_prefix_recipe_call(
    "orthopolys",
    "dup_jacobi",
    [CallInt(n), DomainNumber(a), DomainNumber(b), DomainObject],
    domain,
  )
}

///|
pub fn dup_gegenbauer(
  n : Int,
  a : @symnum.BigRational,
  domain? : String = "QQ",
) -> String raise {
  orth_dup_param("orthopolys", "dup_gegenbauer", n, a, domain)
}

///|
pub fn dup_chebyshevt(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("orthopolys", "dup_chebyshevt", n, domain)
}

///|
pub fn dup_chebyshevu(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("orthopolys", "dup_chebyshevu", n, domain)
}

///|
pub fn dup_hermite(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("orthopolys", "dup_hermite", n, domain)
}

///|
pub fn dup_hermite_prob(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("orthopolys", "dup_hermite_prob", n, domain)
}

///|
pub fn dup_legendre(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("orthopolys", "dup_legendre", n, domain)
}

///|
pub fn dup_laguerre(
  n : Int,
  alpha : @symnum.BigRational,
  domain? : String = "QQ",
) -> String raise {
  orth_dup_param("orthopolys", "dup_laguerre", n, alpha, domain)
}

///|
pub fn dup_spherical_bessel_fn(
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  orth_dup_unary("orthopolys", "dup_spherical_bessel_fn", n, domain)
}

///|
pub fn dup_spherical_bessel_fn_minus(
  n : Int,
  domain? : String = "ZZ",
) -> String raise {
  orth_dup_unary("orthopolys", "dup_spherical_bessel_fn_minus", n, domain)
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
  orth_dup_unary("appellseqs", "dup_bernoulli", n, domain)
}

///|
pub fn dup_bernoulli_c(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("appellseqs", "dup_bernoulli_c", n, domain)
}

///|
pub fn dup_genocchi(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("appellseqs", "dup_genocchi", n, domain)
}

///|
pub fn dup_euler(n : Int, domain? : String = "QQ") -> String raise {
  orth_dup_unary("appellseqs", "dup_euler", n, domain)
}

///|
pub fn dup_andre(n : Int, domain? : String = "ZZ") -> String raise {
  orth_dup_unary("appellseqs", "dup_andre", n, domain)
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
