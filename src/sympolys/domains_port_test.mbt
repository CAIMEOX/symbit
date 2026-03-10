///|
fn trim_ws(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
fn render_domain_result(result : Result[Domain, PolyError]) -> String {
  match result {
    Ok(domain) => domain_to_sympy_string(domain)
    Err(_) => "ERROR"
  }
}

fn normalize_expr_text(text : String) -> String {
  let compact = trim_ws(text)
  if compact == "ERROR" {
    return compact
  }
  try @sympy_polys.sympy_normalize(compact) catch {
    _ => compact
  } noraise {
    normalized => trim_ws(normalized)
  }
}

fn normalize_expr_tuple3_text(text : String) -> String {
  let compact = trim_ws(text)
  if compact == "ERROR" || !compact.has_prefix("(") || !compact.has_suffix(")") {
    return compact
  }
  let inner = (try! compact[1:compact.length() - 1]).to_string()
  let parts : Array[String] = Array::new()
  for part in inner.split(",") {
    parts.push(normalize_expr_text(part.trim().to_string()))
  }
  if parts.length() != 3 {
    compact
  } else {
    "(\{parts[0]},\{parts[1]},\{parts[2]})"
  }
}

fn normalize_expr_tuple2_text(text : String) -> String {
  let compact = trim_ws(text)
  if compact == "ERROR" || !compact.has_prefix("(") || !compact.has_suffix(")") {
    return compact
  }
  let inner = (try! compact[1:compact.length() - 1]).to_string()
  let parts : Array[String] = Array::new()
  for part in inner.split(",") {
    parts.push(normalize_expr_text(part.trim().to_string()))
  }
  if parts.length() != 2 {
    compact
  } else {
    "(\{parts[0]},\{parts[1]})"
  }
}

fn render_expr_result(result : Result[@symcore.Expr, PolyError]) -> String {
  match result {
    Ok(expr) => normalize_expr_text(@symprint.to_string(expr))
    Err(_) => "ERROR"
  }
}

fn render_expr_triple_result(
  result : Result[(@symcore.Expr, @symcore.Expr, @symcore.Expr), PolyError],
) -> String {
  match result {
    Ok(items) =>
      normalize_expr_tuple3_text(
        "(\{@symprint.to_string(items.0)},\{@symprint.to_string(items.1)},\{@symprint.to_string(items.2)})",
      )
    Err(_) => "ERROR"
  }
}

fn render_expr_pair_result(
  result : Result[(@symcore.Expr, @symcore.Expr), PolyError],
) -> String {
  match result {
    Ok(items) =>
      normalize_expr_tuple2_text(
        "(\{@symprint.to_string(items.0)},\{@symprint.to_string(items.1)})",
      )
    Err(_) => "ERROR"
  }
}

///|
test "domains: basic constructor/repr parity" {
  let specs = [
    "ZZ",
    "QQ",
    "RR",
    "CC",
    "ZZ_I",
    "QQ_I",
    "EX",
    "EXRAW",
    "GF(7)",
    "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let domain = domain_from_string(spec)
    let ours = domain_to_sympy_string(domain)
    let oracle = @sympy_polys.domain_repr(spec)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("domain repr mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

///|
test "domains: polynomial/fraction descriptors parity" {
  let poly_domain = poly_ring_domain(Domain::ZZ, ["x", "y"])
  let frac_domain = rational_function_field_domain(Domain::QQ, ["x", "y"])

  let poly_ours = domain_to_sympy_string(poly_domain)
  let frac_ours = domain_to_sympy_string(frac_domain)

  let poly_oracle = @sympy_polys.domain_repr("ZZ[x,y]")
  let frac_oracle = @sympy_polys.domain_repr("QQ(x,y)")

  guard trim_ws(poly_ours) == trim_ws(poly_oracle) else {
    fail("poly ring repr mismatch: ours=\{poly_ours}, oracle=\{poly_oracle}")
  }
  guard trim_ws(frac_ours) == trim_ws(frac_oracle) else {
    fail("frac field repr mismatch: ours=\{frac_ours}, oracle=\{frac_oracle}")
  }
}

///|
test "domains: characteristic parity" {
  let cases = ["ZZ", "QQ", "GF(11)", "ZZ[x]", "QQ(x)"]
  for spec in cases {
    let domain = domain_from_string(spec)
    let ours = domain_characteristic(domain)
    let oracle = @sympy_polys.domain_characteristic(spec)
    guard ours == oracle else {
      fail(
        "characteristic mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}",
      )
    }
  }
}

///|
test "domains: predicate parity (field/ring/exact/finite)" {
  let specs = ["ZZ", "QQ", "RR", "CC", "GF(7)", "ZZ[x]", "QQ(x)", "EX", "EXRAW"]
  for spec in specs {
    let domain = domain_from_string(spec)
    guard domain_is_field_pred(domain) == @sympy_polys.domain_is_field(spec) else {
      fail("is_Field mismatch for \{spec}")
    }
    guard domain_is_ring_pred(domain) == @sympy_polys.domain_is_ring(spec) else {
      fail("is_Ring mismatch for \{spec}")
    }
    guard domain_is_exact_pred(domain) == @sympy_polys.domain_is_exact(spec) else {
      fail("is_Exact mismatch for \{spec}")
    }
    guard
      domain_is_finite_pred(domain) == @sympy_polys.domain_is_finite_field(spec)
    else {
      fail("is_FiniteField mismatch for \{spec}")
    }
  }
}

///|
test "domains: get_field/get_ring parity" {
  let field_specs = [
    "ZZ",
    "QQ",
    "RR",
    "CC",
    "GF(7)",
    "ZZ[x]",
    "QQ(x)",
    "ZZ_I",
    "QQ_I",
    "EX",
    "QQ<sqrt(2)>",
  ]
  for spec in field_specs {
    let ours = domain_to_sympy_string(domain_get_field(domain_from_string(spec)))
    let oracle = @sympy_polys.domain_get_field(spec)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("get_field mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }

  let ring_specs = [
    "QQ",
    "RR",
    "ZZ[x]",
    "QQ(x)",
    "ZZ(x)",
    "QQ_I",
    "ZZ_I",
    "EX",
    "CC",
    "GF(7)",
    "EXRAW",
    "QQ<sqrt(2)>",
  ]
  for spec in ring_specs {
    let ours_try : Result[Domain, PolyError] = try? domain_get_ring(
      domain_from_string(spec),
    )
    let ours = match ours_try {
      Ok(domain) => domain_to_sympy_string(domain)
      Err(_) => "ERROR"
    }
    let oracle = @sympy_polys.domain_get_ring(spec)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("get_ring mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
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
    let ours = domain_unify_pair(domain_from_string(lhs), domain_from_string(rhs))
    let ours_text = domain_to_sympy_string(ours)
    let oracle = @sympy_polys.domain_unify(lhs, rhs)
    guard trim_ws(ours_text) == trim_ws(oracle) else {
      fail(
        "unify mismatch for \{lhs} + \{rhs}: ours=\{ours_text}, oracle=\{oracle}",
      )
    }
  }
}

///|
test "domains: extended predicate parity (module-level tags)" {
  let specs = [
    "ZZ",
    "QQ",
    "RR",
    "CC",
    "ZZ_I",
    "QQ_I",
    "EX",
    "EXRAW",
    "GF(7)",
    "ZZ[x]",
    "QQ(x)",
    "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let domain = domain_from_string(spec)
    guard
      domain_is_composite_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_Composite")
    else {
      fail("is_Composite mismatch for \{spec}")
    }
    guard
      domain_is_simple_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_Simple")
    else {
      fail("is_Simple mismatch for \{spec}")
    }
    guard
      domain_is_numerical_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_Numerical")
    else {
      fail("is_Numerical mismatch for \{spec}")
    }
    guard
      domain_has_assoc_ring_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "has_assoc_Ring")
    else {
      fail("has_assoc_Ring mismatch for \{spec}")
    }
    guard
      domain_is_pid_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_PID")
    else {
      fail("is_PID mismatch for \{spec}")
    }
    guard
      domain_is_integer_ring_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_IntegerRing")
    else {
      fail("is_IntegerRing mismatch for \{spec}")
    }
    guard
      domain_is_rational_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_RationalField")
    else {
      fail("is_RationalField mismatch for \{spec}")
    }
    guard
      domain_is_real_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_RealField")
    else {
      fail("is_RealField mismatch for \{spec}")
    }
    guard
      domain_is_complex_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_ComplexField")
    else {
      fail("is_ComplexField mismatch for \{spec}")
    }
    guard
      domain_is_gaussian_ring_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_GaussianRing")
    else {
      fail("is_GaussianRing mismatch for \{spec}")
    }
    guard
      domain_is_gaussian_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_GaussianField")
    else {
      fail("is_GaussianField mismatch for \{spec}")
    }
    guard
      domain_is_expression_domain_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_EX")
    else {
      fail("is_EX mismatch for \{spec}")
    }
    guard
      domain_is_expression_raw_domain_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_EXRAW")
    else {
      fail("is_EXRAW mismatch for \{spec}")
    }
  }
}

///|
test "domains: advanced predicate parity (meta/family tags)" {
  let specs = [
    "ZZ",
    "QQ",
    "RR",
    "CC",
    "ZZ_I",
    "QQ_I",
    "EX",
    "EXRAW",
    "GF(7)",
    "ZZ[x]",
    "QQ(x)",
    "RR[x]",
    "CC[x]",
    "RR(x)",
    "CC(x)",
    "EX(x)",
    "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let domain = domain_from_string(spec)
    guard
      domain_is_algebraic_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_Algebraic")
    else {
      fail("is_Algebraic mismatch for \{spec}")
    }
    guard
      domain_is_algebraic_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_AlgebraicField")
    else {
      fail("is_AlgebraicField mismatch for \{spec}")
    }
    guard
      domain_is_symbolic_domain_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_SymbolicDomain")
    else {
      fail("is_SymbolicDomain mismatch for \{spec}")
    }
    guard
      domain_has_assoc_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "has_assoc_Field")
    else {
      fail("has_assoc_Field mismatch for \{spec}")
    }
    guard
      domain_has_characteristic_zero_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "has_CharacteristicZero")
    else {
      fail("has_CharacteristicZero mismatch for \{spec}")
    }
    guard
      domain_is_finite_extension_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_FiniteExtension")
    else {
      fail("is_FiniteExtension mismatch for \{spec}")
    }
    guard
      domain_is_zz_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_ZZ")
    else {
      fail("is_ZZ mismatch for \{spec}")
    }
    guard
      domain_is_qq_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_QQ")
    else {
      fail("is_QQ mismatch for \{spec}")
    }
    guard
      domain_is_zz_i_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_ZZ_I")
    else {
      fail("is_ZZ_I mismatch for \{spec}")
    }
    guard
      domain_is_qq_i_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_QQ_I")
    else {
      fail("is_QQ_I mismatch for \{spec}")
    }
    guard
      domain_is_cc_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_CC")
    else {
      fail("is_CC mismatch for \{spec}")
    }
    guard
      domain_is_rr_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_RR")
    else {
      fail("is_RR mismatch for \{spec}")
    }
    guard
      domain_is_ff_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_FF")
    else {
      fail("is_FF mismatch for \{spec}")
    }
    guard
      domain_is_frac_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_Frac")
    else {
      fail("is_Frac mismatch for \{spec}")
    }
    guard
      domain_is_fraction_field_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_FractionField")
    else {
      fail("is_FractionField mismatch for \{spec}")
    }
    guard
      domain_is_poly_pred(domain) == @sympy_polys.domain_attr_bool_query(spec, "is_Poly")
    else {
      fail("is_Poly mismatch for \{spec}")
    }
    guard
      domain_is_polynomial_ring_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_PolynomialRing")
    else {
      fail("is_PolynomialRing mismatch for \{spec}")
    }
    guard
      domain_is_symbolic_raw_domain_pred(domain) ==
      @sympy_polys.domain_attr_bool_query(spec, "is_SymbolicRawDomain")
    else {
      fail("is_SymbolicRawDomain mismatch for \{spec}")
    }
    guard
      domain_has_default_precision_pred(domain) ==
      @sympy_polys.domain_attr_bool_or_false(spec, "has_default_precision")
    else {
      fail("has_default_precision mismatch for \{spec}")
    }
  }
}

///|
test "domains: get_exact parity across core/coercion domains" {
  let specs = [
    "ZZ",
    "QQ",
    "RR",
    "CC",
    "ZZ_I",
    "QQ_I",
    "EX",
    "EXRAW",
    "GF(7)",
    "ZZ[x]",
    "RR[x]",
    "CC[x]",
    "QQ(x)",
    "RR(x)",
    "CC(x)",
    "QQ<sqrt(2)>",
  ]
  for spec in specs {
    let ours = domain_to_sympy_string(domain_get_exact(domain_from_string(spec)))
    let oracle = @sympy_polys.domain_get_exact(spec)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("get_exact mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

///|
test "domains: alias constructors and parser coverage" {
  guard
    domain_to_sympy_string(domain_from_string("IntegerRing")) == domain_to_sympy_string(
      integer_ring_domain(),
    )
  else {
    fail("IntegerRing alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("RationalField")) == domain_to_sympy_string(
      rational_field_domain(),
    )
  else {
    fail("RationalField alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("RealField")) == domain_to_sympy_string(
      real_field_domain(),
    )
  else {
    fail("RealField alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("ComplexField")) == domain_to_sympy_string(
      complex_field_domain(),
    )
  else {
    fail("ComplexField alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("GaussianIntegerRing")) ==
    domain_to_sympy_string(gaussian_integer_ring_domain())
  else {
    fail("GaussianIntegerRing alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("GaussianRationalField")) ==
    domain_to_sympy_string(gaussian_rational_field_domain())
  else {
    fail("GaussianRationalField alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("ExpressionDomain")) ==
    domain_to_sympy_string(expression_domain())
  else {
    fail("ExpressionDomain alias mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("ExpressionRawDomain")) ==
    domain_to_sympy_string(expression_raw_domain())
  else {
    fail("ExpressionRawDomain alias mismatch")
  }
  let ff7 = try! ff_domain(7)
  guard domain_to_sympy_string(domain_from_string("FF(7)")) == domain_to_sympy_string(ff7) else {
    fail("FF alias mismatch")
  }
  let ff11 = try! finite_field_domain(11)
  guard
    domain_to_sympy_string(domain_from_string("FiniteField(11)")) ==
    domain_to_sympy_string(ff11)
  else {
    fail("FiniteField alias mismatch")
  }
  let gfext = domain_from_string("GF(5,2)")
  guard domain_to_sympy_string(gfext) == "GF(5**2)" else {
    fail("GF comma extension parser mismatch")
  }
  let gfext_ff = domain_from_string("FF(7,3)")
  guard domain_to_sympy_string(gfext_ff) == "GF(7**3)" else {
    fail("FF comma extension parser mismatch")
  }
}

///|
test "domains: extended parser handles Frac/GFExt/PowerSeries syntax" {
  let frac = domain_from_string("Frac(ZZ[x])")
  guard domain_to_sympy_string(frac) == "Frac(ZZ[x])" else {
    fail("Frac parser mismatch")
  }
  let gfext_pow = domain_from_string("GF(5**2)")
  guard domain_to_sympy_string(gfext_pow) == "GF(5**2)" else {
    fail("GFExt parser mismatch")
  }
  let ps = domain_from_string("QQ[[x,y]]")
  guard domain_to_sympy_string(ps) == "QQ[[x,y]]" else {
    fail("PowerSeries parser mismatch")
  }
  let ps_prec = domain_from_string("RR[[t]](prec=7)")
  guard domain_to_sympy_string(ps_prec) == "RR[[t]](prec=7)" else {
    fail("PowerSeries precision parser mismatch")
  }
}

///|
test "domains: oracle GF descriptor parser handles extension forms" {
  let gf_pow = @sympy_polys.domain_repr("GF(5**2)")
  let gf_flat = @sympy_polys.domain_repr("GF(25)")
  guard trim_ws(gf_pow) == trim_ws(gf_flat) else {
    fail("oracle GF power descriptor mismatch: \{gf_pow} vs \{gf_flat}")
  }

  let ff_pair = @sympy_polys.domain_repr("FF(7,3)")
  let ff_flat = @sympy_polys.domain_repr("GF(343)")
  guard trim_ws(ff_pair) == trim_ws(ff_flat) else {
    fail("oracle FF pair descriptor mismatch: \{ff_pair} vs \{ff_flat}")
  }
}

///|
test "domains: nested composite parser handles recursive suffix forms" {
  let cases = [
    "ZZ[x][y]",
    "QQ(x)[y]",
    "ZZ[x](y)",
    "QQ(x)(y)",
  ]
  for spec in cases {
    let ours = domain_to_sympy_string(domain_from_string(spec))
    let oracle = @sympy_polys.domain_repr(spec)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("nested parser mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
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
    let domain = domain_from_string(spec)

    let poly_ours = domain_to_sympy_string(try! domain.poly_ring(gens))
    let poly_oracle = @sympy_polys.domain_poly_ring(spec, gens)
    guard trim_ws(poly_ours) == trim_ws(poly_oracle) else {
      fail("poly_ring mismatch for \{spec}: ours=\{poly_ours}, oracle=\{poly_oracle}")
    }

    let frac_ours = domain_to_sympy_string(try! domain.frac_field(gens))
    let frac_oracle = @sympy_polys.domain_frac_field(spec, gens)
    guard trim_ws(frac_ours) == trim_ws(frac_oracle) else {
      fail("frac_field mismatch for \{spec}: ours=\{frac_ours}, oracle=\{frac_oracle}")
    }

    let old_poly_ours = domain_to_sympy_string(try! domain.old_poly_ring(gens))
    let old_poly_oracle = @sympy_polys.domain_old_poly_ring(spec, gens)
    guard trim_ws(old_poly_ours) == trim_ws(old_poly_oracle) else {
      fail(
        "old_poly_ring mismatch for \{spec}: ours=\{old_poly_ours}, oracle=\{old_poly_oracle}",
      )
    }

    let old_frac_ours = domain_to_sympy_string(try! domain.old_frac_field(gens))
    let old_frac_oracle = @sympy_polys.domain_old_frac_field(spec, gens)
    guard trim_ws(old_frac_ours) == trim_ws(old_frac_oracle) else {
      fail(
        "old_frac_field mismatch for \{spec}: ours=\{old_frac_ours}, oracle=\{old_frac_oracle}",
      )
    }
  }

  let quotient = try! quotient_ring_domain(
    Domain::QQ,
    ["x"],
    [@symcore.add([@symcore.pow(@symcore.symbol("x"), @symcore.int(2)), @symcore.int(1)])],
  )
  let quotient_try : Result[Domain, PolyError] = try? quotient.poly_ring(["y"])
  guard render_domain_result(quotient_try) == "ERROR" else {
    fail("quotient poly_ring should reject nested domains")
  }
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
    let ours = domain_to_sympy_string(domain_from_string(spec).set_domain(domain_from_string(ground)))
    let oracle = @sympy_polys.domain_set_domain(spec, ground)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("set_domain mismatch for \{spec} -> \{ground}: ours=\{ours}, oracle=\{oracle}")
    }
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
    let symbols_text = symbols.join(",")
    let ours_try : Result[Domain, PolyError] = try? domain_from_string(lhs).unify_with_symbols(
      domain_from_string(rhs),
      symbols,
    )
    let ours = render_domain_result(ours_try)
    let oracle = @sympy_polys.domain_unify_with_symbols(lhs, rhs, symbols)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail(
        "unify_with_symbols mismatch for \{lhs}, \{rhs}, \{symbols_text}: ours=\{ours}, oracle=\{oracle}",
      )
    }
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
    let ours = domain_to_sympy_string(try! domain_from_string(spec).inject(gens))
    let oracle = @sympy_polys.domain_inject(spec, gens)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("inject mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }

  let overlap_try : Result[Domain, PolyError] = try? domain_from_string("ZZ[x]").inject([
    "x",
  ])
  guard render_domain_result(overlap_try) == "ERROR" else {
    fail("inject overlap should fail")
  }

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
    let ours_try : Result[Domain, PolyError] = try? domain_from_string(spec).drop(gens)
    let ours = render_domain_result(ours_try)
    let oracle = @sympy_polys.domain_drop(spec, gens)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("drop mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

///|
test "domains: algebraic_field parity and Domain methods" {
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let sqrt3 = @symcore.function("sqrt", [@symcore.int(3)])
  let cases = [
    ("QQ", [sqrt2], ["sqrt(2)"]),
    ("ZZ", [sqrt2], ["sqrt(2)"]),
    ("QQ<sqrt(2)>", [sqrt3], ["sqrt(3)"]),
  ]
  for item in cases {
    let spec = item.0
    let ext_exprs = item.1
    let ext_specs = item.2
    let ours = domain_to_sympy_string(try! domain_from_string(spec).algebraic_field(ext_exprs))
    let oracle = @sympy_polys.domain_algebraic_field(spec, ext_specs)
    guard trim_ws(ours) == trim_ws(oracle) else {
      fail("algebraic_field mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }

  guard domain_from_string("GF(5)").characteristic() == 5 else {
    fail("Domain::characteristic mismatch")
  }
  guard
    domain_to_sympy_string(domain_from_string("RR[x]").get_exact()) == "QQ[x]"
  else {
    fail("Domain::get_exact mismatch")
  }
  guard
    domain_to_sympy_string(try! domain_from_string("ZZ[x]").get_field()) == "ZZ(x)"
  else {
    fail("Domain::get_field mismatch")
  }
  guard
    domain_to_sympy_string(try! domain_from_string("QQ(x)").get_ring()) == "QQ[x]"
  else {
    fail("Domain::get_ring mismatch")
  }
  guard
    domain_to_sympy_string(try! domain_from_string("ZZ").unify(domain_from_string("QQ"))) ==
    "QQ"
  else {
    fail("Domain::unify mismatch")
  }
}

///|
test "domains: contains_expr parity for constants polynomials and rational functions" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let sin1 = @symcore.function("sin", [@symcore.int(1)])
  let inv_x = @symcore.pow(x, @symcore.int(-1))

  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(3), "3"),
    ("ZZ", try! @symcore.rational_from_ints(3, 2), "3/2"),
    ("QQ", try! @symcore.rational_from_ints(3, 2), "3/2"),
    ("RR", sqrt2, "sqrt(2)"),
    ("CC", i, "I"),
    ("QQ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("QQ<sqrt(2)>", @symcore.add([@symcore.int(1), @symcore.int(2) * sqrt2]), "1 + 2*sqrt(2)"),
    ("QQ<sqrt(2)>", @symcore.function("sqrt", [@symcore.int(3)]), "sqrt(3)"),
    ("ZZ[x]", (x ^ @symcore.int(2)) + @symcore.int(1), "x**2 + 1"),
    ("ZZ[x]", (x ^ @symcore.int(2)) + (y ^ @symcore.int(2)), "x**2 + y**2"),
    ("QQ(x)", inv_x, "1/x"),
    ("QQ(1/x,y)", x + y, "x + y"),
    ("QQ(1/x)", (try! @symcore.rational_from_ints(2, 3)) * x, "2*x/3"),
    ("QQ[x]", inv_x, "1/x"),
    ("QQ[x][y]", x + y, "x + y"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = domain_from_string(spec).contains_expr(expr)
    let oracle = @sympy_polys.domain_contains_expr(spec, expr_text)
    guard ours == oracle else {
      fail("contains_expr mismatch for \{spec} and \{expr_text}: ours=\{ours}, oracle=\{oracle}")
    }
  }

  guard domain_from_string("RR").contains_expr(sin1) else {
    fail("contains_expr RR constant function mismatch")
  }
}

///|
test "domains: from_sympy/to_sympy/convert_from parity on scalar and composite domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let conversion_cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(7), "7"),
    ("QQ", try! @symcore.rational_from_ints(6, 8), "6/8"),
    ("GF(5)", @symcore.int(7), "7"),
    ("QQ_I", @symcore.add([try! @symcore.rational_from_ints(1, 2), (try! @symcore.rational_from_ints(1, 3)) * i]), "1/2 + I/3"),
    ("QQ<sqrt(2)>", @symcore.add([@symcore.int(1), sqrt2]), "1 + sqrt(2)"),
    ("ZZ[x]", (x ^ @symcore.int(2)) + (@symcore.int(2) * x) + @symcore.int(1), "x**2 + 2*x + 1"),
    ("QQ(x)", ((x ^ @symcore.int(2)) - @symcore.int(1)) * ((x - @symcore.int(1)) ^ @symcore.int(-1)), "(x**2 - 1)/(x - 1)"),
  ]
  for item in conversion_cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = domain_from_string(spec)
    let ours_from = render_expr_result(try? domain.from_sympy_expr(expr))
    let oracle_from = normalize_expr_text(@sympy_polys.domain_from_sympy_expr(spec, expr_text))
    guard ours_from == oracle_from else {
      fail("from_sympy parity mismatch for \{spec} and \{expr_text}: ours=\{ours_from}, oracle=\{oracle_from}")
    }
    let ours_to = render_expr_result(try? domain.to_sympy_expr(expr))
    let oracle_to = normalize_expr_text(@sympy_polys.domain_to_sympy_expr(spec, expr_text))
    guard ours_to == oracle_to else {
      fail("to_sympy parity mismatch for \{spec} and \{expr_text}: ours=\{ours_to}, oracle=\{oracle_to}")
    }
  }

  let convert_cases : Array[(String, String, @symcore.Expr, String)] = [
    ("QQ", "ZZ", @symcore.int(7), "7"),
    ("ZZ", "QQ", @symcore.int(4), "4"),
    ("ZZ", "QQ", try! @symcore.rational_from_ints(1, 2), "1/2"),
    ("QQ_I", "ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("QQ[x]", "ZZ[x]", x + @symcore.int(1), "x + 1"),
    ("ZZ[x]", "QQ[x]", (@symcore.int(2) * x) + @symcore.int(1), "2*x + 1"),
    ("ZZ[x]", "QQ[x]", (try! @symcore.rational_from_ints(1, 2)) * x, "x/2"),
    ("QQ(x)", "ZZ[x]", (x ^ @symcore.int(2)) + @symcore.int(1), "x**2 + 1"),
    ("QQ[x]", "QQ(x)", x + @symcore.int(1), "x + 1"),
    ("QQ<sqrt(2)>", "QQ", try! @symcore.rational_from_ints(3, 2), "3/2"),
  ]
  for item in convert_cases {
    let target = item.0
    let base = item.1
    let expr = item.2
    let expr_text = item.3
    let ours = render_expr_result(try? domain_from_string(target).convert_from_expr(expr, domain_from_string(base)))
    let oracle = normalize_expr_text(@sympy_polys.domain_convert_from_expr(target, expr_text, base))
    guard ours == oracle else {
      fail("convert_from parity mismatch for \{target} <- \{base} using \{expr_text}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

///|
test "domains: is_unit/is_zero/is_one parity on core domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-1), "-1"),
    ("ZZ", @symcore.int(2), "2"),
    ("QQ", try! @symcore.rational_from_ints(2, 3), "2/3"),
    ("QQ", @symcore.int(0), "0"),
    ("ZZ[x]", @symcore.int(1), "1"),
    ("ZZ[x]", x, "x"),
    ("QQ[x]", try! @symcore.rational_from_ints(2, 3), "2/3"),
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
    let ours = domain_from_string(spec).is_unit_expr(expr)
    let oracle = @sympy_polys.domain_is_unit_expr(spec, expr_text)
    guard ours == oracle else {
      fail("is_unit mismatch for \{spec} and \{expr_text}: ours=\{ours}, oracle=\{oracle}")
    }
  }

  guard domain_from_string("QQ").is_zero_expr(@symcore.int(0)) else {
    fail("is_zero_expr mismatch")
  }
  guard domain_from_string("QQ").is_one_expr(@symcore.int(1)) else {
    fail("is_one_expr mismatch")
  }
  guard !domain_from_string("QQ").is_one_expr(@symcore.int(2)) else {
    fail("is_one_expr false positive")
  }
}

///|
test "domains: zero/one and arithmetic wrapper parity" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let zero_one_specs = ["ZZ", "QQ", "GF(5)", "QQ_I", "ZZ[x]", "QQ(x)", "QQ<sqrt(2)>"]
  for spec in zero_one_specs {
    let domain = domain_from_string(spec)
    let ours_zero = render_expr_result(try? domain.zero_expr())
    let oracle_zero = normalize_expr_text(@sympy_polys.domain_zero_expr(spec))
    guard ours_zero == oracle_zero else {
      fail("zero parity mismatch for \{spec}: ours=\{ours_zero}, oracle=\{oracle_zero}")
    }
    let ours_one = render_expr_result(try? domain.one_expr())
    let oracle_one = normalize_expr_text(@sympy_polys.domain_one_expr(spec))
    guard ours_one == oracle_one else {
      fail("one parity mismatch for \{spec}: ours=\{ours_one}, oracle=\{oracle_one}")
    }
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
    let domain = domain_from_string(spec)
    let ours_pos = render_expr_result(try? domain.pos_expr(expr))
    let oracle_pos = normalize_expr_text(@sympy_polys.domain_pos_expr(spec, expr_text))
    guard ours_pos == oracle_pos else {
      fail("pos parity mismatch for \{spec} and \{expr_text}: ours=\{ours_pos}, oracle=\{oracle_pos}")
    }
    let ours_neg = render_expr_result(try? domain.neg_expr(expr))
    let oracle_neg = normalize_expr_text(@sympy_polys.domain_neg_expr(spec, expr_text))
    guard ours_neg == oracle_neg else {
      fail("neg parity mismatch for \{spec} and \{expr_text}: ours=\{ours_neg}, oracle=\{oracle_neg}")
    }
  }

  let binary_cases : Array[(String, @symcore.Expr, @symcore.Expr, String, String)] = [
    ("QQ", try! @symcore.rational_from_ints(1, 2), try! @symcore.rational_from_ints(1, 3), "1/2", "1/3"),
    ("ZZ_I", @symcore.add([@symcore.int(2), i]), @symcore.add([@symcore.int(1), @symcore.int(-1) * i]), "2 + I", "1 - I"),
    ("QQ(x)", (x + @symcore.int(1)) * ((x - @symcore.int(1)) ^ @symcore.int(-1)), x - @symcore.int(1), "(x + 1)/(x - 1)", "x - 1"),
    ("ZZ[x]", x + @symcore.int(1), x - @symcore.int(1), "x + 1", "x - 1"),
  ]
  for item in binary_cases {
    let spec = item.0
    let left = item.1
    let right = item.2
    let left_text = item.3
    let right_text = item.4
    let domain = domain_from_string(spec)
    let ours_add = render_expr_result(try? domain.add_expr(left, right))
    let oracle_add = normalize_expr_text(@sympy_polys.domain_add_expr(spec, left_text, right_text))
    guard ours_add == oracle_add else {
      fail("add parity mismatch for \{spec}: ours=\{ours_add}, oracle=\{oracle_add}")
    }
    let ours_sub = render_expr_result(try? domain.sub_expr(left, right))
    let oracle_sub = normalize_expr_text(@sympy_polys.domain_sub_expr(spec, left_text, right_text))
    guard ours_sub == oracle_sub else {
      fail("sub parity mismatch for \{spec}: ours=\{ours_sub}, oracle=\{oracle_sub}")
    }
    let ours_mul = render_expr_result(try? domain.mul_expr(left, right))
    let oracle_mul = normalize_expr_text(@sympy_polys.domain_mul_expr(spec, left_text, right_text))
    guard ours_mul == oracle_mul else {
      fail("mul parity mismatch for \{spec}: ours=\{ours_mul}, oracle=\{oracle_mul}")
    }
  }

  let pow_cases : Array[(String, @symcore.Expr, Int, String)] = [
    ("QQ", try! @symcore.rational_from_ints(2, 3), 3, "2/3"),
    ("QQ", try! @symcore.rational_from_ints(2, 3), -2, "2/3"),
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
    let ours = render_expr_result(try? domain_from_string(spec).pow_expr(expr, exp))
    let oracle = normalize_expr_text(@sympy_polys.domain_pow_expr(spec, expr_text, exp))
    guard ours == oracle else {
      fail("pow parity mismatch for \{spec}, exp=\{exp}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

///|
test "domains: gcdex/invert/revert wrapper parity" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let gcdex_cases : Array[(String, @symcore.Expr, @symcore.Expr, String, String)] = [
    ("ZZ", @symcore.int(6), @symcore.int(15), "6", "15"),
  ]
  for item in gcdex_cases {
    let spec = item.0
    let left = item.1
    let right = item.2
    let left_text = item.3
    let right_text = item.4
    let domain = domain_from_string(spec)
    let ours_half = render_expr_pair_result(try? domain.half_gcdex_expr(left, right))
    let oracle_half = normalize_expr_tuple2_text(@sympy_polys.domain_half_gcdex_expr(spec, left_text, right_text))
    guard ours_half == oracle_half else {
      fail("half_gcdex parity mismatch for \{spec}: ours=\{ours_half}, oracle=\{oracle_half}")
    }
    let ours_full = render_expr_triple_result(try? domain.gcdex_expr(left, right))
    let oracle_full = normalize_expr_tuple3_text(@sympy_polys.domain_gcdex_expr(spec, left_text, right_text))
    guard ours_full == oracle_full else {
      fail("gcdex parity mismatch for \{spec}: ours=\{ours_full}, oracle=\{oracle_full}")
    }
  }

  let qq_left = try! @symcore.rational_from_ints(2, 3)
  let qq_right = try! @symcore.rational_from_ints(4, 9)
  guard
    render_expr_pair_result(try? domain_from_string("QQ").half_gcdex_expr(qq_left, qq_right)) ==
    "(1/3,2/9)"
  else {
    fail("QQ half_gcdex local behavior mismatch")
  }
  guard
    render_expr_triple_result(try? domain_from_string("QQ").gcdex_expr(qq_left, qq_right)) ==
    "(1/3,0,2/9)"
  else {
    fail("QQ gcdex local behavior mismatch")
  }

  let zzi_left = @symcore.add([@symcore.int(2), i])
  let zzi_right = @symcore.add([@symcore.int(1), @symcore.int(-1) * i])
  let zzi = domain_from_string("ZZ_I")
  let zzi_half = try! zzi.half_gcdex_expr(zzi_left, zzi_right)
  guard render_expr_result(Ok(zzi_half.1)) == "1" else {
    fail("ZZ_I half_gcdex gcd mismatch")
  }
  let zzi_full = try! zzi.gcdex_expr(zzi_left, zzi_right)
  guard render_expr_result(Ok(zzi_full.2)) == "1" else {
    fail("ZZ_I gcdex gcd mismatch")
  }
  let zzi_bezout = try! zzi.add_expr(
    try! zzi.mul_expr(zzi_left, zzi_full.0),
    try! zzi.mul_expr(zzi_right, zzi_full.1),
  )
  guard render_expr_result(Ok(zzi_bezout)) == "1" else {
    fail("ZZ_I gcdex Bezout mismatch")
  }

  let qqx_left = (x ^ @symcore.int(2)) - @symcore.int(1)
  let qqx_right = x - @symcore.int(1)
  let qqx = domain_from_string("QQ[x]")
  let qqx_half = try! qqx.half_gcdex_expr(qqx_left, qqx_right)
  guard render_expr_result(Ok(qqx_half.1)) == "x-1" else {
    fail("QQ[x] half_gcdex gcd mismatch")
  }
  let qqx_full = try! qqx.gcdex_expr(qqx_left, qqx_right)
  guard render_expr_result(Ok(qqx_full.2)) == "x-1" else {
    fail("QQ[x] gcdex gcd mismatch")
  }
  let qqx_bezout = try! qqx.add_expr(
    try! qqx.mul_expr(qqx_left, qqx_full.0),
    try! qqx.mul_expr(qqx_right, qqx_full.1),
  )
  guard render_expr_result(Ok(qqx_bezout)) == "x-1" else {
    fail("QQ[x] gcdex Bezout mismatch")
  }

  let invert_cases : Array[(String, @symcore.Expr, @symcore.Expr, String, String)] = [
    ("ZZ", @symcore.int(3), @symcore.int(7), "3", "7"),
    ("ZZ", @symcore.int(2), @symcore.int(4), "2", "4"),
    ("QQ[x]", x + @symcore.int(1), (x ^ @symcore.int(2)) + @symcore.int(1), "x + 1", "x**2 + 1"),
  ]
  for item in invert_cases {
    let spec = item.0
    let left = item.1
    let right = item.2
    let left_text = item.3
    let right_text = item.4
    let ours = render_expr_result(try? domain_from_string(spec).invert_expr(left, right))
    let oracle = normalize_expr_text(@sympy_polys.domain_invert_expr(spec, left_text, right_text))
    guard ours == oracle else {
      fail("invert parity mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }

  let revert_cases : Array[(String, @symcore.Expr, String)] = [
    ("QQ", try! @symcore.rational_from_ints(2, 3), "2/3"),
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
    let ours = render_expr_result(try? domain_from_string(spec).revert_expr(expr))
    let oracle = normalize_expr_text(@sympy_polys.domain_revert_expr(spec, expr_text))
    guard ours == oracle else {
      fail("revert parity mismatch for \{spec}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

test "domains: sign predicate parity on ordered and composite domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let neg_x = @symcore.mul([@symcore.int(-1), x])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-2), "-2"),
    ("QQ", try! @symcore.rational_from_ints(2, 3), "2/3"),
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
    let domain = domain_from_string(spec)
    let ours_positive = domain.is_positive_expr(expr)
    let ours_negative = domain.is_negative_expr(expr)
    let ours_nonpositive = domain.is_nonpositive_expr(expr)
    let ours_nonnegative = domain.is_nonnegative_expr(expr)
    let oracle_positive = @sympy_polys.domain_is_positive_expr(spec, expr_text)
    let oracle_negative = @sympy_polys.domain_is_negative_expr(spec, expr_text)
    let oracle_nonpositive = @sympy_polys.domain_is_nonpositive_expr(spec, expr_text)
    let oracle_nonnegative = @sympy_polys.domain_is_nonnegative_expr(spec, expr_text)
    guard ours_positive == oracle_positive else {
      fail(
        "is_positive mismatch for \{spec} and \{expr_text}: ours=\{ours_positive}, oracle=\{oracle_positive}",
      )
    }
    guard ours_negative == oracle_negative else {
      fail(
        "is_negative mismatch for \{spec} and \{expr_text}: ours=\{ours_negative}, oracle=\{oracle_negative}",
      )
    }
    guard ours_nonpositive == oracle_nonpositive else {
      fail(
        "is_nonpositive mismatch for \{spec} and \{expr_text}: ours=\{ours_nonpositive}, oracle=\{oracle_nonpositive}",
      )
    }
    guard ours_nonnegative == oracle_nonnegative else {
      fail(
        "is_nonnegative mismatch for \{spec} and \{expr_text}: ours=\{ours_nonnegative}, oracle=\{oracle_nonnegative}",
      )
    }
  }

  let minus_one = @symcore.int(-1)
  guard domain_from_string("ZZ").is_negative_one_expr(minus_one) else {
    fail("is_negative_one_expr mismatch")
  }

  let zz_series = domain_from_string("ZZ[[x]](prec=5)")
  guard !zz_series.is_positive_expr(x) && !zz_series.is_negative_expr(x) &&
    zz_series.is_nonpositive_expr(x) && zz_series.is_nonnegative_expr(x) else {
    fail("power-series sign semantics mismatch")
  }
}

test "domains: canonical_unit parity on scalar and composite domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-2), "-2"),
    ("QQ", try! @symcore.rational_from_ints(-2, 3), "-2/3"),
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
    let ours = render_expr_result(try? domain_from_string(spec).canonical_unit_expr(expr))
    let oracle = normalize_expr_text(@sympy_polys.domain_canonical_unit_expr(spec, expr_text))
    guard ours == oracle else {
      fail(
        "canonical_unit mismatch for \{spec} and \{expr_text}: ours=\{ours}, oracle=\{oracle}",
      )
    }
  }

  let zz_series = domain_from_string("ZZ[[x]](prec=5)")
  guard
    trim_ws(@symprint.to_string(try! zz_series.canonical_unit_expr(@symcore.int(-1) + x))) ==
    "-1"
  else {
    fail("power-series canonical_unit should follow constant coefficient")
  }
}

test "domains: abs parity on supported/error domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(-2), "-2"),
    ("QQ", try! @symcore.rational_from_ints(-2, 3), "-2/3"),
    ("EX", @symcore.int(-1) * x, "-x"),
    ("EX", @symcore.add([@symcore.int(2), i]), "2 + I"),
    ("ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let ours = render_expr_result(try? domain_from_string(spec).abs_expr(expr))
    let oracle = normalize_expr_text(@sympy_polys.domain_abs_expr(spec, expr_text))
    guard ours == oracle else {
      fail("abs mismatch for \{spec} and \{expr_text}: ours=\{ours}, oracle=\{oracle}")
    }
  }
}

test "domains: gcd/lcm/cofactors parity on scalar and composite domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(6), "6", @symcore.int(4), "4"),
    ("QQ", try! @symcore.rational_from_ints(2, 3), "2/3", try! @symcore.rational_from_ints(4, 9), "4/9"),
    ("ZZ_I", @symcore.add([@symcore.int(2), i]), "2 + I", @symcore.add([@symcore.int(1), @symcore.int(-1) * i]), "1 - I"),
    ("QQ_I", @symcore.int(2), "2", @symcore.int(4), "4"),
    ("EX", x, "x", @symcore.int(2), "2"),
    ("ZZ[x]", (x ^ @symcore.int(2)) - @symcore.int(1), "x**2 - 1", x - @symcore.int(1), "x - 1"),
    ("QQ[x]", x, "x", @symcore.int(2), "2"),
    ("QQ(x)", try! @symcore.rational_from_ints(2, 1) * (x ^ @symcore.int(-1)), "2/x", try! @symcore.rational_from_ints(4, 1) * (x ^ @symcore.int(-2)), "4/x**2"),
    ("QQ<sqrt(2)>", @symcore.int(1) + sqrt2, "1 + sqrt(2)", @symcore.int(2), "2"),
  ]
  for item in cases {
    let spec = item.0
    let left = item.1
    let left_text = item.2
    let right = item.3
    let right_text = item.4
    let domain = domain_from_string(spec)
    let ours_gcd = render_expr_result(try? domain.gcd_expr(left, right))
    let ours_lcm = render_expr_result(try? domain.lcm_expr(left, right))
    let ours_cof = render_expr_triple_result(try? domain.cofactors_expr(left, right))
    let oracle_gcd = normalize_expr_text(@sympy_polys.domain_gcd_expr(spec, left_text, right_text))
    let oracle_lcm = normalize_expr_text(@sympy_polys.domain_lcm_expr(spec, left_text, right_text))
    let oracle_cof = normalize_expr_tuple3_text(@sympy_polys.domain_cofactors_expr(spec, left_text, right_text))
    guard ours_gcd == oracle_gcd else {
      fail("gcd mismatch for \{spec}: ours=\{ours_gcd}, oracle=\{oracle_gcd}")
    }
    guard ours_lcm == oracle_lcm else {
      fail("lcm mismatch for \{spec}: ours=\{ours_lcm}, oracle=\{oracle_lcm}")
    }
    guard ours_cof == oracle_cof else {
      fail("cofactors mismatch for \{spec}: ours=\{ours_cof}, oracle=\{oracle_cof}")
    }
  }
}

test "domains: numer/denom parity on scalar and fraction-like domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let sqrt2 = @symcore.function("sqrt", [@symcore.int(2)])
  let cases : Array[(String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(7), "7"),
    ("QQ", try! @symcore.rational_from_ints(7, 3), "7/3"),
    ("ZZ_I", @symcore.add([@symcore.int(3), i]), "3 + I"),
    ("QQ_I", try! @symcore.rational_from_ints(1, 2) + (try! @symcore.rational_from_ints(1, 3) * i), "1/2 + I/3"),
    ("EX", x, "x"),
    ("GF(5)", @symcore.int(3), "3"),
    ("QQ(x)", (x + @symcore.int(1)) * ((x - @symcore.int(1)) ^ @symcore.int(-1)), "(x + 1)/(x - 1)"),
    ("QQ<sqrt(2)>", @symcore.int(1) + sqrt2, "1 + sqrt(2)"),
  ]
  for item in cases {
    let spec = item.0
    let expr = item.1
    let expr_text = item.2
    let domain = domain_from_string(spec)
    let ours_num = render_expr_result(try? domain.numer_expr(expr))
    let ours_den = render_expr_result(try? domain.denom_expr(expr))
    let oracle_num = normalize_expr_text(@sympy_polys.domain_numer_expr(spec, expr_text))
    let oracle_den = normalize_expr_text(@sympy_polys.domain_denom_expr(spec, expr_text))
    guard ours_num == oracle_num else {
      fail("numer mismatch for \{spec}: ours=\{ours_num}, oracle=\{oracle_num}")
    }
    guard ours_den == oracle_den else {
      fail("denom mismatch for \{spec}: ours=\{ours_den}, oracle=\{oracle_den}")
    }
  }
}

test "domains: quo/rem/div/exquo parity on scalar and composite domains" {
  let x = @symcore.symbol("x")
  let i = @symcore.symbol("I")
  let cases : Array[(String, @symcore.Expr, String, @symcore.Expr, String)] = [
    ("ZZ", @symcore.int(7), "7", @symcore.int(3), "3"),
    ("QQ", try! @symcore.rational_from_ints(7, 3), "7/3", try! @symcore.rational_from_ints(2, 3), "2/3"),
    ("ZZ_I", @symcore.add([@symcore.int(3), i]), "3 + I", @symcore.add([@symcore.int(1), @symcore.int(-1) * i]), "1 - I"),
    ("QQ_I", @symcore.int(2), "2", @symcore.int(4), "4"),
    ("ZZ[x]", (x ^ @symcore.int(2)) - @symcore.int(1), "x**2 - 1", x - @symcore.int(1), "x - 1"),
    ("QQ[x]", x, "x", @symcore.int(2), "2"),
    ("QQ(x)", try! @symcore.rational_from_ints(2, 1) * (x ^ @symcore.int(-1)), "2/x", try! @symcore.rational_from_ints(4, 1) * (x ^ @symcore.int(-2)), "4/x**2"),
  ]
  for item in cases {
    let spec = item.0
    let left = item.1
    let left_text = item.2
    let right = item.3
    let right_text = item.4
    let domain = domain_from_string(spec)
    let ours_quo = render_expr_result(try? domain.quo_expr(left, right))
    let ours_rem = render_expr_result(try? domain.rem_expr(left, right))
    let ours_div = render_expr_pair_result(try? domain.div_expr(left, right))
    let ours_exquo = render_expr_result(try? domain.exquo_expr(left, right))
    let oracle_quo = normalize_expr_text(@sympy_polys.domain_quo_expr(spec, left_text, right_text))
    let oracle_rem = normalize_expr_text(@sympy_polys.domain_rem_expr(spec, left_text, right_text))
    let oracle_div = normalize_expr_tuple2_text(@sympy_polys.domain_div_expr(spec, left_text, right_text))
    let oracle_exquo = normalize_expr_text(@sympy_polys.domain_exquo_expr(spec, left_text, right_text))
    guard ours_quo == oracle_quo else {
      fail("quo mismatch for \{spec}: ours=\{ours_quo}, oracle=\{oracle_quo}")
    }
    guard ours_rem == oracle_rem else {
      fail("rem mismatch for \{spec}: ours=\{ours_rem}, oracle=\{oracle_rem}")
    }
    guard ours_div == oracle_div else {
      fail("div mismatch for \{spec}: ours=\{ours_div}, oracle=\{oracle_div}")
    }
    guard ours_exquo == oracle_exquo else {
      fail("exquo mismatch for \{spec}: ours=\{ours_exquo}, oracle=\{oracle_exquo}")
    }
  }

  let exact_fail = render_expr_result(
    try? domain_from_string("ZZ").exquo_expr(@symcore.int(7), @symcore.int(3)),
  )
  guard exact_fail == "ERROR" else {
    fail("ZZ exquo should reject non-exact quotient")
  }
}
