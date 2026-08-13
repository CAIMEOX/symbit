///|
fn domain_foundation_source() -> String {
  (
    #|import importlib as _symbit_importlib
    #|
    #|_symbit_domains = _symbit_importlib.import_module("sympy.polys.domains")
    #|_symbit_sentinel = object()
    #|_symbit_none_sentinel = object()
    #|def _symbit_split_names(text):
    #|    raw = text.strip()
    #|    if not raw:
    #|        return []
    #|    return [name.strip() for name in raw.split(',')]
    #|
    #|def _symbit_matching_open(text, opening, closing):
    #|    if not text.endswith(closing):
    #|        raise ValueError("domain spec has an unmatched suffix")
    #|    depth = 0
    #|    for index in range(len(text) - 1, -1, -1):
    #|        char = text[index]
    #|        if char == closing:
    #|            depth += 1
    #|        elif char == opening:
    #|            depth -= 1
    #|            if depth == 0:
    #|                return index
    #|    raise ValueError("domain spec has an unmatched suffix")
    #|
    #|def _symbit_literal_symbols(text):
    #|    return tuple(sympy.Symbol(name) for name in _symbit_split_names(text))
    #|
    #|def _symbit_domain_generators(text):
    #|    return tuple(sympy.sympify(item) for item in _symbit_split_names(text))
    #|
    #|def _symbit_int_pow(base, exp):
    #|    result = 1
    #|    current = base
    #|    remaining = exp
    #|    while remaining > 0:
    #|        if remaining % 2 == 1:
    #|            result *= current
    #|        remaining //= 2
    #|        if remaining > 0:
    #|            current *= current
    #|    return result
    #|
    #|def _symbit_domain_spec(spec):
    #|    text = spec.strip()
    #|    if not text:
    #|        raise ValueError("empty domain spec")
    #|    if text.startswith(("GF(", "FF(", "FiniteField(")) and text.endswith(")"):
    #|        left = text.index('(')
    #|        body = text[left + 1:-1].strip()
    #|        if '**' in body:
    #|            parts = [part.strip() for part in body.split('**')]
    #|        elif ',' in body:
    #|            parts = [part.strip() for part in body.split(',')]
    #|        else:
    #|            parts = [body]
    #|        if len(parts) == 1:
    #|            order = int(parts[0], 10)
    #|        elif len(parts) == 2:
    #|            order = _symbit_int_pow(int(parts[0], 10), int(parts[1], 10))
    #|        else:
    #|            raise ValueError("invalid finite-field domain spec")
    #|        return _symbit_domains.GF(order)
    #|    if '<' in text and text.endswith('>'):
    #|        left = _symbit_matching_open(text, '<', '>')
    #|        base = _symbit_domain_spec(text[:left])
    #|        extensions = tuple(
    #|            sympy.sympify(item)
    #|            for item in _symbit_split_names(text[left + 1:-1])
    #|        )
    #|        return base.algebraic_field(*extensions)
    #|    for marker, method in (
    #|        ('.old_poly_ring(', 'old_poly_ring'),
    #|        ('.old_frac_field(', 'old_frac_field'),
    #|    ):
    #|        if marker in text and text.endswith(')'):
    #|            left = text.find(marker)
    #|            base = _symbit_domain_spec(text[:left])
    #|            generators = _symbit_domain_generators(text[left + len(marker):-1])
    #|            return getattr(base, method)(*generators)
    #|    if text.endswith(']') and not text.endswith(']]'):
    #|        left = _symbit_matching_open(text, '[', ']')
    #|        base = _symbit_domain_spec(text[:left])
    #|        return base.poly_ring(*_symbit_domain_generators(text[left + 1:-1]))
    #|    if text.endswith(')'):
    #|        left = _symbit_matching_open(text, '(', ')')
    #|        base = _symbit_domain_spec(text[:left])
    #|        return base.frac_field(*_symbit_domain_generators(text[left + 1:-1]))
    #|    return getattr(_symbit_domains, text)
    #|
    #|def _symbit_attr_is_true(value):
    #|    return str(value).strip() == "True"
    #|
    #|def _symbit_try_method(object_value, method_name, args, failure):
    #|    callable_value = getattr(object_value, method_name)
    #|    if any(arg is _symbit_sentinel for arg in args):
    #|        return _symbit_sentinel
    #|    try:
    #|        value = callable_value(*args)
    #|    except Exception:
    #|        return failure
    #|    if value is None:
    #|        return failure
    #|    return value
    #|
    #|def _symbit_contains(object_value, expression):
    #|    if expression is _symbit_sentinel:
    #|        return False
    #|    value = _symbit_try_method(
    #|        object_value, "__contains__", (expression,), _symbit_sentinel
    #|    )
    #|    if value is _symbit_sentinel:
    #|        return False
    #|    return str(value).strip() == "True"
    #|
    #|def _symbit_optional_hook(object_value, method_name, element, base):
    #|    if element is _symbit_sentinel:
    #|        return _symbit_sentinel
    #|    return _symbit_try_method(
    #|        object_value,
    #|        method_name,
    #|        (element, base),
    #|        _symbit_none_sentinel,
    #|    )
    #|
    #|def _symbit_sum(object_value, elements):
    #|    if any(element is _symbit_sentinel for element in elements):
    #|        return _symbit_sentinel
    #|    return _symbit_try_method(
    #|        object_value, "sum", (elements,), _symbit_sentinel
    #|    )
    #|
    #|def _symbit_try_attr(object_value, attr_name):
    #|    try:
    #|        value = getattr(object_value, attr_name)
    #|    except Exception:
    #|        return _symbit_sentinel
    #|    if value is None:
    #|        return _symbit_sentinel
    #|    return value
    #|
    #|def _symbit_domain_value_text(object_value, value):
    #|    rendered = _symbit_try_method(
    #|        object_value, "to_sympy", (value,), _symbit_sentinel
    #|    )
    #|    if rendered is _symbit_sentinel:
    #|        rendered = value
    #|    return str(rendered)
    #|
    #|def _symbit_render_domain_result(object_value, value):
    #|    if value is _symbit_sentinel:
    #|        return "ERROR"
    #|    if value is _symbit_none_sentinel:
    #|        return "NONE"
    #|    return _symbit_domain_value_text(object_value, value)
    #|
    #|def _symbit_render_tuple_result(
    #|    object_value, value, indexes, required_length, exact, tuple_only
    #|):
    #|    if value is _symbit_sentinel or value is _symbit_none_sentinel:
    #|        return "ERROR"
    #|    allowed = isinstance(value, tuple) if tuple_only else isinstance(value, (list, tuple))
    #|    if not allowed:
    #|        return "ERROR"
    #|    if exact:
    #|        if len(value) != required_length:
    #|            return "ERROR"
    #|    elif len(value) < required_length:
    #|        return "ERROR"
    #|    return "(" + ",".join(
    #|        _symbit_domain_value_text(object_value, value[index])
    #|        for index in indexes
    #|    ) + ")"
    #|
    #|def _symbit_half_gcdex(object_value, left, right):
    #|    if left is _symbit_sentinel or right is _symbit_sentinel:
    #|        return "ERROR"
    #|    direct = _symbit_try_method(
    #|        object_value, "half_gcdex", (left, right), _symbit_sentinel
    #|    )
    #|    rendered = _symbit_render_tuple_result(
    #|        object_value, direct, (0, 1), 2, True, True
    #|    )
    #|    if rendered != "ERROR":
    #|        return rendered
    #|    fallback = _symbit_try_method(
    #|        object_value, "gcdex", (left, right), _symbit_sentinel
    #|    )
    #|    return _symbit_render_tuple_result(
    #|        object_value, fallback, (0, 2), 3, True, True
    #|    )
    #|
    #|def _symbit_evalf(object_value, element):
    #|    if element is _symbit_sentinel:
    #|        return "ERROR"
    #|    value = _symbit_try_method(
    #|        object_value, "evalf", (element,), _symbit_sentinel
    #|    )
    #|    if value is _symbit_sentinel:
    #|        return "ERROR"
    #|    return str(sympy.nsimplify(value))
    #|
    #|def _symbit_capture(callable_value, args, kwargs):
    #|    try:
    #|        value = callable_value(*args, **kwargs)
    #|    except Exception:
    #|        return _symbit_sentinel
    #|    if value is None:
    #|        return _symbit_sentinel
    #|    return value
    #|
    #|def _symbit_render_captured(value):
    #|    if value is _symbit_sentinel:
    #|        return "ERROR"
    #|    return str(value)
  )
}

///|
priv struct DomainRecipe {
  builder : @recipe.Builder
  sympy : @recipe.ValueRef
  scope : @recipe.ValueRef
  error_sentinel : @recipe.ValueRef
  capture : @recipe.ValueRef
  render_captured : @recipe.ValueRef
}

///|
fn DomainRecipe::new() -> DomainRecipe raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let scope = builder.exec(builder.sympy_scope(), domain_foundation_source())
  let error_sentinel = builder.getitem(scope, Str("_symbit_sentinel"))
  let capture = builder.getitem(scope, Str("_symbit_capture"))
  let render_captured = builder.getitem(scope, Str("_symbit_render_captured"))
  { builder, sympy, scope, error_sentinel, capture, render_captured }
}

///|
fn DomainRecipe::domain(
  self : DomainRecipe,
  spec : String,
) -> @recipe.ValueRef raise {
  let parser = self.builder.getitem(self.scope, Str("_symbit_domain_spec"))
  self.builder.call(parser, [Str(spec)])
}

///|
fn DomainRecipe::symbol(
  self : DomainRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let symbol_fn = self.builder.getattr(self.sympy, "Symbol")
  self.builder.call(symbol_fn, [Str(name)])
}

///|
fn DomainRecipe::symbols(
  self : DomainRecipe,
  names : Array[String],
) -> Array[@recipe.RecipeArg] raise {
  let result : Array[@recipe.RecipeArg] = []
  for name in names {
    result.push(Ref(self.symbol(name)))
  }
  result
}

///|
fn DomainRecipe::sympify(
  self : DomainRecipe,
  source : String,
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(self.sympy, "sympify")
  self.builder.require_non_none(
    self.builder.call(callable, [Str(source)]),
    message="sympy-polys-domain-sympify-none",
  )
}

///|
fn DomainRecipe::try_method(
  self : DomainRecipe,
  object : @recipe.ValueRef,
  method_name : String,
  args : Array[@recipe.RecipeArg],
  failure : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_try_method"))
  let arguments = self.builder.tuple(args)
  self.builder.call(helper, [
    Ref(object),
    Str(method_name),
    Ref(arguments),
    Ref(failure),
  ])
}

///|
fn DomainRecipe::element(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  source : String,
) -> @recipe.ValueRef raise {
  // The legacy front doors sympified source text strictly before entering
  // their ERROR/false domain-operation boundary.
  let expression = self.sympify(source)
  self.try_method(domain, "from_sympy", [Ref(expression)], self.error_sentinel)
}

///|
fn DomainRecipe::try_attr(
  self : DomainRecipe,
  object : @recipe.ValueRef,
  attr_name : String,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_try_attr"))
  self.builder.call(helper, [Ref(object), Str(attr_name)])
}

///|
fn DomainRecipe::unary_element_method(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  method_name : String,
  source : String,
) -> @recipe.ValueRef raise {
  let element = self.element(domain, source)
  self.try_method(domain, method_name, [Ref(element)], self.error_sentinel)
}

///|
fn DomainRecipe::binary_element_method(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  method_name : String,
  left : String,
  right : String,
) -> @recipe.ValueRef raise {
  let lhs = self.element(domain, left)
  let rhs = self.element(domain, right)
  self.try_method(
    domain,
    method_name,
    [Ref(lhs), Ref(rhs)],
    self.error_sentinel,
  )
}

///|
fn DomainRecipe::element_predicate(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  method_name : String,
  source : String,
) -> @recipe.ValueRef raise {
  let result = self.unary_element_method(domain, method_name, source)
  self.attr_is_true(result)
}

///|
fn DomainRecipe::binary_element_predicate(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  method_name : String,
  left : String,
  right : String,
) -> @recipe.ValueRef raise {
  let result = self.binary_element_method(domain, method_name, left, right)
  self.attr_is_true(result)
}

///|
fn DomainRecipe::render_tuple_result(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  result : @recipe.ValueRef,
  indexes : Array[@recipe.RecipeArg],
  required_length : Int,
  exact : Bool,
  tuple_only : Bool,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(
    self.scope,
    Str("_symbit_render_tuple_result"),
  )
  let index_tuple = self.builder.tuple(indexes)
  self.builder.call(helper, [
    Ref(domain),
    Ref(result),
    Ref(index_tuple),
    DecimalInt(Show::to_string(required_length)),
    Bool(exact),
    Bool(tuple_only),
  ])
}

///|
fn DomainRecipe::half_gcdex(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  left : @recipe.ValueRef,
  right : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_half_gcdex"))
  self.builder.call(helper, [Ref(domain), Ref(left), Ref(right)])
}

///|
fn DomainRecipe::evalf(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  element : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_evalf"))
  self.builder.call(helper, [Ref(domain), Ref(element)])
}

///|
fn DomainRecipe::contains(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  expression : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_contains"))
  self.builder.call(helper, [Ref(domain), Ref(expression)])
}

///|
fn DomainRecipe::optional_hook(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  method_name : String,
  element : @recipe.ValueRef,
  base : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_optional_hook"))
  self.builder.call(helper, [
    Ref(domain),
    Str(method_name),
    Ref(element),
    Ref(base),
  ])
}

///|
fn DomainRecipe::sum(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  elements : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let helper = self.builder.getitem(self.scope, Str("_symbit_sum"))
  let values = self.builder.list(elements)
  self.builder.call(helper, [Ref(domain), Ref(values)])
}

///|
fn DomainRecipe::request_domain_str(
  self : DomainRecipe,
  domain : @recipe.ValueRef,
  result : @recipe.ValueRef,
) -> String raise {
  let helper = self.builder.getitem(
    self.scope,
    Str("_symbit_render_domain_result"),
  )
  let rendered = self.builder.call(helper, [Ref(domain), Ref(result)])
  self.builder.request_str(rendered)
}

///|
fn DomainRecipe::attr_is_true(
  self : DomainRecipe,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let comparator = self.builder.getitem(self.scope, Str("_symbit_attr_is_true"))
  self.builder.call(comparator, [Ref(value)])
}

///|
fn recipe_kwargs_dict(
  builder : @recipe.Builder,
  kwargs : Map[String, @recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for name, value in kwargs {
    items.push((Str(name), value))
  }
  builder.dict(items)
}

///|
fn DomainRecipe::method_call(
  self : DomainRecipe,
  object : @recipe.ValueRef,
  method_name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(object, method_name)
  self.builder.require_non_none(
    self.builder.call(callable, args, kwargs~),
    message="sympy-polys-domain-call-none:" + method_name,
  )
}

///|
fn DomainRecipe::captured_method_call(
  self : DomainRecipe,
  object : @recipe.ValueRef,
  method_name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.builder.getattr(object, method_name)
  let arguments = self.builder.tuple(args)
  let keyword_arguments = recipe_kwargs_dict(self.builder, kwargs)
  self.builder.call(self.capture, [
    Ref(callable),
    Ref(arguments),
    Ref(keyword_arguments),
  ])
}

///|
fn DomainRecipe::request_captured_str(
  self : DomainRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let rendered = self.builder.call(self.render_captured, [Ref(result)])
  self.builder.request_str(rendered)
}

///|
fn parse_domain_int(value : String) -> Int raise {
  @string.parse_int(value) catch {
    _ => fail("sympy-polys-domain-int:" + value)
  }
}
