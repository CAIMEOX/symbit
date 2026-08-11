///|
fn trim_ws(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
fn render_domain_action(action : () -> Domain raise PolyError) -> String {
  try action() catch {
    _ => "ERROR"
  } noraise {
    domain => @sympolys.domain_to_sympy_string(domain)
  }
}

///|
fn normalize_expr_text(text : String) -> String {
  let compact = trim_ws(text)
  if compact == "ERROR" {
    return compact
  }
  try sympy_normalize(compact) catch {
    _ => compact
  } noraise {
    normalized => trim_ws(normalized)
  }
}

///|
fn normalize_expr_tuple3_text(text : String) -> String {
  let compact = trim_ws(text)
  if compact == "ERROR" || !compact.has_prefix("(") || !compact.has_suffix(")") {
    return compact
  }
  let inner = compact[1:compact.length() - 1].to_owned()
  let parts : Array[String] = Array::new()
  for part in inner.split(",") {
    parts.push(normalize_expr_text(part.trim().to_owned()))
  }
  if parts.length() != 3 {
    compact
  } else {
    "(\{parts[0]},\{parts[1]},\{parts[2]})"
  }
}

///|
fn normalize_expr_tuple2_text(text : String) -> String {
  let compact = trim_ws(text)
  if compact == "ERROR" || !compact.has_prefix("(") || !compact.has_suffix(")") {
    return compact
  }
  let inner = compact[1:compact.length() - 1].to_owned()
  let parts : Array[String] = Array::new()
  for part in inner.split(",") {
    parts.push(normalize_expr_text(part.trim().to_owned()))
  }
  if parts.length() != 2 {
    compact
  } else {
    "(\{parts[0]},\{parts[1]})"
  }
}

///|
fn render_expr_result(result : Result[@symcore.Expr, PolyError]) -> String {
  match result {
    Ok(expr) => normalize_expr_text(@symprint.pretty_string(expr))
    Err(_) => "ERROR"
  }
}

///|
fn render_expr_action(action : () -> @symcore.Expr raise PolyError) -> String {
  try action() catch {
    _ => "ERROR"
  } noraise {
    expr => normalize_expr_text(@symprint.pretty_string(expr))
  }
}

///|
fn render_expr_triple_action(
  action : () -> (@symcore.Expr, @symcore.Expr, @symcore.Expr) raise PolyError,
) -> String {
  try action() catch {
    _ => "ERROR"
  } noraise {
    items =>
      normalize_expr_tuple3_text(
        "(\{@symprint.pretty_string(items.0)},\{@symprint.pretty_string(items.1)},\{@symprint.pretty_string(items.2)})",
      )
  }
}

///|
fn render_expr_pair_action(
  action : () -> (@symcore.Expr, @symcore.Expr) raise PolyError,
) -> String {
  try action() catch {
    _ => "ERROR"
  } noraise {
    items =>
      normalize_expr_tuple2_text(
        "(\{@symprint.pretty_string(items.0)},\{@symprint.pretty_string(items.1)})",
      )
  }
}

///|
fn render_optional_expr_result(
  result : Result[@symcore.Expr?, PolyError],
) -> String {
  match result {
    Ok(Some(expr)) => normalize_expr_text(@symprint.pretty_string(expr))
    Ok(None) => "NONE"
    Err(_) => "ERROR"
  }
}

///|
fn render_optional_expr_action(
  action : () -> @symcore.Expr? raise PolyError,
) -> String {
  try action() catch {
    _ => "ERROR"
  } noraise {
    Some(expr) => normalize_expr_text(@symprint.pretty_string(expr))
    None => "NONE"
  }
}

///|
fn render_expr_tree_item(item : DomainExprTree) -> String {
  match item {
    DomainExprTree::Elem(expr) =>
      normalize_expr_text(@symprint.pretty_string(expr))
    DomainExprTree::List(items) => render_expr_tree(items)
  }
}

///|
fn render_expr_tree(items : Array[DomainExprTree]) -> String {
  let body = items.map(render_expr_tree_item).join(",")
  "[\{body}]"
}

///|
fn small_univar_poly_expr(
  poly_expr : String,
  gen : String,
) -> @symcore.Expr raise PolyError {
  let x = @symcore.Expr::Symbol(gen)
  match trim_ws(poly_expr) {
    "x-2" => x - @symcore.int(2)
    "x**2-2" => (x ^ @symcore.int(2)) - @symcore.int(2)
    "x**2+1" => (x ^ @symcore.int(2)) + @symcore.int(1)
    _ => raise PolyError::BadGenerator(poly_expr)
  }
}

///|
test "domains: basic constructor/repr parity" {
  let specs = [
    "ZZ", "QQ", "RR", "CC", "ZZ_I", "QQ_I", "EX", "EXRAW", "GF(7)", "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let domain = @sympolys.domain_from_string(spec)
    let ours = @sympolys.domain_to_sympy_string(domain)
    let oracle = domain_repr(spec)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }
}

///|
test "domains: polynomial/fraction descriptors parity" {
  let poly_domain = @sympolys.poly_ring_domain(Domain::ZZ, ["x", "y"])
  let frac_domain = @sympolys.rational_function_field_domain(Domain::QQ, [
    "x", "y",
  ])

  let poly_ours = @sympolys.domain_to_sympy_string(poly_domain)
  let frac_ours = @sympolys.domain_to_sympy_string(frac_domain)

  let poly_oracle = domain_repr("ZZ[x,y]")
  let frac_oracle = domain_repr("QQ(x,y)")

  assert_eq(trim_ws(poly_ours), trim_ws(poly_oracle))
  assert_eq(trim_ws(frac_ours), trim_ws(frac_oracle))
}

///|
test "domains: characteristic parity" {
  let cases = ["ZZ", "QQ", "GF(11)", "ZZ[x]", "QQ(x)"]
  for spec in cases {
    let domain = @sympolys.domain_from_string(spec)
    let ours = @sympolys.domain_characteristic(domain)
    let oracle = domain_characteristic(spec)
    assert_eq(ours, oracle)
  }
}

///|
test "domains: predicate parity (field/ring/exact/finite)" {
  let specs = ["ZZ", "QQ", "RR", "CC", "GF(7)", "ZZ[x]", "QQ(x)", "EX", "EXRAW"]
  for spec in specs {
    let domain = @sympolys.domain_from_string(spec)
    assert_eq(@sympolys.domain_is_field_pred(domain), domain_is_field(spec))
    assert_eq(@sympolys.domain_is_ring_pred(domain), domain_is_ring(spec))
    assert_eq(@sympolys.domain_is_exact_pred(domain), domain_is_exact(spec))
    assert_eq(
      @sympolys.domain_is_finite_pred(domain),
      domain_is_finite_field(spec),
    )
  }
}

///|
test "domains: get_field/get_ring parity" {
  let field_specs = [
    "ZZ", "QQ", "RR", "CC", "GF(7)", "ZZ[x]", "QQ(x)", "ZZ_I", "QQ_I", "EX", "QQ<sqrt(2)>",
  ]
  for spec in field_specs {
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_get_field(@sympolys.domain_from_string(spec)),
    )
    let oracle = domain_get_field(spec)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let ring_specs = [
    "QQ", "RR", "ZZ[x]", "QQ(x)", "ZZ(x)", "QQ_I", "ZZ_I", "EX", "CC", "GF(7)", "EXRAW",
    "QQ<sqrt(2)>",
  ]
  for spec in ring_specs {
    let ours = render_domain_action(fn() raise PolyError {
      @sympolys.domain_get_ring(@sympolys.domain_from_string(spec))
    })
    let oracle = domain_get_ring(spec)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }
}

///|
test "domains: unify parity for key coercion paths" {
  let pairs = [
    ("ZZ", "QQ"),
    ("QQ", "RR"),
    ("QQ", "CC"),
    ("ZZ", "CC"),
    ("EX", "QQ"),
    ("EXRAW", "QQ"),
    ("ZZ[x]", "QQ"),
    ("ZZ[x]", "QQ(y)"),
    ("QQ(x)", "ZZ[y]"),
    ("QQ(x)", "ZZ(y)"),
    ("ZZ[x]", "ZZ[y]"),
    ("QQ(x)", "QQ(y)"),
    ("ZZ_I", "QQ_I"),
    ("QQ<sqrt(2)>", "QQ"),
    ("QQ<sqrt(2)>", "RR"),
    ("QQ<sqrt(2)>", "CC"),
    ("QQ<sqrt(2)>", "EX"),
    ("QQ<sqrt(2)>", "EXRAW"),
    ("QQ<sqrt(2)>", "ZZ_I"),
    ("QQ<sqrt(2)>", "QQ_I"),
    ("QQ<sqrt(2)>", "QQ[x]"),
    ("QQ<sqrt(2)>", "QQ(x)"),
    ("QQ<sqrt(2)>", "RR[x]"),
    ("QQ<sqrt(2)>", "RR(x)"),
    ("QQ<sqrt(2)>", "ZZ_I[x]"),
    ("QQ<sqrt(2)>", "QQ_I[x]"),
    ("QQ<sqrt(2)>", "ZZ_I(x)"),
    ("QQ<sqrt(2)>", "QQ_I(x)"),
    ("QQ<sqrt(2)>", "QQ<sqrt(3)>"),
  ]
  for pair in pairs {
    let lhs = pair.0
    let rhs = pair.1
    let ours = @sympolys.domain_unify_pair(
      @sympolys.domain_from_string(lhs),
      @sympolys.domain_from_string(rhs),
    )
    let ours_text = @sympolys.domain_to_sympy_string(ours)
    let oracle = domain_unify(lhs, rhs)
    assert_eq(trim_ws(ours_text), trim_ws(oracle))
  }
}

///|
test "domains: extended predicate parity (module-level tags)" {
  let specs = [
    "ZZ", "QQ", "RR", "CC", "ZZ_I", "QQ_I", "EX", "EXRAW", "GF(7)", "ZZ[x]", "QQ(x)",
    "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let domain = @sympolys.domain_from_string(spec)
    assert_eq(
      @sympolys.domain_is_composite_pred(domain),
      domain_attr_bool_query(spec, "is_Composite"),
    )
    assert_eq(
      @sympolys.domain_is_simple_pred(domain),
      domain_attr_bool_query(spec, "is_Simple"),
    )
    assert_eq(
      @sympolys.domain_is_numerical_pred(domain),
      domain_attr_bool_query(spec, "is_Numerical"),
    )
    assert_eq(
      @sympolys.domain_has_assoc_ring_pred(domain),
      domain_attr_bool_query(spec, "has_assoc_Ring"),
    )
    assert_eq(
      @sympolys.domain_is_pid_pred(domain),
      domain_attr_bool_query(spec, "is_PID"),
    )
    assert_eq(
      @sympolys.domain_is_integer_ring_pred(domain),
      domain_attr_bool_query(spec, "is_IntegerRing"),
    )
    assert_eq(
      @sympolys.domain_is_rational_field_pred(domain),
      domain_attr_bool_query(spec, "is_RationalField"),
    )
    assert_eq(
      @sympolys.domain_is_real_field_pred(domain),
      domain_attr_bool_query(spec, "is_RealField"),
    )
    assert_eq(
      @sympolys.domain_is_complex_field_pred(domain),
      domain_attr_bool_query(spec, "is_ComplexField"),
    )
    assert_eq(
      @sympolys.domain_is_gaussian_ring_pred(domain),
      domain_attr_bool_query(spec, "is_GaussianRing"),
    )
    assert_eq(
      @sympolys.domain_is_gaussian_field_pred(domain),
      domain_attr_bool_query(spec, "is_GaussianField"),
    )
    assert_eq(
      @sympolys.domain_is_expression_domain_pred(domain),
      domain_attr_bool_query(spec, "is_EX"),
    )
    assert_eq(
      @sympolys.domain_is_expression_raw_domain_pred(domain),
      domain_attr_bool_query(spec, "is_EXRAW"),
    )
  }
}

///|
test "domains: advanced predicate parity (meta/family tags)" {
  let specs = [
    "ZZ", "QQ", "RR", "CC", "ZZ_I", "QQ_I", "EX", "EXRAW", "GF(7)", "ZZ[x]", "QQ(x)",
    "RR[x]", "CC[x]", "RR(x)", "CC(x)", "EX(x)", "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let domain = @sympolys.domain_from_string(spec)
    assert_eq(
      @sympolys.domain_is_algebraic_pred(domain),
      domain_attr_bool_query(spec, "is_Algebraic"),
    )
    assert_eq(
      @sympolys.domain_is_algebraic_field_pred(domain),
      domain_attr_bool_query(spec, "is_AlgebraicField"),
    )
    assert_eq(
      @sympolys.domain_is_symbolic_domain_pred(domain),
      domain_attr_bool_query(spec, "is_SymbolicDomain"),
    )
    assert_eq(
      @sympolys.domain_has_assoc_field_pred(domain),
      domain_attr_bool_query(spec, "has_assoc_Field"),
    )
    assert_eq(
      @sympolys.domain_has_characteristic_zero_pred(domain),
      domain_attr_bool_query(spec, "has_CharacteristicZero"),
    )
    assert_eq(
      @sympolys.domain_is_finite_extension_pred(domain),
      domain_attr_bool_query(spec, "is_FiniteExtension"),
    )
    assert_eq(
      @sympolys.domain_is_zz_pred(domain),
      domain_attr_bool_query(spec, "is_ZZ"),
    )
    assert_eq(
      @sympolys.domain_is_qq_pred(domain),
      domain_attr_bool_query(spec, "is_QQ"),
    )
    assert_eq(
      @sympolys.domain_is_zz_i_pred(domain),
      domain_attr_bool_query(spec, "is_ZZ_I"),
    )
    assert_eq(
      @sympolys.domain_is_qq_i_pred(domain),
      domain_attr_bool_query(spec, "is_QQ_I"),
    )
    assert_eq(
      @sympolys.domain_is_cc_pred(domain),
      domain_attr_bool_query(spec, "is_CC"),
    )
    assert_eq(
      @sympolys.domain_is_rr_pred(domain),
      domain_attr_bool_query(spec, "is_RR"),
    )
    assert_eq(
      @sympolys.domain_is_ff_pred(domain),
      domain_attr_bool_query(spec, "is_FF"),
    )
    assert_eq(
      @sympolys.domain_is_frac_pred(domain),
      domain_attr_bool_query(spec, "is_Frac"),
    )
    assert_eq(
      @sympolys.domain_is_fraction_field_pred(domain),
      domain_attr_bool_query(spec, "is_FractionField"),
    )
    assert_eq(
      @sympolys.domain_is_poly_pred(domain),
      domain_attr_bool_query(spec, "is_Poly"),
    )
    assert_eq(
      @sympolys.domain_is_polynomial_ring_pred(domain),
      domain_attr_bool_query(spec, "is_PolynomialRing"),
    )
    assert_eq(
      @sympolys.domain_is_symbolic_raw_domain_pred(domain),
      domain_attr_bool_query(spec, "is_SymbolicRawDomain"),
    )
    assert_eq(
      @sympolys.domain_has_default_precision_pred(domain),
      domain_attr_bool_or_false(spec, "has_default_precision"),
    )
  }
}

///|
test "domains: get_exact parity across core/coercion domains" {
  let specs = [
    "ZZ", "QQ", "RR", "CC", "ZZ_I", "QQ_I", "EX", "EXRAW", "GF(7)", "ZZ[x]", "RR[x]",
    "CC[x]", "QQ(x)", "RR(x)", "CC(x)", "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_get_exact(@sympolys.domain_from_string(spec)),
    )
    let oracle = domain_get_exact(spec)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }
}

///|
test "domains: alias constructors and parser coverage" {
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("IntegerRing"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.integer_ring_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("RationalField"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.rational_field_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(@sympolys.domain_from_string("RealField")),
    @sympolys.domain_to_sympy_string(@sympolys.real_field_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("ComplexField"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.complex_field_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("GaussianIntegerRing"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.gaussian_integer_ring_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("GaussianRationalField"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.gaussian_rational_field_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("ExpressionDomain"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.expression_domain()),
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("ExpressionRawDomain"),
    ),
    @sympolys.domain_to_sympy_string(@sympolys.expression_raw_domain()),
  )
  let ff7 = @sympolys.ff_domain(7)
  assert_eq(
    @sympolys.domain_to_sympy_string(@sympolys.domain_from_string("FF(7)")),
    @sympolys.domain_to_sympy_string(ff7),
  )
  let ff11 = @sympolys.finite_field_domain(11)
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("FiniteField(11)"),
    ),
    @sympolys.domain_to_sympy_string(ff11),
  )
  let gfext = @sympolys.domain_from_string("GF(5,2)")
  assert_eq(@sympolys.domain_to_sympy_string(gfext), "GF(5**2)")
  let gfext_ff = @sympolys.domain_from_string("FF(7,3)")
  assert_eq(@sympolys.domain_to_sympy_string(gfext_ff), "GF(7**3)")
}

///|
test "domains: extended parser handles Frac/GFExt/PowerSeries syntax" {
  let frac = @sympolys.domain_from_string("Frac(ZZ[x])")
  assert_eq(@sympolys.domain_to_sympy_string(frac), "Frac(ZZ[x])")
  let gfext_pow = @sympolys.domain_from_string("GF(5**2)")
  assert_eq(@sympolys.domain_to_sympy_string(gfext_pow), "GF(5**2)")
  let ps = @sympolys.domain_from_string("QQ[[x,y]]")
  assert_eq(@sympolys.domain_to_sympy_string(ps), "QQ[[x,y]]")
  let ps_prec = @sympolys.domain_from_string("RR[[t]](prec=7)")
  assert_eq(@sympolys.domain_to_sympy_string(ps_prec), "RR[[t]](prec=7)")
}

///|
test "domains: oracle GF descriptor parser handles extension forms" {
  let gf_pow = domain_repr("GF(5**2)")
  let gf_flat = domain_repr("GF(25)")
  assert_eq(trim_ws(gf_pow), trim_ws(gf_flat))

  let ff_pair = domain_repr("FF(7,3)")
  let ff_flat = domain_repr("GF(343)")
  assert_eq(trim_ws(ff_pair), trim_ws(ff_flat))
}

///|
test "domains: nested composite parser handles recursive suffix forms" {
  let cases = ["ZZ[x][y]", "QQ(x)[y]", "ZZ[x](y)", "QQ(x)(y)"]
  for spec in cases {
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec),
    )
    let oracle = domain_repr(spec)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }
}

///|
test "domains: method constructor parity for poly/frac old/new rings" {
  let cases = [
    ("ZZ", ["x"]),
    ("QQ", ["x", "y"]),
    ("ZZ[x]", ["y"]),
    ("QQ(x)", ["y"]),
    ("ZZ[x][y]", ["z"]),
  ]
  for item in cases {
    let spec = item.0
    let gens = item.1
    let domain = @sympolys.domain_from_string(spec)

    let poly_ours = @sympolys.domain_to_sympy_string(domain.poly_ring(gens))
    let poly_oracle = domain_poly_ring(spec, gens)
    assert_eq(trim_ws(poly_ours), trim_ws(poly_oracle))

    let frac_ours = @sympolys.domain_to_sympy_string(domain.frac_field(gens))
    let frac_oracle = domain_frac_field(spec, gens)
    assert_eq(trim_ws(frac_ours), trim_ws(frac_oracle))

    let old_poly_ours = @sympolys.domain_to_sympy_string(
      domain.old_poly_ring(gens),
    )
    let old_poly_oracle = domain_old_poly_ring(spec, gens)
    assert_eq(trim_ws(old_poly_ours), trim_ws(old_poly_oracle))

    let old_frac_ours = @sympolys.domain_to_sympy_string(
      domain.old_frac_field(gens),
    )
    let old_frac_oracle = domain_old_frac_field(spec, gens)
    assert_eq(trim_ws(old_frac_ours), trim_ws(old_frac_oracle))
  }

  let quotient = @sympolys.quotient_ring_domain(Domain::QQ, ["x"], [
    @symcore.add([
      @symcore.pow(@symcore.Expr::Symbol("x"), @symcore.int(2)),
      @symcore.int(1),
    ]),
  ])
  assert_eq(
    render_domain_action(fn() raise PolyError { quotient.poly_ring(["y"]) }),
    "ERROR",
  )
}

///|
test "domains: set_domain and unify_with_symbols parity" {
  let set_cases = [
    ("ZZ[x]", "QQ"),
    ("RR[x,y]", "ZZ_I"),
    ("QQ(x)", "CC"),
    ("ZZ[x][y]", "QQ"),
  ]
  for item in set_cases {
    let spec = item.0
    let ground = item.1
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec).set_domain(
        @sympolys.domain_from_string(ground),
      ),
    )
    let oracle = domain_set_domain(spec, ground)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let unify_cases = [
    ("ZZ[x]", "QQ", ["y", "z"]),
    ("ZZ[x][y]", "QQ(z)", ["t"]),
    ("ZZ[x,y]", "ZZ", ["y", "z"]),
  ]
  for item in unify_cases {
    let lhs = item.0
    let rhs = item.1
    let symbols = item.2
    let ours = render_domain_action(fn() raise PolyError {
      @sympolys.domain_from_string(lhs).unify_with_symbols(
        @sympolys.domain_from_string(rhs),
        symbols,
      )
    })
    let oracle = domain_unify_with_symbols(lhs, rhs, symbols)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let composite_cases = [
    ("ZZ[x]", "QQ"),
    ("ZZ[x]", "QQ(y)"),
    ("ZZ(x)", "QQ[x]"),
  ]
  for item in composite_cases {
    let lhs = item.0
    let rhs = item.1
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(lhs).unify_composite(
        @sympolys.domain_from_string(rhs),
      ),
    )
    let oracle = domain_unify_composite(lhs, rhs)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }
}

///|
test "domains: inject and drop parity across simple and nested composites" {
  let inject_cases = [
    ("ZZ", ["x", "y"]),
    ("ZZ[x]", ["y", "z"]),
    ("QQ(x)", ["y"]),
  ]
  for item in inject_cases {
    let spec = item.0
    let gens = item.1
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec).inject(gens),
    )
    let oracle = domain_inject(spec, gens)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  assert_eq(
    render_domain_action(fn() raise PolyError {
      @sympolys.domain_from_string("ZZ[x]").inject(["x"])
    }),
    "ERROR",
  )

  let drop_cases = [
    ("ZZ", ["x"]),
    ("ZZ[x]", ["x"]),
    ("ZZ[x,y]", ["x"]),
    ("ZZ(x)", ["x"]),
    ("ZZ(x,y)", ["x"]),
    ("ZZ[x][y]", ["x"]),
    ("ZZ(x)[y]", ["x"]),
    ("QQ<sqrt(2)>", ["x"]),
  ]
  for item in drop_cases {
    let spec = item.0
    let gens = item.1
    let ours = render_domain_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).drop(gens)
    })
    let oracle = domain_drop(spec, gens)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }
}

///|
test "domains: algebraic_field parity and Domain methods" {
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let sqrt3 = @symcore.function("sqrt", [@symcore.int(3)])
  let x = @symcore.Expr::Symbol("x")
  let cases = [
    ("QQ", [sqrt2], ["sqrt(2)"]),
    ("ZZ", [sqrt2], ["sqrt(2)"]),
    ("QQ<sqrt(2)>", [sqrt3], ["sqrt(3)"]),
  ]
  for item in cases {
    let spec = item.0
    let ext_exprs = item.1
    let ext_specs = item.2
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec).algebraic_field(ext_exprs),
    )
    let oracle = domain_algebraic_field(spec, ext_specs)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let poly_cases : Array[(String, String, String, String)] = [
    ("QQ", "x**2 - 2", "x", "a"),
    ("ZZ", "x**2 + 1", "x", "i"),
  ]
  for item in poly_cases {
    let spec = item.0
    let poly_expr = item.1
    let gen = item.2
    let ext_alias = item.3
    let poly = Poly::from_expr(
      small_univar_poly_expr(poly_expr, gen),
      [gen],
      @sympolys.domain_from_string(spec),
    )
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec).alg_field_from_poly(
        poly,
        extension_name=Some(ext_alias),
      ),
    )
    let oracle = domain_alg_field_from_poly(
      spec,
      poly_expr,
      gen,
      extension_name=Some(ext_alias),
    )
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let poly_root_cases : Array[(String, String, String, Int)] = [
    ("QQ", "x**2 - 2", "x", -1),
    ("QQ", "x**2 - 2", "x", 0),
    ("QQ", "x**2 - 2", "x", -2),
    ("QQ", "x - 2", "x", -1),
  ]
  for item in poly_root_cases {
    let spec = item.0
    let poly_expr = item.1
    let gen = item.2
    let root_index = item.3
    let poly = Poly::from_expr(
      small_univar_poly_expr(poly_expr, gen),
      [gen],
      @sympolys.domain_from_string(spec),
    )
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec).alg_field_from_poly(poly, root_index~),
    )
    let oracle = domain_alg_field_from_poly(spec, poly_expr, gen, root_index~)
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let direct_alg_field = @sympolys.domain_from_string("QQ").alg_field_from_poly(
    Poly::from_expr((x ^ @symcore.int(2)) - @symcore.int(2), ["x"], Domain::QQ),
    extension_name=Some("a"),
  )
  match direct_alg_field {
    Domain::AlgExt(_, gens, rels) => {
      assert_true(gens.equal(["a"]))
      assert_eq(normalize_expr_text(@symprint.pretty_string(rels[0])), "a**2-2")
    }
    _ => fail("expected AlgExt from alg_field_from_poly")
  }

  let cyclo_cases = [
    ("QQ", 5, false, "zeta", Some("t")),
    ("QQ", 7, true, "zeta", None),
    ("ZZ", 3, false, "w", None),
  ]
  for item in cyclo_cases {
    let spec = item.0
    let n = item.1
    let ss = item.2
    let ext_alias = item.3
    let gen_opt = item.4
    let ours = @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string(spec).cyclotomic_field(
        n,
        ss~,
        extension_name=ext_alias,
        gen=gen_opt,
      ),
    )
    let oracle = domain_cyclotomic_field(
      spec,
      n,
      ss~,
      extension_name=ext_alias,
      gen=gen_opt,
    )
    assert_eq(trim_ws(ours), trim_ws(oracle))
  }

  let direct_cyclo = @sympolys.domain_from_string("QQ").cyclotomic_field(
    5,
    extension_name="a",
    gen=Some("t"),
  )
  match direct_cyclo {
    Domain::AlgExt(_, gens, rels) => {
      assert_true(gens.equal(["a"]))
      assert_eq(
        normalize_expr_text(@symprint.pretty_string(rels[0])),
        "a**4+a**3+a**2+a+1",
      )
    }
    _ => fail("expected AlgExt from cyclotomic_field")
  }

  assert_eq(@sympolys.domain_from_string("GF(5)").characteristic(), 5)
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("RR[x]").get_exact(),
    ),
    "QQ[x]",
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("ZZ[x]").get_field(),
    ),
    "ZZ(x)",
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("QQ(x)").get_ring(),
    ),
    "QQ[x]",
  )
  assert_eq(
    @sympolys.domain_to_sympy_string(
      @sympolys.domain_from_string("ZZ").unify(
        @sympolys.domain_from_string("QQ"),
      ),
    ),
    "QQ",
  )
}

///|
test "domains: contains_expr parity for constants polynomials and rational functions" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let sin1 = @symcore.function("sin", [@symcore.int(1)])
  let inv_x = @symcore.pow(x, @symcore.int(-1))

  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(3), "3"),
    ("ZZ", @symcore.rational_from_ints(3, 2), "3/2"),
    ("QQ", @symcore.rational_from_ints(3, 2), "3/2"),
    ("RR", sqrt2, "sqrt(2)"),
    ("CC", i, "I"),
    ("QQ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    (
      "QQ<sqrt(2)>",
      @symcore.add([@symcore.int(1), @symcore.int(2) * sqrt2]),
      "1 + 2*sqrt(2)",
    ),
    ("QQ<sqrt(2)>", @symcore.function("sqrt", [@symcore.int(3)]), "sqrt(3)"),
    ("ZZ[x]", (x ^ @symcore.int(2)) + @symcore.int(1), "x**2 + 1"),
    ("ZZ[x]", (x ^ @symcore.int(2)) + (y ^ @symcore.int(2)), "x**2 + y**2"),
    ("QQ(x)", inv_x, "1/x"),
    ("QQ(1/x,y)", x + y, "x + y"),
    ("QQ(1/x)", @symcore.rational_from_ints(2, 3) * x, "2*x/3"),
    ("QQ[x]", inv_x, "1/x"),
    ("QQ[x][y]", x + y, "x + y"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = @sympolys.domain_from_string(spec).contains_expr(expr)
    let oracle = domain_contains_expr(spec, expr_text)
    assert_eq(ours, oracle)
  }

  assert_true(@sympolys.domain_from_string("RR").contains_expr(sin1))
}

///|
test "domains: from_sympy/to_sympy/convert_from parity on scalar and composite domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let conversion_cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(7), "7"),
    ("QQ", @symcore.rational_from_ints(6, 8), "6/8"),
    ("GF(5)", @symcore.int(7), "7"),
    (
      "QQ_I",
      @symcore.add([
        @symcore.rational_from_ints(1, 2),
        @symcore.rational_from_ints(1, 3) * i,
      ]),
      "1/2 + I/3",
    ),
    ("QQ<sqrt(2)>", @symcore.add([@symcore.int(1), sqrt2]), "1 + sqrt(2)"),
    (
      "ZZ[x]",
      (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
      "x**2 + 2*x + 1",
    ),
    (
      "QQ(x)",
      ((x ^ @symcore.int(2)) - @symcore.int(1)) *
      ((x - @symcore.int(1)) ^ @symcore.int(-1)),
      "(x**2 - 1)/(x - 1)",
    ),
  ]
  for item in conversion_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = @sympolys.domain_from_string(spec)
    let ours_from = render_expr_action(fn() raise PolyError {
      domain.from_sympy_expr(expr)
    })
    let oracle_from = normalize_expr_text(
      domain_from_sympy_expr(spec, expr_text),
    )
    assert_eq(ours_from, oracle_from)
    let ours_to = render_expr_action(fn() raise PolyError {
      domain.to_sympy_expr(expr)
    })
    let oracle_to = normalize_expr_text(domain_to_sympy_expr(spec, expr_text))
    assert_eq(ours_to, oracle_to)
  }

  let convert_cases : Array[(String, String, @symcore.Expr, String)] = [
    ("QQ", "ZZ", @symcore.int(7), "7"),
    ("ZZ", "QQ", @symcore.int(4), "4"),
    ("ZZ", "QQ", @symcore.rational_from_ints(1, 2), "1/2"),
    ("QQ_I", "ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("QQ[x]", "ZZ[x]", x + @symcore.int(1), "x + 1"),
    ("ZZ[x]", "QQ[x]", @symcore.int(2) * x + @symcore.int(1), "2*x + 1"),
    ("ZZ[x]", "QQ[x]", @symcore.rational_from_ints(1, 2) * x, "x/2"),
    ("QQ(x)", "ZZ[x]", (x ^ @symcore.int(2)) + @symcore.int(1), "x**2 + 1"),
    ("QQ[x]", "QQ(x)", x + @symcore.int(1), "x + 1"),
    ("QQ<sqrt(2)>", "QQ", @symcore.rational_from_ints(3, 2), "3/2"),
    ("QQ", "QQ(x)", @symcore.int(2), "2"),
    ("QQ<sqrt(2)>", "QQ(x)", @symcore.int(2), "2"),
  ]
  for item in convert_cases {
    let target = item.0
    let base = item.1
    let expr = item.2
    let expr_text = item.3
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(target).convert_from_expr(
        expr,
        @sympolys.domain_from_string(base),
      )
    })
    let oracle = normalize_expr_text(
      domain_convert_from_expr(target, expr_text, base),
    )
    assert_eq(ours, oracle)
  }

  let direct_cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(2), "2"),
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("GF(5)", @symcore.int(7), "7"),
    ("ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("QQ[x]", x + @symcore.int(1), "x + 1"),
  ]
  for item in direct_cases {
    let target = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(target).convert_expr(expr)
    })
    let oracle = normalize_expr_text(domain_convert_expr(target, expr_text))
    assert_eq(ours, oracle)
  }
}

///|
test "domains: sum_expr parity on scalar and gaussian domains" {
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let cases : Array[(String, Array[@symcore.Expr], Array[String])] = [
    ("ZZ", [@symcore.int(1), @symcore.int(2), @symcore.int(3)], ["1", "2", "3"]),
    (
      "QQ",
      [
        @symcore.rational_from_ints(1, 2),
        @symcore.rational_from_ints(1, 3),
        @symcore.rational_from_ints(1, 6),
      ],
      ["1/2", "1/3", "1/6"],
    ),
    (
      "QQ_I",
      [@symcore.int(1) + i, @symcore.int(2) + @symcore.int(-1) * i],
      ["1 + I", "2 - I"],
    ),
    ("GF(5)", [@symcore.int(4), @symcore.int(4)], ["4", "4"]),
  ]
  for item in cases {
    let spec = item.0
    let exprs = item.1
    let expr_texts = item.2
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).sum_expr(exprs)
    })
    let oracle = normalize_expr_text(domain_sum_expr(spec, expr_texts))
    assert_eq(ours, oracle)
  }
}

///|
test "domains: from_* conversion hook parity on representative base families" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, String, @symcore.Expr, String, String)] = [
    ("from_ff", "ZZ", @symcore.int(3), "GF(5)", "3"),
    ("from_real_field", "QQ", @symcore.int(2), "RR", "2"),
    (
      "from_complex_field",
      "QQ_I",
      @symcore.add([@symcore.int(1), @symcore.int(2) * i]),
      "CC",
      "1 + 2*I",
    ),
    (
      "from_algebraic_field",
      "QQ",
      @symcore.rational_from_ints(3, 2),
      "QQ<sqrt(2)>",
      "3/2",
    ),
    ("from_polynomial_ring", "QQ", @symcore.int(2), "QQ[x]", "2"),
    ("from_polynomial_ring", "QQ", x + @symcore.int(1), "QQ[x]", "x + 1"),
    ("from_fraction_field", "QQ", @symcore.int(2), "QQ(x)", "2"),
    (
      "from_expression_domain",
      "QQ",
      @symcore.rational_from_ints(1, 2),
      "EX",
      "1/2",
    ),
    (
      "from_expression_raw_domain",
      "QQ",
      @symcore.rational_from_ints(1, 2),
      "EXRAW",
      "1/2",
    ),
  ]
  for item in cases {
    let family = item.0
    let target = item.1
    let expr = item.2
    let base = item.3
    let expr_text = item.4
    let target_domain = @sympolys.domain_from_string(target)
    let base_domain = @sympolys.domain_from_string(base)
    let ours = match family {
      "from_ff" =>
        render_optional_expr_result(
          Ok(target_domain.from_ff_expr(expr, base_domain)),
        )
      "from_real_field" =>
        render_optional_expr_result(
          Ok(target_domain.from_real_field_expr(expr, base_domain)),
        )
      "from_complex_field" =>
        render_optional_expr_result(
          Ok(target_domain.from_complex_field_expr(expr, base_domain)),
        )
      "from_algebraic_field" =>
        render_optional_expr_result(
          Ok(target_domain.from_algebraic_field_expr(expr, base_domain)),
        )
      "from_polynomial_ring" =>
        render_optional_expr_result(
          Ok(target_domain.from_polynomial_ring_expr(expr, base_domain)),
        )
      "from_fraction_field" =>
        render_optional_expr_result(
          Ok(target_domain.from_fraction_field_expr(expr, base_domain)),
        )
      "from_expression_domain" =>
        render_optional_expr_result(
          Ok(target_domain.from_expression_domain_expr(expr, base_domain)),
        )
      "from_expression_raw_domain" =>
        render_optional_expr_result(
          Ok(target_domain.from_expression_raw_domain_expr(expr, base_domain)),
        )
      _ => "ERROR"
    }
    let oracle = match family {
      "from_ff" =>
        normalize_expr_text(domain_from_ff_expr(target, expr_text, base))
      "from_real_field" =>
        normalize_expr_text(
          domain_from_real_field_expr(target, expr_text, base),
        )
      "from_complex_field" =>
        normalize_expr_text(
          domain_from_complex_field_expr(target, expr_text, base),
        )
      "from_algebraic_field" =>
        normalize_expr_text(
          domain_from_algebraic_field_expr(target, expr_text, base),
        )
      "from_polynomial_ring" =>
        normalize_expr_text(
          domain_from_polynomial_ring_expr(target, expr_text, base),
        )
      "from_fraction_field" =>
        normalize_expr_text(
          domain_from_fraction_field_expr(target, expr_text, base),
        )
      "from_expression_domain" =>
        normalize_expr_text(
          domain_from_expression_domain_expr(target, expr_text, base),
        )
      "from_expression_raw_domain" =>
        normalize_expr_text(
          domain_from_expression_raw_domain_expr(target, expr_text, base),
        )
      _ => "ERROR"
    }
    assert_eq(ours, oracle)
  }

  assert_eq(
    render_optional_expr_result(
      Ok(
        @sympolys.domain_from_string("QQ").from_fraction_field_expr(
          @symcore.int(2),
          @sympolys.domain_from_string("QQ(x)"),
        ),
      ),
    ),
    "NONE",
  )
  ignore(sqrt2)
}

///|
test "domains: extended conversion hook parity for ground, gaussian, and legacy-ring families" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let half = @symcore.rational_from_ints(1, 2)
  let cases : Array[(String, String, @symcore.Expr, String, String, String)] = [
    ("from_zz", "QQ", @symcore.int(2), "ZZ", "ZZ", "2"),
    ("from_zz_python", "QQ", @symcore.int(2), "ZZ", "ZZ", "2"),
    ("from_zz_gmpy", "QQ", @symcore.int(2), "ZZ", "ZZ", "2"),
    ("from_qq", "QQ_I", half, "QQ", "QQ", "1/2"),
    ("from_qq_python", "QQ_I", half, "QQ", "QQ", "1/2"),
    ("from_qq_gmpy", "QQ_I", half, "QQ", "QQ", "1/2"),
    ("from_ff_python", "ZZ", @symcore.int(3), "GF(5)", "GF(5)", "3"),
    ("from_ff_gmpy", "ZZ", @symcore.int(3), "GF(5)", "GF(5)", "3"),
    (
      "from_gaussian_integer_ring",
      "QQ_I",
      @symcore.add([@symcore.int(1), @symcore.int(2) * i]),
      "ZZ_I",
      "ZZ_I",
      "1 + 2*I",
    ),
    ("from_gaussian_rational_field", "QQ", @symcore.int(2), "QQ_I", "QQ_I", "2"),
    (
      "from_global_polynomial_ring",
      "QQ",
      @symcore.int(2),
      "QQ[x]",
      "QQ.old_poly_ring(x)",
      "2",
    ),
    (
      "from_generalized_polynomial_ring",
      "EX",
      x * (y ^ @symcore.int(-1)),
      "QQ(x,y)",
      "QQ.old_frac_field(x,y)",
      "x/y",
    ),
  ]
  for item in cases {
    let family = item.0
    let target = item.1
    let expr = item.2
    let local_base = item.3
    let oracle_base = item.4
    let expr_text = item.5
    let target_domain = @sympolys.domain_from_string(target)
    let base_domain = @sympolys.domain_from_string(local_base)
    let ours = match family {
      "from_zz" =>
        render_optional_expr_result(
          Ok(target_domain.from_zz_expr(expr, base_domain)),
        )
      "from_zz_python" =>
        render_optional_expr_result(
          Ok(target_domain.from_zz_python_expr(expr, base_domain)),
        )
      "from_zz_gmpy" =>
        render_optional_expr_result(
          Ok(target_domain.from_zz_gmpy_expr(expr, base_domain)),
        )
      "from_qq" =>
        render_optional_expr_result(
          Ok(target_domain.from_qq_expr(expr, base_domain)),
        )
      "from_qq_python" =>
        render_optional_expr_result(
          Ok(target_domain.from_qq_python_expr(expr, base_domain)),
        )
      "from_qq_gmpy" =>
        render_optional_expr_result(
          Ok(target_domain.from_qq_gmpy_expr(expr, base_domain)),
        )
      "from_ff_python" =>
        render_optional_expr_result(
          Ok(target_domain.from_ff_python_expr(expr, base_domain)),
        )
      "from_ff_gmpy" =>
        render_optional_expr_result(
          Ok(target_domain.from_ff_gmpy_expr(expr, base_domain)),
        )
      "from_gaussian_integer_ring" =>
        render_optional_expr_result(
          Ok(target_domain.from_gaussian_integer_ring_expr(expr, base_domain)),
        )
      "from_gaussian_rational_field" =>
        render_optional_expr_result(
          Ok(target_domain.from_gaussian_rational_field_expr(expr, base_domain)),
        )
      "from_global_polynomial_ring" =>
        render_optional_expr_result(
          Ok(target_domain.from_global_polynomial_ring_expr(expr, base_domain)),
        )
      "from_generalized_polynomial_ring" =>
        render_optional_expr_result(
          Ok(
            target_domain.from_generalized_polynomial_ring_expr(
              expr, base_domain,
            ),
          ),
        )
      _ => "ERROR"
    }
    let oracle = match family {
      "from_zz" =>
        normalize_expr_text(domain_from_zz_expr(target, expr_text, oracle_base))
      "from_zz_python" =>
        normalize_expr_text(
          domain_from_zz_python_expr(target, expr_text, oracle_base),
        )
      "from_zz_gmpy" =>
        normalize_expr_text(
          domain_from_zz_gmpy_expr(target, expr_text, oracle_base),
        )
      "from_qq" =>
        normalize_expr_text(domain_from_qq_expr(target, expr_text, oracle_base))
      "from_qq_python" =>
        normalize_expr_text(
          domain_from_qq_python_expr(target, expr_text, oracle_base),
        )
      "from_qq_gmpy" =>
        normalize_expr_text(
          domain_from_qq_gmpy_expr(target, expr_text, oracle_base),
        )
      "from_ff_python" =>
        normalize_expr_text(
          domain_from_ff_python_expr(target, expr_text, oracle_base),
        )
      "from_ff_gmpy" =>
        normalize_expr_text(
          domain_from_ff_gmpy_expr(target, expr_text, oracle_base),
        )
      "from_gaussian_integer_ring" =>
        normalize_expr_text(
          domain_from_gaussian_integer_ring_expr(target, expr_text, oracle_base),
        )
      "from_gaussian_rational_field" =>
        normalize_expr_text(
          domain_from_gaussian_rational_field_expr(
            target, expr_text, oracle_base,
          ),
        )
      "from_global_polynomial_ring" =>
        normalize_expr_text(
          domain_from_global_polynomial_ring_expr(
            target, expr_text, oracle_base,
          ),
        )
      "from_generalized_polynomial_ring" =>
        normalize_expr_text(
          domain_from_generalized_polynomial_ring_expr(
            target, expr_text, oracle_base,
          ),
        )
      _ => "ERROR"
    }
    assert_eq(ours, oracle)
  }

  assert_eq(
    render_optional_expr_result(
      Ok(
        @sympolys.domain_from_string("QQ").from_global_polynomial_ring_expr(
          x + @symcore.int(1),
          @sympolys.domain_from_string("QQ[x]"),
        ),
      ),
    ),
    "NONE",
  )
  assert_eq(
    render_optional_expr_result(
      Ok(
        @sympolys.domain_from_string("QQ").from_monogenic_finite_extension_expr(
          @symcore.int(2),
          @sympolys.domain_from_string("QQ<sqrt(2)>"),
        ),
      ),
    ),
    "2",
  )
}

///|
test "domains: new/normal constructors and recursive map stay normalized" {
  let x = @symcore.Expr::Symbol("x")
  let gf = @sympolys.domain_from_string("GF(5)")
  assert_eq(
    render_expr_action(fn() raise PolyError { gf.new_expr(@symcore.int(7)) }),
    "2",
  )
  assert_eq(
    render_expr_action(fn() raise PolyError { gf.normal_expr(@symcore.int(12)) }),
    "2",
  )
  assert_eq(
    render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string("QQ[x]").new_expr(x + @symcore.int(1))
    }),
    "x+1",
  )

  let mapped = gf.map_expr_tree([
    @sympolys.domain_expr_tree_elem(@symcore.int(6)),
    @sympolys.domain_expr_tree_list([
      @sympolys.domain_expr_tree_elem(@symcore.int(7)),
      @sympolys.domain_expr_tree_elem(@symcore.int(10)),
    ]),
  ])
  assert_eq(render_expr_tree(mapped), "[1,[2,0]]")

  let zz_mapped = @sympolys.domain_from_string("ZZ").map_expr_tree([
    @sympolys.domain_expr_tree_list([
      @sympolys.domain_expr_tree_elem(@symcore.int(1)),
      @sympolys.domain_expr_tree_elem(@symcore.int(2)),
    ]),
  ])
  assert_eq(render_expr_tree(zz_mapped), "[[1,2]]")
}

///|
test "domains: is_unit/is_zero/is_one parity on core domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-1), "-1"),
    ("ZZ", @symcore.int(2), "2"),
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("QQ", @symcore.int(0), "0"),
    ("ZZ[x]", @symcore.int(1), "1"),
    ("ZZ[x]", x, "x"),
    ("QQ[x]", @symcore.rational_from_ints(2, 3), "2/3"),
    ("QQ[x]", x, "x"),
    ("QQ(x)", x, "x"),
    ("QQ(x)", @symcore.int(0), "0"),
    ("ZZ_I", i, "I"),
    ("ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("QQ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("QQ<sqrt(2)>", @symcore.add([@symcore.int(1), sqrt2]), "1 + sqrt(2)"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = @sympolys.domain_from_string(spec).is_unit_expr(expr)
    let oracle = domain_is_unit_expr(spec, expr_text)
    assert_eq(ours, oracle)
  }

  assert_true(@sympolys.domain_from_string("QQ").is_zero_expr(@symcore.int(0)))
  assert_true(@sympolys.domain_from_string("QQ").is_one_expr(@symcore.int(1)))
  assert_true(!@sympolys.domain_from_string("QQ").is_one_expr(@symcore.int(2)))
}

///|
test "domains: zero/one and arithmetic wrapper parity" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let zero_one_specs = [
    "ZZ", "QQ", "GF(5)", "QQ_I", "ZZ[x]", "QQ(x)", "QQ<sqrt(2)>",
  ]
  for spec in zero_one_specs {
    let domain = @sympolys.domain_from_string(spec)
    let ours_zero = render_expr_action(fn() raise PolyError {
      domain.zero_expr()
    })
    let oracle_zero = normalize_expr_text(domain_zero_expr(spec))
    assert_eq(ours_zero, oracle_zero)
    let ours_one = render_expr_action(fn() raise PolyError { domain.one_expr() })
    let oracle_one = normalize_expr_text(domain_one_expr(spec))
    assert_eq(ours_one, oracle_one)
  }

  let unary_cases : Array[(String, @symcore.Expr, String)] = [
    ("GF(5)", @symcore.int(7), "7"),
    ("QQ_I", @symcore.add([@symcore.int(1), i]), "1 + I"),
    ("QQ(x)", (x + @symcore.int(1)) * (x ^ @symcore.int(-1)), "(x + 1)/x"),
  ]
  for item in unary_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = @sympolys.domain_from_string(spec)
    let ours_pos = render_expr_action(fn() raise PolyError {
      domain.pos_expr(expr)
    })
    let oracle_pos = normalize_expr_text(domain_pos_expr(spec, expr_text))
    assert_eq(ours_pos, oracle_pos)
    let ours_neg = render_expr_action(fn() raise PolyError {
      domain.neg_expr(expr)
    })
    let oracle_neg = normalize_expr_text(domain_neg_expr(spec, expr_text))
    assert_eq(ours_neg, oracle_neg)
  }

  let binary_cases : Array[
    (String, @symcore.Expr, @symcore.Expr, String, String),
  ] = [
    (
      "QQ",
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(1, 3),
      "1/2",
      "1/3",
    ),
    (
      "ZZ_I",
      @symcore.add([@symcore.int(2), i]),
      @symcore.add([@symcore.int(1), @symcore.int(-1) * i]),
      "2 + I",
      "1 - I",
    ),
    (
      "QQ(x)",
      (x + @symcore.int(1)) * ((x - @symcore.int(1)) ^ @symcore.int(-1)),
      x - @symcore.int(1),
      "(x + 1)/(x - 1)",
      "x - 1",
    ),
    ("ZZ[x]", x + @symcore.int(1), x - @symcore.int(1), "x + 1", "x - 1"),
  ]
  for item in binary_cases {
    let spec = item.0
    let left = item.1
    let right = item.2
    let left_text = item.3
    let right_text = item.4
    let domain = @sympolys.domain_from_string(spec)
    let ours_add = render_expr_action(fn() raise PolyError {
      domain.add_expr(left, right)
    })
    let oracle_add = normalize_expr_text(
      domain_add_expr(spec, left_text, right_text),
    )
    assert_eq(ours_add, oracle_add)
    let ours_sub = render_expr_action(fn() raise PolyError {
      domain.sub_expr(left, right)
    })
    let oracle_sub = normalize_expr_text(
      domain_sub_expr(spec, left_text, right_text),
    )
    assert_eq(ours_sub, oracle_sub)
    let ours_mul = render_expr_action(fn() raise PolyError {
      domain.mul_expr(left, right)
    })
    let oracle_mul = normalize_expr_text(
      domain_mul_expr(spec, left_text, right_text),
    )
    assert_eq(ours_mul, oracle_mul)
  }

  let pow_cases : Array[(String, @symcore.Expr, Int, String)] = [
    ("QQ", @symcore.rational_from_ints(2, 3), 3, "2/3"),
    ("QQ", @symcore.rational_from_ints(2, 3), -2, "2/3"),
    ("GF(5)", @symcore.int(2), -1, "2"),
    ("QQ_I", @symcore.add([@symcore.int(1), i]), 2, "1 + I"),
    ("QQ(x)", (x + @symcore.int(1)) * (x ^ @symcore.int(-1)), -1, "(x + 1)/x"),
    ("ZZ[x]", x + @symcore.int(1), 2, "x + 1"),
  ]
  for item in pow_cases {
    let spec = item.0
    let expr = item.1
    let exp = item.2
    let expr_text = item.3
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).pow_expr(expr, exp)
    })
    let oracle = normalize_expr_text(domain_pow_expr(spec, expr_text, exp))
    assert_eq(ours, oracle)
  }
}

///|
test "domains: gcdex/invert/revert wrapper parity" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let gcdex_cases : Array[
    (String, @symcore.Expr, @symcore.Expr, String, String),
  ] = [("ZZ", @symcore.int(6), @symcore.int(15), "6", "15")]
  for item in gcdex_cases {
    let spec = item.0
    let left = item.1
    let right = item.2
    let left_text = item.3
    let right_text = item.4
    let domain = @sympolys.domain_from_string(spec)
    let ours_half = render_expr_pair_action(fn() raise PolyError {
      domain.half_gcdex_expr(left, right)
    })
    let oracle_half = normalize_expr_tuple2_text(
      domain_half_gcdex_expr(spec, left_text, right_text),
    )
    assert_eq(ours_half, oracle_half)
    let ours_full = render_expr_triple_action(fn() raise PolyError {
      domain.gcdex_expr(left, right)
    })
    let oracle_full = normalize_expr_tuple3_text(
      domain_gcdex_expr(spec, left_text, right_text),
    )
    assert_eq(ours_full, oracle_full)
  }

  let qq_left = @symcore.rational_from_ints(2, 3)
  let qq_right = @symcore.rational_from_ints(4, 9)
  assert_eq(
    render_expr_pair_action(fn() raise PolyError {
      @sympolys.domain_from_string("QQ").half_gcdex_expr(qq_left, qq_right)
    }),
    "(1/3,2/9)",
  )
  assert_eq(
    render_expr_triple_action(fn() raise PolyError {
      @sympolys.domain_from_string("QQ").gcdex_expr(qq_left, qq_right)
    }),
    "(1/3,0,2/9)",
  )

  let zzi_left = @symcore.add([@symcore.int(2), i])
  let zzi_right = @symcore.add([@symcore.int(1), @symcore.int(-1) * i])
  let zzi = @sympolys.domain_from_string("ZZ_I")
  let zzi_half = zzi.half_gcdex_expr(zzi_left, zzi_right)
  assert_eq(render_expr_result(Ok(zzi_half.1)), "1")
  let zzi_full = zzi.gcdex_expr(zzi_left, zzi_right)
  assert_eq(render_expr_result(Ok(zzi_full.2)), "1")
  let zzi_bezout = zzi.add_expr(
    zzi.mul_expr(zzi_left, zzi_full.0),
    zzi.mul_expr(zzi_right, zzi_full.1),
  )
  assert_eq(render_expr_result(Ok(zzi_bezout)), "1")

  let qqx_left = (x ^ @symcore.int(2)) - @symcore.int(1)
  let qqx_right = x - @symcore.int(1)
  let qqx = @sympolys.domain_from_string("QQ[x]")
  let qqx_half = qqx.half_gcdex_expr(qqx_left, qqx_right)
  assert_eq(render_expr_result(Ok(qqx_half.1)), "x-1")
  let qqx_full = qqx.gcdex_expr(qqx_left, qqx_right)
  assert_eq(render_expr_result(Ok(qqx_full.2)), "x-1")
  let qqx_bezout = qqx.add_expr(
    qqx.mul_expr(qqx_left, qqx_full.0),
    qqx.mul_expr(qqx_right, qqx_full.1),
  )
  assert_eq(render_expr_result(Ok(qqx_bezout)), "x-1")

  let invert_cases : Array[
    (String, @symcore.Expr, @symcore.Expr, String, String),
  ] = [
    ("ZZ", @symcore.int(3), @symcore.int(7), "3", "7"),
    ("ZZ", @symcore.int(2), @symcore.int(4), "2", "4"),
    (
      "QQ[x]",
      x + @symcore.int(1),
      (x ^ @symcore.int(2)) + @symcore.int(1),
      "x + 1",
      "x**2 + 1",
    ),
  ]
  for item in invert_cases {
    let spec = item.0
    let left = item.1
    let right = item.2
    let left_text = item.3
    let right_text = item.4
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).invert_expr(left, right)
    })
    let oracle = normalize_expr_text(
      domain_invert_expr(spec, left_text, right_text),
    )
    assert_eq(ours, oracle)
  }

  let revert_cases : Array[(String, @symcore.Expr, String)] = [
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("GF(5)", @symcore.int(2), "2"),
    ("QQ(x)", (x + @symcore.int(1)) * (x ^ @symcore.int(-1)), "(x + 1)/x"),
    ("ZZ", @symcore.int(1), "1"),
    ("ZZ", @symcore.int(2), "2"),
    ("QQ[x]", @symcore.int(1), "1"),
  ]
  for item in revert_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).revert_expr(expr)
    })
    let oracle = normalize_expr_text(domain_revert_expr(spec, expr_text))
    assert_eq(ours, oracle)
  }
}

///|
test "domains: sign predicate parity on ordered and composite domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let neg_x = @symcore.mul([@symcore.int(-1), x])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-2), "-2"),
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("CC", @symcore.int(2), "2"),
    ("GF(5)", @symcore.int(2), "2"),
    ("ZZ_I", i, "I"),
    ("QQ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("ZZ[x]", x, "x"),
    ("ZZ[x]", neg_x, "-x"),
    ("QQ(x)", x, "x"),
    ("QQ(1/x,y)", x, "x"),
    ("QQ<sqrt(2)>", @symcore.add([@symcore.int(1), sqrt2]), "1 + sqrt(2)"),
    ("EX", @symcore.add([x, @symcore.int(1)]), "x + 1"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = @sympolys.domain_from_string(spec)
    let ours_positive = domain.is_positive_expr(expr)
    let ours_negative = domain.is_negative_expr(expr)
    let ours_nonpositive = domain.is_nonpositive_expr(expr)
    let ours_nonnegative = domain.is_nonnegative_expr(expr)
    let oracle_positive = domain_is_positive_expr(spec, expr_text)
    let oracle_negative = domain_is_negative_expr(spec, expr_text)
    let oracle_nonpositive = domain_is_nonpositive_expr(spec, expr_text)
    let oracle_nonnegative = domain_is_nonnegative_expr(spec, expr_text)
    assert_eq(ours_positive, oracle_positive)
    assert_eq(ours_negative, oracle_negative)
    assert_eq(ours_nonpositive, oracle_nonpositive)
    assert_eq(ours_nonnegative, oracle_nonnegative)
  }

  let minus_one = @symcore.int(-1)
  assert_true(
    @sympolys.domain_from_string("ZZ").is_negative_one_expr(minus_one),
  )

  let zz_series = @sympolys.domain_from_string("ZZ[[x]](prec=5)")
  assert_true(
    !zz_series.is_positive_expr(x) &&
    !zz_series.is_negative_expr(x) &&
    zz_series.is_nonpositive_expr(x) &&
    zz_series.is_nonnegative_expr(x),
  )
}

///|
test "domains: canonical_unit parity on scalar and composite domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-2), "-2"),
    ("QQ", @symcore.rational_from_ints(-2, 3), "-2/3"),
    ("ZZ_I", i, "I"),
    ("ZZ_I", @symcore.add([@symcore.int(1), @symcore.int(-1) * i]), "1 - I"),
    ("QQ_I", @symcore.int(2), "2"),
    ("ZZ[x]", @symcore.int(-1) * x, "-x"),
    ("QQ(x)", x, "x"),
    ("QQ(1/x)", (x ^ @symcore.int(2)) - @symcore.int(1), "x**2 - 1"),
    ("QQ<sqrt(2)>", @symcore.int(-1) * sqrt2, "-sqrt(2)"),
    ("EX", @symcore.int(-1) * x, "-x"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).canonical_unit_expr(expr)
    })
    let oracle = normalize_expr_text(
      domain_canonical_unit_expr(spec, expr_text),
    )
    assert_eq(ours, oracle)
  }

  let zz_series = @sympolys.domain_from_string("ZZ[[x]](prec=5)")
  assert_eq(
    trim_ws(
      @symprint.pretty_string(
        zz_series.canonical_unit_expr(@symcore.int(-1) + x),
      ),
    ),
    "-1",
  )
}

///|
test "domains: abs parity on supported/error domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-2), "-2"),
    ("QQ", @symcore.rational_from_ints(-2, 3), "-2/3"),
    ("EX", @symcore.int(-1) * x, "-x"),
    ("EX", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).abs_expr(expr)
    })
    let oracle = normalize_expr_text(domain_abs_expr(spec, expr_text))
    assert_eq(ours, oracle)
  }
}

///|
test "domains: gcd/lcm/cofactors parity on scalar and composite domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(6), "6", @symcore.int(4), "4"),
    (
      "QQ",
      @symcore.rational_from_ints(2, 3),
      "2/3",
      @symcore.rational_from_ints(4, 9),
      "4/9",
    ),
    (
      "ZZ_I",
      @symcore.add([@symcore.int(2), i]),
      "2 + I",
      @symcore.add([@symcore.int(1), @symcore.int(-1) * i]),
      "1 - I",
    ),
    ("QQ_I", @symcore.int(2), "2", @symcore.int(4), "4"),
    ("EX", x, "x", @symcore.int(2), "2"),
    (
      "ZZ[x]",
      (x ^ @symcore.int(2)) - @symcore.int(1),
      "x**2 - 1",
      x - @symcore.int(1),
      "x - 1",
    ),
    ("QQ[x]", x, "x", @symcore.int(2), "2"),
    (
      "QQ(x)",
      @symcore.rational_from_ints(2, 1) * (x ^ @symcore.int(-1)),
      "2/x",
      @symcore.rational_from_ints(4, 1) * (x ^ @symcore.int(-2)),
      "4/x**2",
    ),
    (
      "QQ<sqrt(2)>",
      @symcore.int(1) + sqrt2,
      "1 + sqrt(2)",
      @symcore.int(2),
      "2",
    ),
  ]
  for item in cases {
    let spec = item.0
    let left = item.1
    let left_text = item.2
    let right = item.3
    let right_text = item.4
    let domain = @sympolys.domain_from_string(spec)
    let ours_gcd = render_expr_action(fn() raise PolyError {
      domain.gcd_expr(left, right)
    })
    let ours_lcm = render_expr_action(fn() raise PolyError {
      domain.lcm_expr(left, right)
    })
    let ours_cof = render_expr_triple_action(fn() raise PolyError {
      domain.cofactors_expr(left, right)
    })
    let oracle_gcd = normalize_expr_text(
      domain_gcd_expr(spec, left_text, right_text),
    )
    let oracle_lcm = normalize_expr_text(
      domain_lcm_expr(spec, left_text, right_text),
    )
    let oracle_cof = normalize_expr_tuple3_text(
      domain_cofactors_expr(spec, left_text, right_text),
    )
    assert_eq(ours_gcd, oracle_gcd)
    assert_eq(ours_lcm, oracle_lcm)
    assert_eq(ours_cof, oracle_cof)
  }
}

///|
test "domains: numer/denom parity on scalar and fraction-like domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(7), "7"),
    ("QQ", @symcore.rational_from_ints(7, 3), "7/3"),
    ("ZZ_I", @symcore.add([@symcore.int(3), i]), "3 + I"),
    (
      "QQ_I",
      @symcore.rational_from_ints(1, 2) + @symcore.rational_from_ints(1, 3) * i,
      "1/2 + I/3",
    ),
    ("EX", x, "x"),
    ("GF(5)", @symcore.int(3), "3"),
    (
      "QQ(x)",
      (x + @symcore.int(1)) * ((x - @symcore.int(1)) ^ @symcore.int(-1)),
      "(x + 1)/(x - 1)",
    ),
    ("QQ<sqrt(2)>", @symcore.int(1) + sqrt2, "1 + sqrt(2)"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = @sympolys.domain_from_string(spec)
    let ours_num = render_expr_action(fn() raise PolyError {
      domain.numer_expr(expr)
    })
    let ours_den = render_expr_action(fn() raise PolyError {
      domain.denom_expr(expr)
    })
    let oracle_num = normalize_expr_text(domain_numer_expr(spec, expr_text))
    let oracle_den = normalize_expr_text(domain_denom_expr(spec, expr_text))
    assert_eq(ours_num, oracle_num)
    assert_eq(ours_den, oracle_den)
  }
}

///|
test "domains: quo/rem/div/exquo parity on scalar and composite domains" {
  let x = @symcore.Expr::Symbol("x")
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let cases : Array[(String, @symcore.Expr, String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(7), "7", @symcore.int(3), "3"),
    (
      "QQ",
      @symcore.rational_from_ints(7, 3),
      "7/3",
      @symcore.rational_from_ints(2, 3),
      "2/3",
    ),
    (
      "ZZ_I",
      @symcore.add([@symcore.int(3), i]),
      "3 + I",
      @symcore.add([@symcore.int(1), @symcore.int(-1) * i]),
      "1 - I",
    ),
    ("QQ_I", @symcore.int(2), "2", @symcore.int(4), "4"),
    (
      "ZZ[x]",
      (x ^ @symcore.int(2)) - @symcore.int(1),
      "x**2 - 1",
      x - @symcore.int(1),
      "x - 1",
    ),
    ("QQ[x]", x, "x", @symcore.int(2), "2"),
    (
      "QQ(x)",
      @symcore.rational_from_ints(2, 1) * (x ^ @symcore.int(-1)),
      "2/x",
      @symcore.rational_from_ints(4, 1) * (x ^ @symcore.int(-2)),
      "4/x**2",
    ),
  ]
  for item in cases {
    let spec = item.0
    let left = item.1
    let left_text = item.2
    let right = item.3
    let right_text = item.4
    let domain = @sympolys.domain_from_string(spec)
    let ours_quo = render_expr_action(fn() raise PolyError {
      domain.quo_expr(left, right)
    })
    let ours_rem = render_expr_action(fn() raise PolyError {
      domain.rem_expr(left, right)
    })
    let ours_div = render_expr_pair_action(fn() raise PolyError {
      domain.div_expr(left, right)
    })
    let ours_exquo = render_expr_action(fn() raise PolyError {
      domain.exquo_expr(left, right)
    })
    let oracle_quo = normalize_expr_text(
      domain_quo_expr(spec, left_text, right_text),
    )
    let oracle_rem = normalize_expr_text(
      domain_rem_expr(spec, left_text, right_text),
    )
    let oracle_div = normalize_expr_tuple2_text(
      domain_div_expr(spec, left_text, right_text),
    )
    let oracle_exquo = normalize_expr_text(
      domain_exquo_expr(spec, left_text, right_text),
    )
    assert_eq(ours_quo, oracle_quo)
    assert_eq(ours_rem, oracle_rem)
    assert_eq(ours_div, oracle_div)
    assert_eq(ours_exquo, oracle_exquo)
  }

  let exact_fail = render_expr_action(fn() raise PolyError {
    @sympolys.domain_from_string("ZZ").exquo_expr(
      @symcore.int(7),
      @symcore.int(3),
    )
  })
  assert_eq(exact_fail, "ERROR")
}

///|
test "domains: factorial/log/sqrt parity on integer-like domains" {
  let factorial_cases : Array[(@symcore.Expr, String)] = [
    (@symcore.int(0), "0"),
    (@symcore.int(5), "5"),
  ]
  for item in factorial_cases {
    let expr = item.0
    let expr_text = item.1
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string("ZZ").factorial_expr(expr)
    })
    let oracle = normalize_expr_text(domain_factorial_expr("ZZ", expr_text))
    assert_eq(ours, oracle)
  }

  let log_cases : Array[(@symcore.Expr, String, @symcore.Expr, String)] = [
    (@symcore.int(8), "8", @symcore.int(2), "2"),
    (@symcore.int(9), "9", @symcore.int(2), "2"),
    (@symcore.int(1), "1", @symcore.int(2), "2"),
  ]
  for item in log_cases {
    let value = item.0
    let value_text = item.1
    let base = item.2
    let base_text = item.3
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string("ZZ").log_expr(value, base)
    })
    let oracle = normalize_expr_text(
      domain_log_expr("ZZ", value_text, base_text),
    )
    assert_eq(ours, oracle)
  }

  let sqrt_cases : Array[(@symcore.Expr, String)] = [
    (@symcore.int(2), "2"),
    (@symcore.int(8), "8"),
    (@symcore.int(9), "9"),
  ]
  for item in sqrt_cases {
    let expr = item.0
    let expr_text = item.1
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string("ZZ").sqrt_expr(expr)
    })
    let oracle = normalize_expr_text(domain_sqrt_expr("ZZ", expr_text))
    assert_eq(ours, oracle)
  }

  let zzx = @sympolys.domain_from_string("ZZ[x]")
  assert_eq(
    render_expr_action(fn() raise PolyError {
      zzx.factorial_expr(@symcore.int(5))
    }),
    "120",
  )
  assert_eq(
    render_expr_action(fn() raise PolyError {
      zzx.log_expr(@symcore.int(8), @symcore.int(2))
    }),
    "3",
  )
  assert_eq(
    render_expr_action(fn() raise PolyError { zzx.sqrt_expr(@symcore.int(8)) }),
    "2",
  )
}

///|
test "domains: is_square/exsqrt parity and exact root coverage" {
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let parity_cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(4), "4"),
    ("ZZ", @symcore.int(2), "2"),
    ("QQ", @symcore.rational_from_ints(4, 9), "4/9"),
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("GF(7)", @symcore.int(4), "4"),
    ("GF(7)", @symcore.int(3), "3"),
  ]
  for item in parity_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = @sympolys.domain_from_string(spec)
    let ours_square = domain.is_square_expr(expr) catch { _ => false }
    let oracle_square = domain_is_square_expr(spec, expr_text)
    assert_eq(ours_square, oracle_square)
    let ours_root = render_optional_expr_action(fn() raise PolyError {
      domain.exsqrt_expr(expr)
    })
    let oracle_root = domain_exsqrt_expr(spec, expr_text)
    let oracle_root_expected = if oracle_root == "ERROR" && !oracle_square {
      "NONE"
    } else {
      normalize_expr_text(oracle_root)
    }
    assert_eq(ours_root, oracle_root_expected)
  }

  let zz_i = @sympolys.domain_from_string("ZZ_I")
  let zz_i_square = @symcore.add([@symcore.int(3), @symcore.int(4) * i])
  assert_true(zz_i.is_square_expr(zz_i_square))
  assert_eq(
    render_optional_expr_action(fn() raise PolyError {
      zz_i.exsqrt_expr(zz_i_square)
    }),
    normalize_expr_text("2 + I"),
  )

  let qq_i = @sympolys.domain_from_string("QQ_I")
  let qq_i_square = @symcore.rational_from_ints(-3, 4) + i
  assert_true(qq_i.is_square_expr(qq_i_square))
  assert_eq(
    render_optional_expr_action(fn() raise PolyError {
      qq_i.exsqrt_expr(qq_i_square)
    }),
    normalize_expr_text("1/2 + I"),
  )

  let rr = @sympolys.domain_from_string("RR")
  assert_eq(
    render_optional_expr_action(fn() raise PolyError {
      rr.exsqrt_expr(@symcore.int(2))
    }),
    normalize_expr_text("sqrt(2)"),
  )
  assert_true(!rr.is_square_expr(@symcore.int(-1)))

  let cc = @sympolys.domain_from_string("CC")
  let cc_expr = @symcore.add([@symcore.int(2), i])
  assert_true(cc.is_square_expr(cc_expr))
  assert_eq(
    render_optional_expr_action(fn() raise PolyError { cc.exsqrt_expr(cc_expr) }),
    normalize_expr_text("sqrt(2 + I)"),
  )
}

///|
test "domains: real/imag/almosteq parity and tolerance semantics" {
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let x = @symcore.Expr::Symbol("x")
  let component_cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(2), "2"),
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("GF(5)", @symcore.int(3), "3"),
    ("ZZ_I", @symcore.add([@symcore.int(1), i]), "1 + I"),
    (
      "QQ_I",
      @symcore.rational_from_ints(1, 2) + @symcore.rational_from_ints(1, 3) * i,
      "1/2 + I/3",
    ),
    ("QQ[x]", x + @symcore.int(1), "x + 1"),
  ]
  for item in component_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = @sympolys.domain_from_string(spec)
    let ours_real = render_expr_action(fn() raise PolyError {
      domain.real_expr(expr)
    })
    let ours_imag = render_expr_action(fn() raise PolyError {
      domain.imag_expr(expr)
    })
    let oracle_real = normalize_expr_text(domain_real_expr(spec, expr_text))
    let oracle_imag = normalize_expr_text(domain_imag_expr(spec, expr_text))
    assert_eq(ours_real, oracle_real)
    assert_eq(ours_imag, oracle_imag)
  }

  let almosteq_cases : Array[
    (String, @symcore.Expr, String, @symcore.Expr, String),
  ] = [
    ("ZZ", @symcore.int(2), "2", @symcore.int(2), "2"),
    ("ZZ", @symcore.int(2), "2", @symcore.int(3), "3"),
    (
      "QQ",
      @symcore.rational_from_ints(1, 2),
      "1/2",
      @symcore.rational_from_ints(2, 4),
      "2/4",
    ),
    (
      "QQ",
      @symcore.rational_from_ints(1, 2),
      "1/2",
      @symcore.rational_from_ints(2, 3),
      "2/3",
    ),
    (
      "ZZ_I",
      @symcore.add([@symcore.int(1), i]),
      "1 + I",
      @symcore.add([@symcore.int(1), i]),
      "1 + I",
    ),
    (
      "ZZ_I",
      @symcore.add([@symcore.int(1), i]),
      "1 + I",
      @symcore.add([@symcore.int(1), @symcore.int(-1) * i]),
      "1 - I",
    ),
    ("RR", @symcore.int(1), "1", @symcore.int(1), "1"),
    ("RR", @symcore.int(1), "1", @symcore.int(2), "2"),
    (
      "CC",
      @symcore.add([@symcore.int(1), i]),
      "1 + I",
      @symcore.add([@symcore.int(1), i]),
      "1 + I",
    ),
    ("CC", @symcore.add([@symcore.int(1), i]), "1 + I", i, "I"),
  ]
  for item in almosteq_cases {
    let spec = item.0
    let left = item.1
    let left_text = item.2
    let right = item.3
    let right_text = item.4
    let ours = @sympolys.domain_from_string(spec).almosteq_expr(left, right)
    let oracle = domain_almosteq_expr(spec, left_text, right_text)
    assert_eq(ours, oracle)
  }

  let qq = @sympolys.domain_from_string("QQ")
  assert_true(
    qq.almosteq_expr(
      @symcore.rational_from_ints(1, 2),
      @symcore.rational_from_ints(2, 3),
      tolerance=Some(
        @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(4)),
      ),
    ),
  )

  let qq_i = @sympolys.domain_from_string("QQ_I")
  assert_true(
    qq_i.almosteq_expr(
      @symcore.add([@symcore.int(1), i]),
      @symcore.add([@symcore.int(1), @symcore.rational_from_ints(1, 2) * i]),
      tolerance=Some(
        @symnum.BigRational::new(BigInt::from_int(1), BigInt::from_int(2)),
      ),
    ),
  )

  let evalf_cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(2), "2"),
    ("QQ", @symcore.rational_from_ints(2, 3), "2/3"),
    ("ZZ_I", @symcore.add([@symcore.int(1), i]), "1 + I"),
    ("QQ[x]", x + @symcore.int(1), "x + 1"),
  ]
  for item in evalf_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = render_expr_action(fn() raise PolyError {
      @sympolys.domain_from_string(spec).evalf_expr(expr)
    })
    let oracle = normalize_expr_text(domain_evalf_expr(spec, expr_text))
    assert_eq(ours, oracle)
  }
}
