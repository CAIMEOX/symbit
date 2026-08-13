///|
fn polys_tail_recipe_source() -> String {
  (
    #|def _symbit_polys_p6g_sequence(value, minimum, message):
    #|    if value is None or not isinstance(value, (list, tuple)):
    #|        raise ValueError(message)
    #|    if len(value) < minimum:
    #|        raise ValueError(message)
    #|    return value
    #|
    #|def _symbit_polys_p6g_value(value, message):
    #|    if value is None:
    #|        raise ValueError(message)
    #|    return value
    #|
    #|def _symbit_polys_p6g_int_list_text(values, message):
    #|    values = _symbit_polys_p6g_sequence(values, 0, message)
    #|    parts = []
    #|    for value in values:
    #|        value = _symbit_polys_p6g_value(value, message)
    #|        parts.append(str(int(str(value))))
    #|    return "[" + ",".join(parts) + "]"
    #|
    #|def _symbit_polys_p6g_matrix_text(matrix):
    #|    matrix = _symbit_polys_p6g_value(matrix, "matrix-hnf-none")
    #|    rows = _symbit_polys_p6g_sequence(
    #|        matrix.tolist(), 0, "matrix-hnf-rows"
    #|    )
    #|    rendered = []
    #|    for row in rows:
    #|        row = _symbit_polys_p6g_sequence(row, 0, "matrix-hnf-row")
    #|        cells = []
    #|        for cell in row:
    #|            cell = _symbit_polys_p6g_value(cell, "matrix-hnf-cell-none")
    #|            cells.append(str(int(str(cell))))
    #|        rendered.append(",".join(cells))
    #|    return ";".join(rendered)
    #|
    #|def _symbit_polys_p6g_domain_scalar_text(result):
    #|    fields = _symbit_polys_p6g_sequence(
    #|        result, 2, "domainscalar-construct-domain"
    #|    )
    #|    domain = _symbit_polys_p6g_value(
    #|        fields[0], "domainscalar-domain-none"
    #|    )
    #|    elements = _symbit_polys_p6g_sequence(
    #|        fields[1], 1, "domainscalar-construct-items"
    #|    )
    #|    element = _symbit_polys_p6g_value(
    #|        elements[0], "domainscalar-element-none"
    #|    )
    #|    return str(element) + "@" + str(domain)
    #|
    #|def _symbit_polys_p6g_domain_text(result):
    #|    fields = _symbit_polys_p6g_sequence(
    #|        result, 1, "construct-domain-result-shape"
    #|    )
    #|    domain = _symbit_polys_p6g_value(
    #|        fields[0], "construct-domain-domain-none"
    #|    )
    #|    return str(domain)
    #|
    #|def _symbit_polys_p6g_sorted_factors_text(result, multiple):
    #|    factors = _symbit_polys_p6g_sequence(
    #|        result, 0, "sort-factors-result-shape"
    #|    )
    #|    rendered = []
    #|    if multiple:
    #|        for item in factors:
    #|            pair = _symbit_polys_p6g_sequence(
    #|                item, 2, "sort-factors-pair-shape"
    #|            )
    #|            factor = _symbit_polys_p6g_int_list_text(
    #|                pair[0], "sort-factors-factor-shape"
    #|            )
    #|            exponent = _symbit_polys_p6g_value(
    #|                pair[1], "sort-factors-exponent-none"
    #|            )
    #|            rendered.append(
    #|                "(" + factor + "," + str(int(str(exponent))) + ")"
    #|            )
    #|    else:
    #|        for factor in factors:
    #|            rendered.append(_symbit_polys_p6g_int_list_text(
    #|                factor, "sort-factors-factor-shape"
    #|            ))
    #|    return "[" + ",".join(rendered) + "]"
    #|
    #|def _symbit_polys_p6g_anp_coefficients(values, message):
    #|    values = _symbit_polys_p6g_sequence(values, 0, message)
    #|    rendered = []
    #|    for value in values:
    #|        value = _symbit_polys_p6g_value(value, message)
    #|        rendered.append(str(value))
    #|    return "[" + ", ".join(rendered) + "]"
    #|
    #|def _symbit_polys_p6g_anp_text(value):
    #|    value = _symbit_polys_p6g_value(value, "init-normal-anp-none")
    #|    rep = _symbit_polys_p6g_value(
    #|        getattr(value, "rep"), "init-normal-anp-rep-none"
    #|    )
    #|    modulus = _symbit_polys_p6g_value(
    #|        getattr(value, "mod"), "init-normal-anp-mod-none"
    #|    )
    #|    domain = _symbit_polys_p6g_value(
    #|        getattr(value, "dom"), "init-normal-anp-domain-none"
    #|    )
    #|    return (
    #|        "ANP("
    #|        + _symbit_polys_p6g_anp_coefficients(
    #|            rep, "init-normal-anp-rep-shape"
    #|        )
    #|        + ", "
    #|        + _symbit_polys_p6g_anp_coefficients(
    #|            modulus, "init-normal-anp-mod-shape"
    #|        )
    #|        + ", " + str(domain) + ")"
    #|    )
    #|
    #|def _symbit_polys_p6g_factor_repr_text(result):
    #|    fields = _symbit_polys_p6g_sequence(
    #|        result, 2, "sort-factor-repr-tuple"
    #|    )
    #|    content = _symbit_polys_p6g_value(
    #|        fields[0], "sort-factor-repr-content-none"
    #|    )
    #|    factors = _symbit_polys_p6g_sequence(
    #|        fields[1], 0, "sort-factor-repr-factors-shape"
    #|    )
    #|    entries = []
    #|    for item in factors:
    #|        pair = _symbit_polys_p6g_sequence(
    #|            item, 2, "sort-factor-repr-pair-shape"
    #|        )
    #|        factor = _symbit_polys_p6g_value(
    #|            pair[0], "sort-factor-repr-factor-none"
    #|        )
    #|        exponent = _symbit_polys_p6g_value(
    #|            pair[1], "sort-factor-repr-exponent-none"
    #|        )
    #|        entries.append((str(factor), int(str(exponent))))
    #|    entries.sort(key=lambda item: (item[0], item[1]))
    #|    body = ",".join(
    #|        "(" + factor + ", " + str(exponent) + ")"
    #|        for factor, exponent in entries
    #|    )
    #|    return "(" + str(content) + ", [" + body + "])"
  )
}

///|
priv struct PolysTailRecipe {
  polys : PolysRecipe
  scope : @recipe.ValueRef
}

///|
fn PolysTailRecipe::new() -> PolysTailRecipe raise {
  let polys = PolysRecipe::new()
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    polys_tail_recipe_source(),
  )
  { polys, scope }
}

///|
fn PolysTailRecipe::helper(
  self : PolysTailRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.getitem(self.scope, Str(name))
}

///|
fn PolysTailRecipe::render(
  self : PolysTailRecipe,
  helper_name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  self.polys.builder.require_non_none(
    self.polys.builder.call(self.helper(helper_name), args),
    message="sympy-polys-tail-render-none:" + helper_name,
  )
}

///|
fn PolysTailRecipe::request_matrix(
  self : PolysTailRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(
    self.render("_symbit_polys_p6g_matrix_text", [Ref(value)]),
  )
}

///|
fn PolysTailRecipe::request_domain_scalar(
  self : PolysTailRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(
    self.render("_symbit_polys_p6g_domain_scalar_text", [Ref(value)]),
  )
}

///|
fn PolysTailRecipe::request_domain(
  self : PolysTailRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(
    self.render("_symbit_polys_p6g_domain_text", [Ref(value)]),
  )
}

///|
fn PolysTailRecipe::request_sorted_factors(
  self : PolysTailRecipe,
  value : @recipe.ValueRef,
  multiple~ : Bool,
) -> String raise {
  self.polys.builder.request_str(
    self.render("_symbit_polys_p6g_sorted_factors_text", [
      Ref(value),
      Bool(multiple),
    ]),
  )
}

///|
fn PolysTailRecipe::request_anp(
  self : PolysTailRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(
    self.render("_symbit_polys_p6g_anp_text", [Ref(value)]),
  )
}

///|
fn PolysTailRecipe::request_factor_repr(
  self : PolysTailRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  self.polys.builder.request_str(
    self.render("_symbit_polys_p6g_factor_repr_text", [Ref(value)]),
  )
}

///|
fn PolysTailRecipe::int_list(
  self : PolysTailRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.polys.builder.list(items)
}

///|
fn PolysTailRecipe::int_lists(
  self : PolysTailRecipe,
  values : Array[Array[Int]],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(Ref(self.int_list(value)))
  }
  self.polys.builder.list(items)
}

///|
fn PolysTailRecipe::matrix_rows(
  self : PolysTailRecipe,
  rows : Array[Array[Int]],
) -> @recipe.ValueRef raise {
  let column_count = if rows.is_empty() { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != column_count {
      fail("matrix-ragged")
    }
  }
  self.int_lists(rows)
}

///|
fn PolysTailRecipe::sympy_domain(
  self : PolysTailRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let sympy = self.polys.builder.import_module("sympy")
  self.polys.builder.require_non_none(
    self.polys.builder.getattr(sympy, name),
    message="sympy-domain-missing:" + name,
  )
}

///|
fn PolysTailRecipe::domain_coefficients(
  self : PolysTailRecipe,
  values : Array[Int],
  domain : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let convert = self.polys.builder.getattr(domain, "convert")
  let coefficients : Array[@recipe.RecipeArg] = []
  for value in values {
    let integer = self.polys.call("sympy.Integer", [
      DecimalInt(Show::to_string(value)),
    ])
    let converted = self.polys.builder.require_non_none(
      self.polys.builder.call(convert, [Ref(integer)]),
      message="sympy-polys-tail-domain-convert-none",
    )
    coefficients.push(Ref(converted))
  }
  self.polys.builder.list(coefficients)
}

///|
pub fn matrix_hnf_code(rows : Array[Array[Int]]) -> String raise {
  let recipe = PolysTailRecipe::new()
  let matrix = recipe.polys.call("sympy.Matrix", [Ref(recipe.matrix_rows(rows))])
  let result = recipe.polys.call(
    "sympy.matrices.normalforms.hermite_normal_form",
    [Ref(matrix)],
  )
  recipe.request_matrix(result)
}

///|
pub fn domainscalar_from_expr(expr : String) -> String raise {
  let recipe = PolysTailRecipe::new()
  let expression = recipe.polys.call("sympy.sympify", [Str(expr)])
  let expressions = recipe.polys.builder.list([Ref(expression)])
  let result = recipe.polys.call("sympy.polys.constructor.construct_domain", [
    Ref(expressions),
  ])
  recipe.request_domain_scalar(result)
}

///|
pub fn construct_domain_domain(exprs : Array[@symcore.Expr]) -> String raise {
  let recipe = PolysTailRecipe::new()
  let expressions = recipe.polys.expression_list(exprs)
  let result = recipe.polys.call("sympy.polys.constructor.construct_domain", [
    Ref(expressions),
  ])
  recipe.request_domain(result)
}

///|
pub fn sort_factors(factors : Array[Array[Int]]) -> String raise {
  let recipe = PolysTailRecipe::new()
  let values = recipe.int_lists(factors)
  let result = recipe.polys.call(
    "sympy.polys.polyutils._sort_factors",
    [Ref(values)],
    kwargs={ "multiple": Bool(false) },
  )
  recipe.request_sorted_factors(result, multiple=false)
}

///|
pub fn sort_factors_multiple(
  factors : Array[(Array[Int], Int)],
) -> String raise {
  let recipe = PolysTailRecipe::new()
  let values : Array[@recipe.RecipeArg] = []
  for item in factors {
    let (factor, exponent) = item
    let pair = recipe.polys.builder.tuple([
      Ref(recipe.int_list(factor)),
      DecimalInt(Show::to_string(exponent)),
    ])
    values.push(Ref(pair))
  }
  let factor_list = recipe.polys.builder.list(values)
  let result = recipe.polys.call(
    "sympy.polys.polyutils._sort_factors",
    [Ref(factor_list)],
    kwargs={ "multiple": Bool(true) },
  )
  recipe.request_sorted_factors(result, multiple=true)
}

///|
pub fn init_normal_ANP(
  rep : Array[Int],
  mod : Array[Int],
  domain? : String = "QQ",
) -> String raise {
  let recipe = PolysTailRecipe::new()
  let domain_object = recipe.sympy_domain(domain)
  let representation = recipe.domain_coefficients(rep, domain_object)
  let modulus = recipe.domain_coefficients(mod, domain_object)
  let result = recipe.polys.call("sympy.polys.polyclasses.init_normal_ANP", [
    Ref(representation),
    Ref(modulus),
    Ref(domain_object),
  ])
  recipe.request_anp(result)
}

///|
pub fn sympy_sort_factor_repr(repr_str : String) -> String raise {
  let recipe = PolysTailRecipe::new()
  let parsed = recipe.polys.call("sympy.sympify", [Str(repr_str)])
  recipe.request_factor_repr(parsed)
}
