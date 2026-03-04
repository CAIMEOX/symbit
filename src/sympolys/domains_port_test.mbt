///|
fn trim_ws(s : String) -> String {
  s.replace_all(old=" ", new="")
}

///|
test "domains: basic constructor/repr parity" {
  let specs = ["ZZ", "QQ", "RR", "CC", "ZZ_I", "QQ_I", "EX", "EXRAW", "GF(7)"]
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
    ("ZZ[x]", "QQ"),
    ("ZZ[x]", "QQ(y)"),
    ("QQ(x)", "ZZ[y]"),
    ("QQ(x)", "ZZ(y)"),
    ("ZZ[x]", "ZZ[y]"),
    ("QQ(x)", "QQ(y)"),
    ("ZZ_I", "QQ_I"),
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
test "domains: extended parser handles Frac and GFExt syntax" {
  let frac = domain_from_string("Frac(ZZ[x])")
  guard domain_to_sympy_string(frac) == "Frac(ZZ[x])" else {
    fail("Frac parser mismatch")
  }
  let gfext = domain_from_string("GF(5**2)")
  guard domain_to_sympy_string(gfext) == "GF(5**2)" else {
    fail("GFExt parser mismatch")
  }
}
