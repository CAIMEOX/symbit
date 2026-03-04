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

///|
test "factor wb: high-gap branch sweep" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let a = @symcore.symbol("a")

  let pth_nonuni : Result[Poly, PolyError] = try? pth_root_univar_gf(
    PolyBuilder::new(["x", "y"], Domain::GF(3)).from_expr(x + y),
    3,
  )
  guard pth_nonuni is Err(PolyError::NotUnivariate) else {
    fail("pth_root_univar_gf should reject multivariate input")
  }
  let pth_zero = try! pth_root_univar_gf(Poly::zero(["x"], Domain::GF(3)), 3)
  guard pth_zero.is_zero() else { fail("pth_root_univar_gf(0) should be 0") }

  let sqf_nonuni : Result[Array[(Poly, Int)], PolyError] = try? square_free_decompose(
    PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y),
  )
  guard sqf_nonuni is Err(PolyError::NotUnivariate) else {
    fail("square_free_decompose should reject multivariate input")
  }
  guard (try! square_free_decompose(Poly::zero(["x"], Domain::QQ))).length() == 0 else {
    fail("square_free_decompose(0) should be empty")
  }
  let gfext_domain = Domain::GFExt(5, 2, [1, 0, 1])
  let sqf_gfext = try! square_free_decompose(
    PolyBuilder::new(["x"], gfext_domain).from_expr((x ^ @symcore.int(5)) + @symcore.int(1)),
  )
  guard sqf_gfext.length() == 1 && sqf_gfext[0].1 == 1 else {
    fail("square_free_decompose GFExt derivative-zero fallback mismatch")
  }

  let qq_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let ext_passthrough = try! apply_extension_request(qq_poly, ["a"])
  guard ext_passthrough.domain == Domain::QQ else {
    fail("apply_extension_request on non-ZZ should preserve domain")
  }

  let zero_zz = Poly::zero(["x"], Domain::ZZ)
  guard (try! zero_zz.factor()).length() == 0 else { fail("factor(0) should be []") }
  let fl_zero = try! zero_zz.factor_list()
  guard fl_zero.0.is_zero() && fl_zero.1.length() == 0 else {
    fail("factor_list(0) mismatch")
  }
  guard (try! zero_zz.sqf_part()).is_zero() else { fail("sqf_part(0) should be 0") }

  let zz_content = PolyBuilder::new(["x"], Domain::ZZ).from_expr(@symcore.int(2) * x + @symcore.int(2))
  let zz_fac = try! zz_content.factor(gens=["x"])
  guard zz_fac.length() >= 1 else { fail("factor with matching gens should succeed") }

  let gf_same_mod = PolyBuilder::new(["x"], Domain::GF(5)).from_expr((x ^ @symcore.int(2)) + @symcore.int(4))
  let gf_same_parts = try! gf_same_mod.factor(modulus=5, seed=23, gens=["x"])
  guard gf_same_parts.length() >= 1 else { fail("factor GF with same modulus should succeed") }

  let cc_poly = PolyBuilder::new(["x"], Domain::CC).from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let cc_parts = try! cc_poly.factor()
  guard cc_parts.length() >= 1 else { fail("factor over CC should use linear-rational fallback path") }

  let norm_zero = try! normalize_factor_for_list(Poly::zero(["x"], Domain::QQ))
  guard norm_zero.1.is_one() else { fail("normalize_factor_for_list(0) lc should be 1") }

  let rel = (a ^ @symcore.int(2)) + @symcore.int(1)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let alg_poly = PolyBuilder::new(["x"], alg_domain).from_expr((x ^ @symcore.int(2)) + x + @symcore.int(1))
  let norm_alg = try! normalize_factor_for_list(alg_poly)
  guard norm_alg.0.domain == alg_domain else {
    fail("normalize_factor_for_list should keep AlgExt domain")
  }
  let norm_zz = try! normalize_factor_for_list(
    PolyBuilder::new(["x"], Domain::ZZ).from_expr(@symcore.int(2) * x + @symcore.int(1)),
  )
  guard norm_zz.1.to_string() == "2" else {
    fail("normalize_factor_for_list ZZ lc extraction mismatch")
  }

  let lin_parts = try! factor_linear_rationals(PolyBuilder::new(["x"], Domain::QQ).from_expr(x))
  guard lin_parts.length() == 1 else {
    fail("factor_linear_rationals(x) should produce one linear factor")
  }

  let gf_coeffs : Map[Monomial, FieldElem] = Map::new()
  gf_coeffs.set(Monomial::{ exps: [1] }, FieldElem::GFp(5, 0))
  gf_coeffs.set(Monomial::{ exps: [0] }, FieldElem::GFp(5, 3))
  let gf_with_zero = Poly::{
    coeffs: gf_coeffs,
    gens: ["x"],
    domain: Domain::GF(5),
    order: TermOrder::Lex,
  }
  let gf_norm = try! normalize_poly_mod(gf_with_zero)
  guard gf_norm.degree(0) == 0 else {
    fail("normalize_poly_mod should drop explicit zero GF coefficients")
  }
  let gfext_norm = try! normalize_poly_mod(
    PolyBuilder::new(["x"], gfext_domain).from_expr(x + @symcore.int(1)),
  )
  guard gfext_norm.domain == gfext_domain else {
    fail("normalize_poly_mod should pass through GFExt polynomials")
  }

  let stripped_const = try! strip_linear_roots_gf(
    PolyBuilder::new(["x"], Domain::GF(5)).from_expr(@symcore.int(3)),
    5,
  )
  guard stripped_const.1.length() == 0 else {
    fail("strip_linear_roots_gf(constant) should return no factors")
  }

  let gf_repeated = PolyBuilder::new(["x"], Domain::GF(5)).from_expr((x + @symcore.int(1)) ^ @symcore.int(2))
  let gf_repeated_parts = try! factor_gf_seeded(gf_repeated, 7)
  guard gf_repeated_parts.length() >= 1 else {
    fail("factor_gf_seeded repeated-factor branch should return factors")
  }

  let gfext_for_seed = PolyBuilder::new(["x"], gfext_domain).from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let gfext_seeded = try! factor_gf_seeded(gfext_for_seed, 31)
  guard gfext_seeded.length() >= 1 else {
    fail("factor_gf_seeded GFExt domain branch should return factors")
  }

  let seeded_some = try! field_elem_from_seed(
    11,
    3,
    2,
    Some([1, 0, 1]),
    Domain::GFExt(3, 2, [1, 0, 1]),
  )
  guard seeded_some is FieldElem::GFExt(_, _, m) && m.length() == 3 else {
    fail("field_elem_from_seed(Some(mod_poly)) mismatch")
  }
  let seeded_other = try! field_elem_from_seed(5, 7, 1, None, Domain::QQ)
  guard seeded_other.to_string() == "5" else {
    fail("field_elem_from_seed fallback domain conversion mismatch")
  }

  let c1 = try! poly_const_from_fe(FieldElem::QQ(@symnum.BigRational::one()), ["x"], Domain::QQ)
  guard !c1.is_zero() else { fail("poly_const_from_fe(nonzero) should be nonzero") }

  let alg_one = Poly::one(["x"], alg_domain)
  guard (try! factor_algext(alg_one)).length() == 0 else {
    fail("factor_algext(one) should return []")
  }
  let alg_linear = PolyBuilder::new(["x"], alg_domain).from_expr(x + @symcore.int(1))
  let alg_factored = try! factor_algext(alg_linear)
  guard alg_factored.length() == 1 else {
    fail("factor_algext(linear) should return one factor")
  }

  let rf = [try! fw_const(1, Domain::QQ), try! fw_const(2, Domain::QQ)]
  let rg = [try! fw_const(3, Domain::QQ), try! fw_const(4, Domain::QQ)]
  let rfull = try! resultant_poly_coeffs(rf, rg, Domain::QQ, "x")
  guard !rfull.is_zero() else {
    fail("resultant_poly_coeffs nontrivial Sylvester matrix branch mismatch")
  }
}

///|
test "factor wb: residual reachable branch sweep" {
  let x = @symcore.symbol("x")
  let a = @symcore.symbol("a")

  let gf5_poly = PolyBuilder::new(["x"], Domain::GF(5)).from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let remapped = try! gf5_poly.factor(modulus=7)
  guard remapped.length() >= 1 else {
    fail("factor(modulus!=domain GF prime) should remap and factor")
  }

  let qq_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let qq_norm = try! normalize_poly_mod(qq_poly)
  guard qq_norm.domain == Domain::QQ else {
    fail("normalize_poly_mod should pass through non-GF domains")
  }
  let qq_mod_parts = try! (PolyBuilder::new(["x"], Domain::QQ).from_expr((x ^ @symcore.int(2)) + @symcore.int(1))).factor(modulus=5)
  guard qq_mod_parts.length() >= 1 else {
    fail("factor(modulus=...) on non-GF domain should map into GF path")
  }
  let bad_seeded : Result[Array[Poly], PolyError] = try? factor_gf_seeded(qq_poly, 13)
  guard bad_seeded is Err(PolyError::NotUnivariate) else {
    fail("factor_gf_seeded should reject non-GF domains")
  }

  let rel = (a ^ @symcore.int(2)) + @symcore.int(1)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let alg_linear = PolyBuilder::new(["x"], alg_domain).from_expr(x + @symcore.int(1))
  let alg_via_poly_factor = try! alg_linear.factor()
  guard alg_via_poly_factor.length() == 1 else {
    fail("Poly.factor should dispatch through AlgExt branch")
  }

  let gfext_domain = Domain::GFExt(5, 2, [1, 0, 1])
  let sqf_tail = try! square_free_decompose(
    PolyBuilder::new(["x"], gfext_domain).from_expr((x ^ @symcore.int(5)) * (x + @symcore.int(1))),
  )
  guard sqf_tail.length() >= 2 else {
    fail("square_free_decompose should keep residual inseparable tail in non-GF domain")
  }

  let gf3_repeat_expr = ((((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(2)) * ((x ^ @symcore.int(2)) + x + @symcore.int(2)))
  let gf3_repeat = PolyBuilder::new(["x"], Domain::GF(3)).from_expr(gf3_repeat_expr)
  let gf3_parts = try! factor_gf_seeded(gf3_repeat, 41)
  guard gf3_parts.length() >= 1 else {
    fail("factor_gf_seeded should split repeated non-linear factors")
  }

  let gfext_mix = PolyBuilder::new(["x"], gfext_domain).from_expr((x ^ @symcore.int(2)) + x)
  let gfext_mix_parts = try! factor_gf_seeded(gfext_mix, 9)
  guard gfext_mix_parts.length() >= 1 else {
    fail("factor_gf_seeded on GFExt should return at least one factor")
  }
  let gfext_linear_parts = try! factor_gf_seeded(
    PolyBuilder::new(["x"], gfext_domain).from_expr(x + @symcore.int(1)),
    15,
  )
  guard gfext_linear_parts.length() == 1 else {
    fail("factor_gf_seeded should keep linear GFExt factors directly")
  }

  let edf_poly = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(
    ((x ^ @symcore.int(2)) + @symcore.int(2)) * ((x ^ @symcore.int(2)) + @symcore.int(3)),
  )
  let edf_parts = try! equal_degree_factor(edf_poly, 2, 5, 5, 1, 17, None)
  guard !edf_parts.is_empty() else {
    fail("equal_degree_factor should return at least one factor")
  }
}
