///|
test "polys domain worker distinguishes missing attribute policies" {
  let strict_missing = try {
    domain_attr_bool_query("ZZ", "__symbit_missing_domain_attr__") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(strict_missing)
  assert_false(
    domain_attr_bool_or_false("ZZ", "__symbit_missing_domain_attr__"),
  )
  assert_false(domain_attr_bool_query("ZZ", "characteristic"))
  assert_false(domain_attr_bool_or_false("ZZ", "characteristic"))
  assert_true(domain_is_ring("ZZ"))
}

///|
test "polys domain worker parses exact specs and finite field aliases" {
  assert_eq(domain_repr("ZZ"), "ZZ")
  assert_eq(domain_repr("QQ"), "QQ")
  assert_eq(domain_repr("ZZ_I"), "ZZ_I")
  assert_eq(domain_repr("EXRAW"), "EXRAW")
  assert_eq(
    domain_repr("IntegerRing"),
    "<class 'sympy.polys.domains.integerring.IntegerRing'>",
  )
  assert_eq(domain_repr("ZZ[x](y)"), "ZZ[x](y)")
  assert_eq(domain_repr("FF(5,2)"), domain_repr("GF(25)"))
  assert_eq(domain_repr("FiniteField(5**2)"), domain_repr("GF(25)"))
  assert_eq(domain_repr("GF(5**0)"), domain_repr("GF(1)"))
  assert_eq(domain_repr("GF(5**-2)"), domain_repr("GF(1)"))
}

///|
test "polys domain worker rejects an unknown spec and recovers" {
  let rejected_specs = [
    "DefinitelyMissingDomain", "GaussianIntegerRing", "ExpressionRawDomain", "GF(5,,2)",
    "QQ<sqrt(2),>",
  ]
  for spec in rejected_specs {
    let rejected = try {
      domain_repr(spec) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_eq(domain_repr("ZZ"), "ZZ")
  assert_eq(domain_characteristic("GF(11)"), 11)
}

///|
test "polys domain constructors keep generator names literal" {
  assert_eq(domain_poly_ring("ZZ", ["x y,z"]), "ZZ[x y,z]")
  assert_eq(domain_frac_field("QQ", ["q'quoted"]), "QQ(q'quoted)")
  assert_eq(domain_inject("ZZ", ["x y,z"]), "ZZ[x y,z]")
  assert_eq(domain_drop("ZZ[x]", ["x"]), "ZZ")
}

///|
test "polys domain constructors preserve ERROR and defaults" {
  assert_eq(domain_get_ring("CC"), "ERROR")
  assert_eq(domain_get_ring("EXRAW"), "ERROR")
  assert_eq(domain_cyclotomic_field("QQ", 5), "QQ<zeta>")
  assert_eq(
    domain_alg_field_from_poly("QQ", "x**2 - 2", "x"),
    "QQ<CRootOf(x**2 - 2, 1)>",
  )
}
