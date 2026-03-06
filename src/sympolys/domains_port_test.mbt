///|
fn trim_ws(s : String) -> String {
  s.replace_all(old=" ", new="")
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
    ("QQ<sqrt(2)>", "QQ[x]"),
    ("QQ<sqrt(2)>", "QQ(x)"),
    ("QQ<sqrt(2)>", "RR[x]"),
    ("QQ<sqrt(2)>", "RR(x)"),
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
