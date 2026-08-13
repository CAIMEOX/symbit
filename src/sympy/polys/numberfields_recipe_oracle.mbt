///|
fn numberfields_foundation_source() -> String {
  (
    #|def _symbit_nf_tuple(value, minimum, message):
    #|    if not isinstance(value, (list, tuple)) or len(value) < minimum:
    #|        raise ValueError(message)
    #|    return value
    #|
    #|def _symbit_nf_to_rational(value_text, denominator_text, limit):
    #|    from fractions import Fraction
    #|    value = sympy.Float(value_text)
    #|    max_denom = int(denominator_text)
    #|    try:
    #|        from sympy.polys.domains.realfield import to_rational
    #|    except (ImportError, AttributeError):
    #|        to_rational = None
    #|    if to_rational is not None:
    #|        return to_rational(value, max_denom, limit)
    #|    from sympy.external.mpmath import to_rational as mpmath_to_rational
    #|    p, q = mpmath_to_rational(value._mpf_)
    #|    p, q = int(p), int(q)
    #|    if (not limit) or q <= max_denom:
    #|        return p, q
    #|    p0, q0, p1, q1 = 0, 1, 1, 0
    #|    n, d = p, q
    #|    while True:
    #|        a = n // d
    #|        q2 = q0 + a*q1
    #|        if q2 > max_denom:
    #|            break
    #|        p0, q0, p1, q1 = p1, q1, p0 + a*p1, q2
    #|        n, d = d, n - a*d
    #|    k = (max_denom - q0) // q1
    #|    number = Fraction(p, q)
    #|    bound1 = Fraction(p0 + k*p1, q0 + k*q1)
    #|    bound2 = Fraction(p1, q1)
    #|    if not bound2 or not bound1:
    #|        return p, q
    #|    if abs(bound2 - number) <= abs(bound1 - number):
    #|        return bound2.numerator, bound2.denominator
    #|    return bound1.numerator, bound1.denominator
    #|
    #|def _symbit_nf_primitive_coeffs(result):
    #|    fields = _symbit_nf_tuple(result, 2, "primitive-element-result-shape")
    #|    return [int(str(value)) for value in fields[1]]
    #|
    #|def _symbit_nf_primitive_reps(result):
    #|    fields = _symbit_nf_tuple(
    #|        result, 3, "primitive-element-ex-result-shape"
    #|    )
    #|    return "[" + ",".join(
    #|        "[" + ",".join(str(sympy.Rational(value)) for value in row) + "]"
    #|        for row in fields[2]
    #|    ) + "]"
    #|
    #|def _symbit_nf_to_number_field_text(lhs, rhs):
    #|    from sympy.polys.numberfields import to_number_field
    #|    try:
    #|        result = to_number_field(lhs, rhs)
    #|    except Exception:
    #|        return "None"
    #|    if result is None:
    #|        return "None"
    #|    return str(result.coeffs()).replace(" ", "")
    #|
    #|def _symbit_nf_make_mod_elt_text(
    #|    defining_expression, basis, column, denominator, use_submodule
    #|):
    #|    from sympy.polys.domains import ZZ
    #|    from sympy.polys.matrices import DomainMatrix
    #|    from sympy.polys.numberfields.modules import PowerBasis, make_mod_elt
    #|    x = sympy.Symbol("x")
    #|    power = PowerBasis(sympy.Poly(sympy.sympify(defining_expression), x))
    #|    module = power
    #|    if use_submodule:
    #|        basis_matrix = DomainMatrix(
    #|            basis, (len(basis), len(basis)), ZZ
    #|        )
    #|        module = power.submodule_from_matrix(basis_matrix)
    #|    column_matrix = DomainMatrix(
    #|        [[value] for value in column], (len(column), 1), ZZ
    #|    )
    #|    element = make_mod_elt(module, column_matrix, denom=denominator)
    #|    return type(element).__name__ + ":" + str(element)
    #|
    #|def _symbit_nf_find_min_poly_text(
    #|    defining_expression, column, denominator, symbol_name
    #|):
    #|    from sympy.polys.domains import ZZ
    #|    from sympy.polys.matrices import DomainMatrix
    #|    from sympy.polys.numberfields.modules import (
    #|        PowerBasis, find_min_poly, make_mod_elt,
    #|    )
    #|    x = sympy.Symbol(symbol_name)
    #|    module = PowerBasis(sympy.Poly(sympy.sympify(defining_expression), x))
    #|    column_matrix = DomainMatrix(
    #|        [[value] for value in column], (len(column), 1), ZZ
    #|    )
    #|    element = make_mod_elt(module, column_matrix, denom=denominator)
    #|    return find_min_poly(element, sympy.QQ, x=x).as_expr()
    #|
    #|def _symbit_nf_field_isomorphism(lhs, rhs):
    #|    from sympy.polys.numberfields import field_isomorphism
    #|    try:
    #|        return field_isomorphism(lhs, rhs)
    #|    except Exception:
    #|        return None
    #|
    #|def _symbit_nf_field_isomorphism_text(lhs, rhs):
    #|    result = _symbit_nf_field_isomorphism(lhs, rhs)
    #|    if result is None:
    #|        return "None"
    #|    return str(result).replace(" ", "")
    #|
    #|def _symbit_nf_field_isomorphic(lhs, rhs):
    #|    return _symbit_nf_field_isomorphism(lhs, rhs) is not None
    #|
    #|def _symbit_nf_get_num_denom_text(result):
    #|    fields = _symbit_nf_tuple(result, 2, "numberfield-get-num-denom")
    #|    return "(" + str(fields[0]) + "," + str(fields[1]) + ")"
    #|
    #|def _symbit_nf_to_col_text(column):
    #|    return str(column.to_Matrix())
    #|
    #|def _symbit_nf_factor_items_text(factors):
    #|    entries = sorted(
    #|        ((int(str(prime)), int(str(power))) for prime, power in factors.items()),
    #|        key=lambda item: item[0],
    #|    )
    #|    return "[" + ",".join(
    #|        "(" + str(prime) + "," + str(power) + ")"
    #|        for prime, power in entries
    #|    ) + "]"
    #|
    #|def _symbit_nf_factor_pair_text(result):
    #|    fields = _symbit_nf_tuple(
    #|        result, 2, "numberfield-extract-fundamental-discriminant"
    #|    )
    #|    return (
    #|        _symbit_nf_factor_items_text(fields[0])
    #|        + "||" + _symbit_nf_factor_items_text(fields[1])
    #|    )
    #|
    #|def _symbit_nf_coeff_search_text(generator, count):
    #|    rows = []
    #|    for _ in range(count):
    #|        rows.append([int(str(value)) for value in next(generator)])
    #|    return "[" + ",".join(
    #|        "[" + ",".join(str(value) for value in row) + "]"
    #|        for row in rows
    #|    ) + "]"
    #|
    #|def _symbit_nf_poly(expression, generators):
    #|    if generators is None:
    #|        generators = sorted(expression.free_symbols, key=lambda value: value.name)
    #|    return sympy.Poly(expression, *generators)
    #|
    #|def _symbit_nf_poly_expr_text(poly):
    #|    return str(sympy.sympify(str(poly.as_expr()))).replace(" ", "")
    #|
    #|def _symbit_nf_tschirnhausen_text(result):
    #|    fields = _symbit_nf_tuple(result, 2, "tschirnhausen tuple")
    #|    return (
    #|        "(" + _symbit_nf_poly_expr_text(fields[0])
    #|        + ", " + _symbit_nf_poly_expr_text(fields[1]) + ")"
    #|    )
    #|
    #|def _symbit_nf_resolvent_definitions_text(result):
    #|    parts = []
    #|    for key, value in result.items():
    #|        if isinstance(value, (list, tuple)) and len(value) >= 3:
    #|            parts.append(
    #|                str(key).replace(" ", "")
    #|                + ":" + str(len(value[1]))
    #|                + ":" + str(len(value[2]))
    #|            )
    #|    return "|".join(sorted(parts))
    #|
    #|def _symbit_nf_sparse_resolvent_text(definitions, degree, number):
    #|    from sympy.polys.numberfields.galois_resolvents import (
    #|        sparse_symmetrize_resolvent_coeffs,
    #|    )
    #|    fields = _symbit_nf_tuple(
    #|        definitions[(degree, number)], 3, "resolvent spec tuple"
    #|    )
    #|    result = sparse_symmetrize_resolvent_coeffs(
    #|        fields[0], fields[1], fields[2]
    #|    )
    #|    result_fields = _symbit_nf_tuple(result, 1, "resolvent symmetrize tuple")
    #|    return "|".join(str(value) for value in result_fields[0])
  )
}

///|
priv struct NumberFieldsRecipe {
  polys : PolysRecipe
  scope : @recipe.ValueRef
}

///|
fn NumberFieldsRecipe::new() -> NumberFieldsRecipe raise {
  let polys = PolysRecipe::new()
  let scope = polys.builder.exec(
    polys.builder.sympy_scope(),
    numberfields_foundation_source(),
  )
  { polys, scope }
}

///|
fn NumberFieldsRecipe::helper(
  self : NumberFieldsRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.polys.builder.getitem(self.scope, Str(name))
}

///|
fn NumberFieldsRecipe::helper_call(
  self : NumberFieldsRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  self.polys.builder.require_non_none(
    self.polys.builder.call(self.helper(name), args),
    message="sympy-numberfields-helper-none:" + name,
  )
}

///|
fn NumberFieldsRecipe::sympify(
  self : NumberFieldsRecipe,
  source : String,
) -> @recipe.ValueRef raise {
  self.polys.call("sympy.sympify", [Str(source)])
}

///|
fn NumberFieldsRecipe::symbol(
  self : NumberFieldsRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  self.polys.literal_symbol(name)
}

///|
fn NumberFieldsRecipe::sympified_list(
  self : NumberFieldsRecipe,
  sources : Array[String],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for source in sources {
    items.push(Ref(self.sympify(source)))
  }
  self.polys.builder.list(items)
}

///|
fn NumberFieldsRecipe::int_list(
  self : NumberFieldsRecipe,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(DecimalInt(Show::to_string(value)))
  }
  self.polys.builder.list(items)
}

///|
fn NumberFieldsRecipe::int_rows(
  self : NumberFieldsRecipe,
  rows : Array[Array[Int]],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for row in rows {
    items.push(Ref(self.int_list(row)))
  }
  self.polys.builder.list(items)
}

///|
fn NumberFieldsRecipe::literal_symbol_list(
  self : NumberFieldsRecipe,
  names : Array[String],
) -> @recipe.ValueRef raise {
  self.polys.literal_symbol_list(names)
}

///|
fn NumberFieldsRecipe::poly(
  self : NumberFieldsRecipe,
  expression : @symcore.Expr,
  gens : Array[String],
) -> @recipe.ValueRef raise {
  let generator_arg : @recipe.RecipeArg = if gens.is_empty() {
    Null
  } else {
    Ref(self.literal_symbol_list(gens))
  }
  self.helper_call("_symbit_nf_poly", [
    Ref(self.polys.expr(expression)),
    generator_arg,
  ])
}

///|
fn NumberFieldsRecipe::request_int_array(
  self : NumberFieldsRecipe,
  value : @recipe.ValueRef,
) -> Array[Int] raise {
  match self.polys.builder.request(value, List(Int)) {
    Array(items) => {
      let result : Array[Int] = []
      for item in items {
        match item {
          String(text) =>
            result.push(
              @string.parse_int(text) catch {
                _ => fail("sympy-numberfields-int-item:" + text)
              },
            )
          other => fail("sympy-numberfields-int-item:" + other.stringify())
        }
      }
      result
    }
    other => fail("sympy-numberfields-int-array:" + other.stringify())
  }
}

///|
pub fn to_rational(
  value : String,
  max_denom : String,
  limit? : Bool = true,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_to_rational", [
    Str(value),
    Str(max_denom),
    Bool(limit),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn wrap(text : String, width? : Int = 80) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galois_resolvents.wrap",
    [Str(text), DecimalInt(Show::to_string(width))],
  )
  recipe.polys.builder.request_str(result)
}

///|
pub fn numberfield_minpoly(expr : String, gen? : String = "x") -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call("sympy.polys.numberfields.minpoly", [
    Ref(recipe.sympify(expr)),
    Ref(recipe.symbol(gen)),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn numberfield_primitive_coeffs(
  exprs : Array[String],
  gen? : String = "x",
) -> Array[Int] raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call("sympy.polys.numberfields.primitive_element", [
    Ref(recipe.sympified_list(exprs)),
    Ref(recipe.symbol(gen)),
  ])
  let coefficients = recipe.helper_call("_symbit_nf_primitive_coeffs", [
    Ref(result),
  ])
  recipe.request_int_array(coefficients)
}

///|
pub fn numberfield_primitive_reps(
  exprs : Array[String],
  gen? : String = "x",
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.primitive_element",
    [Ref(recipe.sympified_list(exprs)), Ref(recipe.symbol(gen))],
    kwargs={ "ex": Bool(true) },
  )
  let rendered = recipe.helper_call("_symbit_nf_primitive_reps", [Ref(result)])
  recipe.polys.builder.request_str(rendered)
}

///|
pub fn numberfield_to_number_field_coeffs(
  lhs : String,
  rhs : String,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_to_number_field_text", [
    Ref(recipe.sympify(lhs)),
    Ref(recipe.sympify(rhs)),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn make_mod_elt_power_basis(
  def_expr : String,
  col : Array[Int],
  denom? : Int = 1,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_make_mod_elt_text", [
    Str(def_expr),
    Ref(recipe.polys.builder.list([])),
    Ref(recipe.int_list(col)),
    DecimalInt(Show::to_string(denom)),
    Bool(false),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn make_mod_elt_submodule(
  def_expr : String,
  basis : Array[Array[Int]],
  col : Array[Int],
  denom? : Int = 1,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_make_mod_elt_text", [
    Str(def_expr),
    Ref(recipe.int_rows(basis)),
    Ref(recipe.int_list(col)),
    DecimalInt(Show::to_string(denom)),
    Bool(true),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn find_min_poly_power_basis(
  def_expr : String,
  col : Array[Int],
  denom? : Int = 1,
  x? : String = "x",
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_find_min_poly_text", [
    Str(def_expr),
    Ref(recipe.int_list(col)),
    DecimalInt(Show::to_string(denom)),
    Str(x),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn numberfield_field_isomorphism_coeffs(
  lhs : String,
  rhs : String,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_field_isomorphism_text", [
    Ref(recipe.sympify(lhs)),
    Ref(recipe.sympify(rhs)),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn numberfield_field_isomorphic(lhs : String, rhs : String) -> Bool raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.helper_call("_symbit_nf_field_isomorphic", [
    Ref(recipe.sympify(lhs)),
    Ref(recipe.sympify(rhs)),
  ])
  recipe.polys.builder.request_bool(result)
}

///|
pub fn numberfield_is_rat(expr : String) -> Bool raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call("sympy.polys.numberfields.utilities.is_rat", [
    Ref(recipe.sympify(expr)),
  ])
  recipe.polys.builder.request_bool(result)
}

///|
pub fn numberfield_is_int(expr : String) -> Bool raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call("sympy.polys.numberfields.utilities.is_int", [
    Ref(recipe.sympify(expr)),
  ])
  recipe.polys.builder.request_bool(result)
}

///|
pub fn numberfield_get_num_denom(expr : String) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.utilities.get_num_denom",
    [Ref(recipe.sympify(expr))],
  )
  let rendered = recipe.helper_call("_symbit_nf_get_num_denom_text", [
    Ref(result),
  ])
  recipe.polys.builder.request_str(rendered)
}

///|
pub fn numberfield_to_col(coeffs : Array[Int]) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call("sympy.polys.numberfields.modules.to_col", [
    Ref(recipe.int_list(coeffs)),
  ])
  let rendered = recipe.helper_call("_symbit_nf_to_col_text", [Ref(result)])
  recipe.polys.builder.request_str(rendered)
}

///|
pub fn numberfield_s_vars(n : Int) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galois_resolvents.s_vars",
    [DecimalInt(Show::to_string(n))],
  )
  recipe.polys.builder.request_str(result)
}

///|
pub fn numberfield_is_sq_maxrank_HNF(rows : Array[Array[Int]]) -> Bool raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain("ZZ")
  let matrix = recipe.domainmatrix(rows, domain)
  let result = recipe.call_path(
    "sympy.polys.numberfields.modules.is_sq_maxrank_HNF",
    [Ref(matrix)],
  )
  recipe.request_bool(result)
}

///|
pub fn numberfield_supplement_a_subspace(
  rows : Array[Array[Int]],
  domain_spec : String,
) -> String raise {
  let recipe = DomainMatrixRecipe::new()
  let domain = recipe.domain(domain_spec)
  let matrix = recipe.domainmatrix(rows, domain)
  let result = recipe.call_path(
    "sympy.polys.numberfields.utilities.supplement_a_subspace",
    [Ref(matrix)],
  )
  recipe.request_str(recipe.render_matrix(result))
}

///|
pub fn numberfield_extract_fundamental_discriminant(a : Int) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.utilities.extract_fundamental_discriminant",
    [DecimalInt(Show::to_string(a))],
  )
  let rendered = recipe.helper_call("_symbit_nf_factor_pair_text", [Ref(result)])
  recipe.polys.builder.request_str(rendered)
}

///|
pub fn numberfield_coeff_search(m : Int, r : Int, count : Int) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let generator = recipe.polys.call(
    "sympy.polys.numberfields.utilities.coeff_search",
    [DecimalInt(Show::to_string(m)), DecimalInt(Show::to_string(r))],
  )
  let result = recipe.helper_call("_symbit_nf_coeff_search_text", [
    Ref(generator),
    DecimalInt(Show::to_string(count)),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn tschirnhausen_transformation(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  max_tries? : Int = 30,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let polynomial = recipe.poly(expr, gens)
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galoisgroups.tschirnhausen_transformation",
    [Ref(polynomial)],
    kwargs={ "max_tries": DecimalInt(Show::to_string(max_tries)) },
  )
  let rendered = recipe.helper_call("_symbit_nf_tschirnhausen_text", [
    Ref(result),
  ])
  recipe.polys.builder.request_str(rendered)
}

///|
pub fn get_resolvent_by_lookup(
  expr : @symcore.Expr,
  number : Int,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let polynomial = recipe.poly(expr, gens)
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galois_resolvents.get_resolvent_by_lookup",
    [Ref(polynomial), DecimalInt(Show::to_string(number))],
  )
  recipe.polys.builder.request_str(result)
}

///|
pub fn define_resolvents() -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galois_resolvents.define_resolvents",
    [],
  )
  let rendered = recipe.helper_call("_symbit_nf_resolvent_definitions_text", [
    Ref(result),
  ])
  recipe.polys.builder.request_str(rendered)
}

///|
pub fn sparse_symmetrize_resolvent_coeffs(
  degree : Int,
  number : Int,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let definitions = recipe.polys.call(
    "sympy.polys.numberfields.galois_resolvents.define_resolvents",
    [],
  )
  let result = recipe.helper_call("_symbit_nf_sparse_resolvent_text", [
    Ref(definitions),
    DecimalInt(Show::to_string(degree)),
    DecimalInt(Show::to_string(number)),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn generate_lambda_lookup(
  verbose? : Bool = false,
  trial_run? : Bool = false,
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galois_resolvents.generate_lambda_lookup",
    [],
    kwargs={ "verbose": Bool(verbose), "trial_run": Bool(trial_run) },
  )
  recipe.polys.builder.request_str(result)
}

///|
pub fn has_square_disc(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> Bool raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.galoisgroups.has_square_disc",
    [Ref(recipe.poly(expr, gens))],
  )
  recipe.polys.builder.request_bool(result)
}

///|
pub fn isolate(expr : @symcore.Expr, eps? : String = "") -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.polys.expr(expr))]
  if eps != "" {
    args.push(Ref(recipe.sympify(eps)))
  }
  let result = recipe.polys.call(
    "sympy.polys.numberfields.utilities.isolate", args,
  )
  recipe.polys.builder.request_str(result)
}

///|
pub fn round_two(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call("sympy.polys.numberfields.basis.round_two", [
    Ref(recipe.poly(expr, gens)),
  ])
  recipe.polys.builder.request_str(result)
}

///|
pub fn prime_decomp(
  p : Int,
  expr : @symcore.Expr,
  gens? : Array[String] = [],
) -> String raise {
  let recipe = NumberFieldsRecipe::new()
  let result = recipe.polys.call(
    "sympy.polys.numberfields.primes.prime_decomp",
    [DecimalInt(Show::to_string(p)), Ref(recipe.poly(expr, gens))],
  )
  recipe.polys.builder.request_str(result)
}
