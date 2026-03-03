///|
fn fw_const(n : Int, domain : Domain) -> Poly raise PolyError {
  Poly::from_expr(@symcore.int(n), ["x"], domain)
}

///|
fn fw_univar(expr : @symcore.Expr, domain : Domain) -> Poly raise PolyError {
  PolyBuilder::new(["x"], domain).from_expr(expr)
}

///|
test "factor wb: extension and univariate guard branches" {
  let one = try! fw_const(1, Domain::QQ)
  let two = try! fw_const(2, Domain::QQ)
  guard is_one(one) else { fail("is_one should accept constant one") }
  guard !is_one(two) else { fail("is_one should reject non-one constants") }

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let non_uni = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)

  let deriv_bad : Result[Poly, PolyError] = try? deriv_univar(non_uni)
  guard deriv_bad is Err(PolyError::NotUnivariate) else {
    fail("deriv_univar should reject multivariate input")
  }

  let gf_poly = try! fw_univar(
    (x ^ @symcore.int(3)) + @symcore.int(1),
    Domain::GF(5),
  )
  let root_bad : Result[Poly, PolyError] = try? pth_root_univar_gf(gf_poly, 2)
  guard root_bad is Err(PolyError::BadExponent) else {
    fail("pth_root_univar_gf should reject exponents not divisible by p")
  }

  let ext_none = try! apply_extension_request(gf_poly, [])
  guard ext_none.domain == gf_poly.domain else {
    fail("apply_extension_request(empty) should keep domain unchanged")
  }

  let ext_bad : Result[Poly, PolyError] = try? apply_extension_request(two, ["a", "b"])
  guard ext_bad is Err(PolyError::BadGenerator("extension")) else {
    fail("apply_extension_request should reject multiple extension symbols")
  }

  let zz_poly = try! fw_univar(
    (x ^ @symcore.int(2)) + @symcore.int(1),
    Domain::ZZ,
  )
  let lifted = try! apply_extension_request(zz_poly, ["a"])
  guard lifted.domain == Domain::QQ else {
    fail("apply_extension_request should lift ZZ to QQ for extension request")
  }

  let factor_bad_gens : Result[Array[(Poly, Int)], PolyError] = try? zz_poly.factor(
    gens=["y"],
  )
  guard factor_bad_gens is Err(PolyError::DomainMismatch) else {
    fail("Poly.factor should validate explicit gens")
  }

  let factor_bad_mod : Result[Array[(Poly, Int)], PolyError] = try? zz_poly.factor(
    modulus=1,
  )
  guard factor_bad_mod is Err(PolyError::BadModulus) else {
    fail("Poly.factor should reject modulus <= 1")
  }
}

///|
test "factor wb: determinant/resultant helper branches" {
  let d0 = try! poly_det([], Domain::QQ, "x")
  inspect(d0.to_string(), content="1")

  let d1 = try! poly_det([[try! fw_const(2, Domain::QQ)]], Domain::QQ, "x")
  inspect(d1.to_string(), content="2")

  let singular = try! poly_det(
    [
      [try! fw_const(0, Domain::QQ), try! fw_const(1, Domain::QQ)],
      [try! fw_const(0, Domain::QQ), try! fw_const(2, Domain::QQ)],
    ],
    Domain::QQ,
    "x",
  )
  inspect(singular.to_string(), content="0")

  let swapped = try! poly_det(
    [
      [try! fw_const(0, Domain::QQ), try! fw_const(1, Domain::QQ)],
      [try! fw_const(1, Domain::QQ), try! fw_const(0, Domain::QQ)],
    ],
    Domain::QQ,
    "x",
  )
  inspect(swapped.to_string(), content="-1")

  let d3 = try! poly_det(
    [
      [
        try! fw_const(1, Domain::QQ),
        try! fw_const(2, Domain::QQ),
        try! fw_const(3, Domain::QQ),
      ],
      [
        try! fw_const(4, Domain::QQ),
        try! fw_const(5, Domain::QQ),
        try! fw_const(6, Domain::QQ),
      ],
      [
        try! fw_const(7, Domain::QQ),
        try! fw_const(8, Domain::QQ),
        try! fw_const(10, Domain::QQ),
      ],
    ],
    Domain::QQ,
    "x",
  )
  guard !d3.is_zero() else {
    fail("3x3 determinant branch should produce non-zero result")
  }

  let rz = try! resultant_poly_coeffs(
    [try! fw_const(1, Domain::QQ)],
    [try! fw_const(2, Domain::QQ)],
    Domain::QQ,
    "x",
  )
  inspect(rz.to_string(), content="0")
}

///|
test "factor wb: GF splitting and seed helpers" {
  let x = @symcore.symbol("x")
  let gf_poly = try! fw_univar(
    (x ^ @symcore.int(2)) + @symcore.int(1),
    Domain::GF(5),
  )
  let edf_same = try! equal_degree_factor(gf_poly, 2, 5, 5, 1, 17, None)
  guard edf_same.length() == 1 else {
    fail("equal_degree_factor(deg=d) should return singleton")
  }

  let edf_try = try! equal_degree_factor(gf_poly, 1, 5, 5, 1, 19, None)
  guard !edf_try.is_empty() else {
    fail("equal_degree_factor should return at least one factor")
  }

  let seeded = try! field_elem_from_seed(7, 3, 3, None, Domain::GFExt(3, 3, [1, 0, 0, 1]))
  match seeded {
    FieldElem::GFExt(_, coeffs, mod_poly) => {
      guard coeffs.length() == 3 && coeffs[0] == 1 && coeffs[1] == 2 && mod_poly.length() == 0 else {
        fail("field_elem_from_seed GFExt(None) branch mismatch")
      }
    }
    _ => fail("field_elem_from_seed should build GFExt coefficient")
  }

  let c0 = try! poly_const_from_fe(FieldElem::QQ(@symnum.BigRational::zero()), ["x"], Domain::QQ)
  guard c0.is_zero() else { fail("poly_const_from_fe(0) should return zero polynomial") }

  let y = @symcore.symbol("y")
  let non_uni = PolyBuilder::new(["x", "y"], Domain::GF(5)).from_expr(x + y)
  let bad_gf_seeded : Result[Array[Poly], PolyError] = try? factor_gf_seeded(non_uni, 11)
  guard bad_gf_seeded is Err(PolyError::NotUnivariate) else {
    fail("factor_gf_seeded should reject multivariate input")
  }

  let bad_eval_mod : Result[Int, PolyError] = try? eval_univar_mod(gf_poly, 1, 1)
  guard bad_eval_mod is Err(PolyError::BadModulus) else {
    fail("eval_univar_mod should reject modulus <= 1")
  }

  let lin_bad : Result[Array[Poly], PolyError] = try? factor_linear_rationals(
    PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y),
  )
  guard lin_bad is Err(PolyError::NotUnivariate) else {
    fail("factor_linear_rationals should reject multivariate input")
  }
}

///|
test "factor wb: algext conversion and factoring helper branches" {
  let a = @symcore.symbol("a")
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let rel = (a ^ @symcore.int(2)) + @symcore.int(1)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let (minpoly, _) = try! load_algext_minpoly(Domain::QQ, ["a"], [rel])

  let zero_alg = Poly::zero(["x"], alg_domain)
  let sf_zero = try! factor_algext_squarefree(zero_alg, Domain::QQ, minpoly)
  guard sf_zero.length() == 0 else {
    fail("factor_algext_squarefree(0) should return []")
  }

  let lin_alg = try! fw_univar(x + @symcore.int(1), alg_domain)
  let sf_lin = try! factor_algext_squarefree(lin_alg, Domain::QQ, minpoly)
  guard sf_lin.length() == 1 else {
    fail("factor_algext_squarefree(linear) should return singleton")
  }

  let bad_factor_domain : Result[Array[Poly], PolyError] = try? factor_algext(
    try! fw_univar(x + @symcore.int(1), Domain::QQ),
  )
  guard bad_factor_domain is Err(PolyError::DomainMismatch) else {
    fail("factor_algext should reject non-AlgExt domain")
  }

  let bad_factor_nonuni : Result[Array[Poly], PolyError] = try? factor_algext(
    PolyBuilder::new(["x", "y"], alg_domain).from_expr(x + y),
  )
  guard bad_factor_nonuni is Err(PolyError::NotUnivariate) else {
    fail("factor_algext should reject multivariate input")
  }

  let coeffs : Map[Monomial, FieldElem] = Map::new()
  coeffs.set(Monomial::{ exps: [1] }, FieldElem::QQ(@symnum.BigRational::one()))
  coeffs.set(
    Monomial::{ exps: [0] },
    FieldElem::AlgExt(
      Domain::QQ,
      [FieldElem::QQ(@symnum.BigRational::one()), FieldElem::QQ(@symnum.BigRational::one())],
      minpoly,
      "a",
    ),
  )
  let mixed_alg_poly = Poly::{
    coeffs,
    gens: ["x"],
    domain: alg_domain,
    order: TermOrder::Lex,
  }
  let t_coeffs = try! algext_poly_to_t_coeffs(mixed_alg_poly, Domain::QQ, "x")
  guard t_coeffs.length() >= 2 else {
    fail("algext_poly_to_t_coeffs should allocate buckets up to max AlgExt degree")
  }

  let m_coeffs = try! minpoly_to_t_coeffs(minpoly, Domain::QQ, "x")
  guard m_coeffs.length() == minpoly.degree(0) + 1 else {
    fail("minpoly_to_t_coeffs length mismatch")
  }

  let base_poly = try! fw_univar((x ^ @symcore.int(2)) + @symcore.int(1), Domain::QQ)
  let lifted = try! lift_base_poly_to_algext(base_poly, alg_domain)
  guard lifted.domain == alg_domain else {
    fail("lift_base_poly_to_algext should move coefficients to AlgExt domain")
  }

  let _ = int_pow(3, 4)
}
