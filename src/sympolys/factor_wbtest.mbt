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
  let one = fw_const(1, Domain::QQ)
  let two = fw_const(2, Domain::QQ)
  assert_true(is_one(one))
  assert_true(!is_one(two))

  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let non_uni = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y)

  let deriv_bad : Result[Poly, PolyError] = try? deriv_univar(non_uni)
  assert_true(deriv_bad is Err(PolyError::NotUnivariate))

  let gf_poly = fw_univar(
    (x ^ @symcore.int(3)) + @symcore.int(1),
    Domain::GF(5),
  )
  let root_bad : Result[Poly, PolyError] = try? pth_root_univar_gf(gf_poly, 2)
  assert_true(root_bad is Err(PolyError::BadExponent))

  let ext_none = apply_extension_request(gf_poly, [])
  assert_true(ext_none.domain == gf_poly.domain)

  let ext_bad : Result[Poly, PolyError] = try? apply_extension_request(two, [
    "a", "b",
  ])
  assert_true(ext_bad is Err(PolyError::BadGenerator("extension")))

  let zz_poly = fw_univar((x ^ @symcore.int(2)) + @symcore.int(1), Domain::ZZ)
  let lifted = apply_extension_request(zz_poly, ["a"])
  assert_true(lifted.domain == Domain::QQ)

  let factor_bad_gens : Result[Array[(Poly, Int)], PolyError] = try? zz_poly.factor(gens=[
      "y",
    ],
  )
  assert_true(factor_bad_gens is Err(PolyError::DomainMismatch))

  let factor_bad_mod : Result[Array[(Poly, Int)], PolyError] = try? zz_poly.factor(
    modulus=1,
  )
  assert_true(factor_bad_mod is Err(PolyError::BadModulus))
}

///|
test "factor wb: determinant/resultant helper branches" {
  let d0 = poly_det([], Domain::QQ, "x")
  inspect(d0, content="1")

  let d1 = poly_det([[fw_const(2, Domain::QQ)]], Domain::QQ, "x")
  inspect(d1, content="2")

  let singular = poly_det(
    [
      [fw_const(0, Domain::QQ), fw_const(1, Domain::QQ)],
      [fw_const(0, Domain::QQ), fw_const(2, Domain::QQ)],
    ],
    Domain::QQ,
    "x",
  )
  inspect(singular, content="0")

  let swapped = poly_det(
    [
      [fw_const(0, Domain::QQ), fw_const(1, Domain::QQ)],
      [fw_const(1, Domain::QQ), fw_const(0, Domain::QQ)],
    ],
    Domain::QQ,
    "x",
  )
  inspect(swapped, content="-1")

  let d3 = poly_det(
    [
      [
        fw_const(1, Domain::QQ),
        fw_const(2, Domain::QQ),
        fw_const(3, Domain::QQ),
      ],
      [
        fw_const(4, Domain::QQ),
        fw_const(5, Domain::QQ),
        fw_const(6, Domain::QQ),
      ],
      [
        fw_const(7, Domain::QQ),
        fw_const(8, Domain::QQ),
        fw_const(10, Domain::QQ),
      ],
    ],
    Domain::QQ,
    "x",
  )
  assert_true(!d3.is_zero())

  let rz = resultant_poly_coeffs(
    [fw_const(1, Domain::QQ)],
    [fw_const(2, Domain::QQ)],
    Domain::QQ,
    "x",
  )
  inspect(rz, content="0")
}

///|
test "factor wb: GF splitting and seed helpers" {
  let x = @symcore.Expr::Symbol("x")
  let gf_poly = fw_univar(
    (x ^ @symcore.int(2)) + @symcore.int(1),
    Domain::GF(5),
  )
  let edf_same = equal_degree_factor(gf_poly, 2, 5, 5, 1, 17, None)
  assert_eq(edf_same.length(), 1)

  let edf_try = equal_degree_factor(gf_poly, 1, 5, 5, 1, 19, None)
  assert_true(!edf_try.is_empty())

  let seeded = field_elem_from_seed(
    7,
    3,
    3,
    None,
    Domain::GFExt(3, 3, [1, 0, 0, 1]),
  )
  match seeded {
    FieldElem::GFExt(_, coeffs, mod_poly) =>
      assert_true(
        coeffs.length() == 3 &&
        coeffs[0] == 1 &&
        coeffs[1] == 2 &&
        mod_poly.length() == 0,
      )
    _ => fail("field_elem_from_seed should build GFExt coefficient")
  }

  let c0 = poly_const_from_fe(
    FieldElem::QQ(@symnum.BigRational::zero()),
    ["x"],
    Domain::QQ,
  )
  assert_true(c0.is_zero())

  let y = @symcore.Expr::Symbol("y")
  let non_uni = PolyBuilder::new(["x", "y"], Domain::GF(5)).from_expr(x + y)
  let bad_gf_seeded : Result[Array[Poly], PolyError] = try? factor_gf_seeded(
    non_uni, 11,
  )
  assert_true(bad_gf_seeded is Err(PolyError::NotUnivariate))

  let bad_eval_mod : Result[Int, PolyError] = try? eval_univar_mod(
    gf_poly, 1, 1,
  )
  assert_true(bad_eval_mod is Err(PolyError::BadModulus))

  let lin_bad : Result[Array[Poly], PolyError] = try? factor_linear_rationals(
    PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y),
  )
  assert_true(lin_bad is Err(PolyError::NotUnivariate))
}

///|
test "factor wb: algext conversion and factoring helper branches" {
  let a = @symcore.Expr::Symbol("a")
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let rel = (a ^ @symcore.int(2)) + @symcore.int(1)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let (minpoly, _) = load_algext_minpoly(Domain::QQ, ["a"], [rel])

  let zero_alg = Poly::zero(["x"], alg_domain)
  let sf_zero = factor_algext_squarefree(zero_alg, Domain::QQ, minpoly)
  assert_eq(sf_zero.length(), 0)

  let lin_alg = fw_univar(x + @symcore.int(1), alg_domain)
  let sf_lin = factor_algext_squarefree(lin_alg, Domain::QQ, minpoly)
  assert_eq(sf_lin.length(), 1)

  let bad_factor_domain : Result[Array[Poly], PolyError] = try? factor_algext(
    fw_univar(x + @symcore.int(1), Domain::QQ),
  )
  assert_true(bad_factor_domain is Err(PolyError::DomainMismatch))

  let bad_factor_nonuni : Result[Array[Poly], PolyError] = try? factor_algext(
    PolyBuilder::new(["x", "y"], alg_domain).from_expr(x + y),
  )
  assert_true(bad_factor_nonuni is Err(PolyError::NotUnivariate))

  let coeffs : Map[Monomial, FieldElem] = Map::new()
  coeffs.set(Monomial::{ exps: [1] }, FieldElem::QQ(@symnum.BigRational::one()))
  coeffs.set(
    Monomial::{ exps: [0] },
    FieldElem::AlgExt(
      Domain::QQ,
      [
        FieldElem::QQ(@symnum.BigRational::one()),
        FieldElem::QQ(@symnum.BigRational::one()),
      ],
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
  let t_coeffs = algext_poly_to_t_coeffs(mixed_alg_poly, Domain::QQ, "x")
  assert_true(t_coeffs.length() >= 2)

  let m_coeffs = minpoly_to_t_coeffs(minpoly, Domain::QQ, "x")
  assert_eq(m_coeffs.length(), minpoly.degree(0) + 1)

  let base_poly = fw_univar((x ^ @symcore.int(2)) + @symcore.int(1), Domain::QQ)
  let lifted = lift_base_poly_to_algext(base_poly, alg_domain)
  assert_true(lifted.domain == alg_domain)

  let _ = int_pow(3, 4)
}

///|
test "factor wb: high-gap branch sweep" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let a = @symcore.Expr::Symbol("a")

  let pth_nonuni : Result[Poly, PolyError] = try? pth_root_univar_gf(
    PolyBuilder::new(["x", "y"], Domain::GF(3)).from_expr(x + y),
    3,
  )
  assert_true(pth_nonuni is Err(PolyError::NotUnivariate))
  let pth_zero = pth_root_univar_gf(Poly::zero(["x"], Domain::GF(3)), 3)
  assert_true(pth_zero.is_zero())

  let sqf_nonuni : Result[Array[(Poly, Int)], PolyError] = try? square_free_decompose(
    PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y),
  )
  assert_true(sqf_nonuni is Err(PolyError::NotUnivariate))
  assert_eq(square_free_decompose(Poly::zero(["x"], Domain::QQ)).length(), 0)
  let gfext_domain = Domain::GFExt(5, 2, [1, 0, 1])
  let sqf_gfext = square_free_decompose(
    PolyBuilder::new(["x"], gfext_domain).from_expr(
      (x ^ @symcore.int(5)) + @symcore.int(1),
    ),
  )
  assert_true(sqf_gfext.length() == 1 && sqf_gfext[0].1 == 1)

  let qq_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let ext_passthrough = apply_extension_request(qq_poly, ["a"])
  assert_true(ext_passthrough.domain == Domain::QQ)

  let zero_zz = Poly::zero(["x"], Domain::ZZ)
  assert_eq(zero_zz.factor().length(), 0)
  let fl_zero = zero_zz.factor_list()
  assert_true(fl_zero.0.is_zero() && fl_zero.1.length() == 0)
  assert_true(zero_zz.sqf_part().is_zero())

  let zz_content = PolyBuilder::new(["x"], Domain::ZZ).from_expr(
    @symcore.int(2) * x + @symcore.int(2),
  )
  let zz_fac = zz_content.factor(gens=["x"])
  assert_true(zz_fac.length() >= 1)

  let gf_same_mod = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(4),
  )
  let gf_same_parts = gf_same_mod.factor(modulus=5, seed=23, gens=["x"])
  assert_true(gf_same_parts.length() >= 1)

  let cc_poly = PolyBuilder::new(["x"], Domain::CC).from_expr(
    (x ^ @symcore.int(2)) - @symcore.int(1),
  )
  let cc_parts = cc_poly.factor()
  assert_true(cc_parts.length() >= 1)

  let norm_zero = normalize_factor_for_list(Poly::zero(["x"], Domain::QQ))
  assert_true(norm_zero.1.is_one())

  let rel = (a ^ @symcore.int(2)) + @symcore.int(1)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let alg_poly = PolyBuilder::new(["x"], alg_domain).from_expr(
    (x ^ @symcore.int(2)) + x + @symcore.int(1),
  )
  let norm_alg = normalize_factor_for_list(alg_poly)
  assert_true(norm_alg.0.domain == alg_domain)
  let norm_zz = normalize_factor_for_list(
    PolyBuilder::new(["x"], Domain::ZZ).from_expr(
      @symcore.int(2) * x + @symcore.int(1),
    ),
  )
  assert_eq(norm_zz.1.to_string(), "2")

  let lin_parts = factor_linear_rationals(
    PolyBuilder::new(["x"], Domain::QQ).from_expr(x),
  )
  assert_eq(lin_parts.length(), 1)

  let gf_coeffs : Map[Monomial, FieldElem] = Map::new()
  gf_coeffs.set(Monomial::{ exps: [1] }, FieldElem::GFp(5, 0))
  gf_coeffs.set(Monomial::{ exps: [0] }, FieldElem::GFp(5, 3))
  let gf_with_zero = Poly::{
    coeffs: gf_coeffs,
    gens: ["x"],
    domain: Domain::GF(5),
    order: TermOrder::Lex,
  }
  let gf_norm = normalize_poly_mod(gf_with_zero)
  assert_eq(gf_norm.degree(0), 0)
  let gfext_norm = normalize_poly_mod(
    PolyBuilder::new(["x"], gfext_domain).from_expr(x + @symcore.int(1)),
  )
  assert_true(gfext_norm.domain == gfext_domain)

  let stripped_const = strip_linear_roots_gf(
    PolyBuilder::new(["x"], Domain::GF(5)).from_expr(@symcore.int(3)),
    5,
  )
  assert_eq(stripped_const.1.length(), 0)

  let gf_repeated = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(
    (x + @symcore.int(1)) ^ @symcore.int(2),
  )
  let gf_repeated_parts = factor_gf_seeded(gf_repeated, 7)
  assert_true(gf_repeated_parts.length() >= 1)

  let gfext_for_seed = PolyBuilder::new(["x"], gfext_domain).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let gfext_seeded = factor_gf_seeded(gfext_for_seed, 31)
  assert_true(gfext_seeded.length() >= 1)

  let seeded_some = field_elem_from_seed(
    11,
    3,
    2,
    Some([1, 0, 1]),
    Domain::GFExt(3, 2, [1, 0, 1]),
  )
  guard seeded_some is FieldElem::GFExt(_, _, m) && m.length() == 3 else {
    fail("field_elem_from_seed(Some(mod_poly)) mismatch")
  }
  let seeded_other = field_elem_from_seed(5, 7, 1, None, Domain::QQ)
  assert_eq(seeded_other.to_string(), "5")

  let c1 = poly_const_from_fe(
    FieldElem::QQ(@symnum.BigRational::one()),
    ["x"],
    Domain::QQ,
  )
  assert_true(!c1.is_zero())

  let alg_one = Poly::one(["x"], alg_domain)
  assert_eq(factor_algext(alg_one).length(), 0)
  let alg_linear = PolyBuilder::new(["x"], alg_domain).from_expr(
    x + @symcore.int(1),
  )
  let alg_factored = factor_algext(alg_linear)
  assert_eq(alg_factored.length(), 1)

  let rf = [fw_const(1, Domain::QQ), fw_const(2, Domain::QQ)]
  let rg = [fw_const(3, Domain::QQ), fw_const(4, Domain::QQ)]
  let rfull = resultant_poly_coeffs(rf, rg, Domain::QQ, "x")
  assert_true(!rfull.is_zero())
}

///|
test "factor wb: residual reachable branch sweep" {
  let x = @symcore.Expr::Symbol("x")
  let a = @symcore.Expr::Symbol("a")

  let gf5_poly = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(1),
  )
  let remapped = gf5_poly.factor(modulus=7)
  assert_true(remapped.length() >= 1)

  let qq_poly = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    x + @symcore.int(1),
  )
  let qq_norm = normalize_poly_mod(qq_poly)
  assert_true(qq_norm.domain == Domain::QQ)
  let qq_mod_parts = PolyBuilder::new(["x"], Domain::QQ)
    .from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
    .factor(modulus=5)
  assert_true(qq_mod_parts.length() >= 1)
  let bad_seeded : Result[Array[Poly], PolyError] = try? factor_gf_seeded(
    qq_poly, 13,
  )
  assert_true(bad_seeded is Err(PolyError::NotUnivariate))

  let rel = (a ^ @symcore.int(2)) + @symcore.int(1)
  let alg_domain = Domain::AlgExt(Domain::QQ, ["a"], [rel])
  let alg_linear = PolyBuilder::new(["x"], alg_domain).from_expr(
    x + @symcore.int(1),
  )
  let alg_via_poly_factor = alg_linear.factor()
  assert_eq(alg_via_poly_factor.length(), 1)

  let gfext_domain = Domain::GFExt(5, 2, [1, 0, 1])
  let sqf_tail = square_free_decompose(
    PolyBuilder::new(["x"], gfext_domain).from_expr(
      (x ^ @symcore.int(5)) * (x + @symcore.int(1)),
    ),
  )
  assert_true(sqf_tail.length() >= 2)

  let gf3_repeat_expr = (
      ((x ^ @symcore.int(2)) + @symcore.int(1)) ^ @symcore.int(2)
    ) *
    ((x ^ @symcore.int(2)) + x + @symcore.int(2))
  let gf3_repeat = PolyBuilder::new(["x"], Domain::GF(3)).from_expr(
    gf3_repeat_expr,
  )
  let gf3_parts = factor_gf_seeded(gf3_repeat, 41)
  assert_true(gf3_parts.length() >= 1)

  let gfext_mix = PolyBuilder::new(["x"], gfext_domain).from_expr(
    (x ^ @symcore.int(2)) + x,
  )
  let gfext_mix_parts = factor_gf_seeded(gfext_mix, 9)
  assert_true(gfext_mix_parts.length() >= 1)
  let gfext_linear_parts = factor_gf_seeded(
    PolyBuilder::new(["x"], gfext_domain).from_expr(x + @symcore.int(1)),
    15,
  )
  assert_eq(gfext_linear_parts.length(), 1)

  let edf_poly = PolyBuilder::new(["x"], Domain::GF(5)).from_expr(
    ((x ^ @symcore.int(2)) + @symcore.int(2)) *
    ((x ^ @symcore.int(2)) + @symcore.int(3)),
  )
  let edf_parts = equal_degree_factor(edf_poly, 2, 5, 5, 1, 17, None)
  assert_true(!edf_parts.is_empty())
}

///|
test "factor wb: rational linear roots use divisor candidates" {
  let x = @symcore.Expr::Symbol("x")
  let parts = factor_linear_rationals(
    PolyBuilder::new(["x"], Domain::QQ).from_expr(
      (@symcore.int(2) * x + @symcore.int(-1)) *
      (@symcore.int(3) * x + @symcore.int(1)),
    ),
  )
  let texts = parts
    .filter(p => p.degree(0) == 1)
    .map(p => @symprint.pretty_string(p.to_expr()))
  assert_eq(texts.length(), 2)
  assert_true(texts.contains("x - 1/2"))
  assert_true(texts.contains("x + 1/3"))
}

///|
test "factor wb: monic integer linear roots split repeated divisor family" {
  let x = @symcore.Expr::Symbol("x")
  let expr = @symcore.add([
    @symcore.pow(x, @symcore.int(6)),
    @symcore.mul([@symcore.int(-21), @symcore.pow(x, @symcore.int(5))]),
    @symcore.mul([@symcore.int(175), @symcore.pow(x, @symcore.int(4))]),
    @symcore.mul([@symcore.int(-735), @symcore.pow(x, @symcore.int(3))]),
    @symcore.mul([@symcore.int(1624), @symcore.pow(x, @symcore.int(2))]),
    @symcore.mul([@symcore.int(-1764), x]),
    @symcore.int(720),
  ])
  let parts = factor_linear_rationals(
    PolyBuilder::new(["x"], Domain::QQ).from_expr(expr),
  )
  let texts = parts
    .filter(p => p.degree(0) == 1)
    .map(p => @symprint.pretty_string(p.to_expr()))
  assert_eq(texts.length(), 6)
  for i in 1..<=6 {
    assert_true(texts.contains("x - \{i}"))
  }
}
