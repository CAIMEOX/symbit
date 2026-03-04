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
test "domains: unify parity for key coercion paths" {
  let zz_qq = domain_unify_pair(Domain::ZZ, Domain::QQ)
  let zz_qq_oracle = @sympy_polys.domain_unify("ZZ", "QQ")
  guard trim_ws(domain_to_sympy_string(zz_qq)) == trim_ws(zz_qq_oracle) else {
    fail("unify ZZ+QQ mismatch")
  }

  let zxy_q = domain_unify_pair(domain_from_string("ZZ[x]"), Domain::QQ)
  let zxy_q_oracle = @sympy_polys.domain_unify("ZZ[x]", "QQ")
  guard trim_ws(domain_to_sympy_string(zxy_q)) == trim_ws(zxy_q_oracle) else {
    fail("unify ZZ[x]+QQ mismatch")
  }

  let zzi_qqi = domain_unify_pair(Domain::ZZ_I, Domain::QQ_I)
  guard domain_to_sympy_string(zzi_qqi) == "QQ_I" else {
    fail("expected ZZ_I unify QQ_I -> QQ_I")
  }
}
