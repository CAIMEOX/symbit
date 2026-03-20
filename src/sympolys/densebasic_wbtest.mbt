///|
fn db_wb_fe(n : Int) -> FieldElem {
  FieldElem::QQ(@symnum.BigRational::from_int(n))
}

///|
fn db_wb_coef(n : Int) -> DensePoly {
  DensePoly::Coef(db_wb_fe(n))
}

///|
fn db_wb_poly(xs : Array[DensePoly]) -> DensePoly {
  DensePoly::Poly(xs)
}

///|
fn db_wb_const_poly(
  n : Int,
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  Poly::from_expr(@symcore.int(n), gens, domain)
}

///|
fn db_wb_add_pair(
  a : FieldElem,
  b : FieldElem,
  _args : Array[FieldElem],
) -> FieldElem {
  match (a, b) {
    (FieldElem::QQ(lhs), FieldElem::QQ(rhs)) => FieldElem::QQ(lhs.add_r(rhs))
    _ => a
  }
}

///|
test "densebasic wb: dense extraction and coefficient edge branches" {
  let c0 = dense_to_coeffs(DensePoly::Coef(db_wb_fe(0)))
  assert_eq(c0.length(), 0)

  let c1 = dense_to_coeffs(DensePoly::Coef(db_wb_fe(3)))
  assert_true(c1.length() == 1 && c1[0].to_string() == "3")

  let non_uni : Result[Array[FieldElem], PolyError] = try? dense_to_coeffs(
    DensePoly::Poly([DensePoly::Poly([])]),
  )
  assert_true(non_uni is Err(PolyError::NotUnivariate))

  let lc = dmp_LC(DensePoly::Coef(db_wb_fe(9)))
  let tc = dmp_TC(DensePoly::Coef(db_wb_fe(8)))
  assert_true(lc is DensePoly::Coef(_) && tc is DensePoly::Coef(_))

  let glc_nested = dmp_ground_LC(db_wb_poly([db_wb_poly([])]), 0)
  let gtc_nested = dmp_ground_TC(db_wb_poly([db_wb_poly([])]), 0)
  assert_true(glc_nested.to_string() == "0" && gtc_nested.to_string() == "0")
}

///|
test "densebasic wb: dpp conversion helper branches" {
  let gens = ["x"]
  let nonzero = db_wb_const_poly(2, gens, Domain::QQ)
  let zero = Poly::zero(gens, Domain::QQ)

  let empty : Map[Monomial, Poly] = Map::new()
  let u0_empty = dpp_from_dict(empty, 0, gens, Domain::QQ)
  assert_true(dpp_zero_p(u0_empty))

  let bad_u0 : Map[Monomial, Poly] = Map::new()
  bad_u0.set(Monomial::{ exps: [1, 0] }, nonzero)
  let bad_u0_res : Result[DensePolyPoly, PolyError] = try? dpp_from_dict(
    bad_u0,
    0,
    gens,
    Domain::QQ,
  )
  assert_true(bad_u0_res is Err(PolyError::DomainMismatch))

  let u1_empty = dpp_from_dict(empty, 1, gens, Domain::QQ)
  assert_true(dpp_zero_p(u1_empty))

  let bad_u1 : Map[Monomial, Poly] = Map::new()
  bad_u1.set(Monomial::{ exps: [2] }, nonzero)
  let bad_u1_res : Result[DensePolyPoly, PolyError] = try? dpp_from_dict(
    bad_u1,
    1,
    gens,
    Domain::QQ,
  )
  assert_true(bad_u1_res is Err(PolyError::DomainMismatch))

  let only_zero : Map[Monomial, Poly] = Map::new()
  only_zero.set(Monomial::{ exps: [2, 1] }, zero)
  let only_zero_dpp = dpp_from_dict(only_zero, 1, gens, Domain::QQ)
  assert_true(dpp_zero_p(only_zero_dpp))

  let td0 = dpp_to_dict(DensePolyPoly::Coef(nonzero), 0)
  assert_eq(td0.length(), 1)

  let bad_nested : DensePolyPoly = DensePolyPoly::Poly([DensePolyPoly::Poly([])])
  let bad_nested_res : Result[Map[Monomial, Poly], PolyError] = try? dpp_to_dict(
    bad_nested, 0,
  )
  assert_true(bad_nested_res is Err(PolyError::NonPolynomial))

  let td1 = dpp_to_dict(DensePolyPoly::Coef(nonzero), 1)
  assert_eq(td1.length(), 1)
}

///|
test "densebasic wb: inject/eject, terms, pairwise apply, slice/random edges" {
  let wrong_poly = Poly::from_expr(
    @symcore.symbol("z") + @symcore.int(1),
    ["z"],
    Domain::QQ,
  )
  let bad_inject : Result[(DensePoly, Int), PolyError] = try? dmp_inject(
    DensePolyPoly::Coef(wrong_poly),
    0,
    ["x"],
    Domain::QQ,
  )
  assert_true(bad_inject is Err(PolyError::DomainMismatch))

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let xy_poly = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(
    x + y + @symcore.int(1),
  )
  let dpp = DensePolyPoly::Poly([DensePolyPoly::Coef(xy_poly)])
  let (inj_front, w_front) = dmp_inject(
    dpp,
    0,
    ["x", "y"],
    Domain::QQ,
    front=true,
  )
  assert_eq(w_front, 2)
  let ejected = dmp_eject(
    inj_front,
    w_front,
    ["x", "y"],
    Domain::QQ,
    front=true,
  )
  let ejected_dict = dpp_to_dict(ejected, 0)
  assert_eq(ejected_dict.length(), 1)

  let bad_eject : Result[DensePolyPoly, PolyError] = try? dmp_eject(
    db_wb_poly([]),
    0,
    ["x", "y"],
    Domain::QQ,
  )
  assert_true(bad_eject is Err(PolyError::BadExponent))

  let (k, trimmed) = dup_terms_gcd(
    [db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)],
    Domain::ZZ,
  )
  assert_true(k == 2 && trimmed.length() == 1 && trimmed[0].to_string() == "1")

  let (exps, reduced) = dmp_terms_gcd(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)]),
    0,
    Domain::ZZ,
  )
  assert_true(exps.length() == 1 && exps[0] == 2)
  let reduced_coeffs = dense_to_coeffs(reduced)
  assert_true(reduced_coeffs.length() == 1 && reduced_coeffs[0].to_string() == "1")

  let ap1 = dup_apply_pairs(
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)],
    [db_wb_fe(4)],
    db_wb_add_pair,
    [],
    Domain::ZZ,
  )
  assert_eq(ap1.length(), 3)
  let ap2 = dup_apply_pairs(
    [db_wb_fe(4)],
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)],
    db_wb_add_pair,
    [],
    Domain::ZZ,
  )
  assert_eq(ap2.length(), 3)

  let da = dmp_apply_pairs(
    db_wb_poly([db_wb_coef(1), db_wb_coef(2)]),
    db_wb_coef(3),
    db_wb_add_pair,
    [],
    1,
    Domain::ZZ,
  )
  let da_dict = dmp_to_dict(da, 1, Domain::ZZ)
  assert_true(da_dict.length() > 0)

  let s0 = dup_slice([db_wb_fe(0), db_wb_fe(0)], 2, 0, Domain::ZZ)
  assert_eq(s0.length(), 0)
  let s1 = dup_slice([db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)], 1, 2, Domain::ZZ)
  assert_true(s1.length() > 0 && fe_is_zero(s1[s1.length() - 1]))

  let bad_slice : Result[DensePoly, PolyError] = try? dmp_slice_in(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(2)]),
    1,
    2,
    2,
    1,
    Domain::ZZ,
  )
  assert_true(bad_slice is Err(PolyError::BadExponent))
  let sliced_u0 = dmp_slice_in(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)]),
    1,
    3,
    0,
    0,
    Domain::ZZ,
  )
  let sliced_u0_coeffs = dense_to_coeffs(sliced_u0)
  assert_true(sliced_u0_coeffs.length() > 0)

  let rand_fixed = dup_random(3, 0, 0, Domain::ZZ)
  assert_true(!fe_is_zero(rand_fixed[0]))
}

///|
test "densebasic wb: remaining branch sweep for deflate/inflate/dict/pairs helpers" {
  inspect(dup_LC([]), content="0")
  inspect(dup_TC([]), content="0")
  assert_eq(dup_copy([]).length(), 0)
  inspect(dup_nth([], 0), content="0")

  let z_lc = dmp_LC(DensePoly::Poly([]))
  let z_tc = dmp_TC(DensePoly::Poly([]))
  guard z_lc is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_LC([]) should return []")
  }
  guard z_tc is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_TC([]) should return []")
  }
  assert_true(dmp_strip(DensePoly::Coef(db_wb_fe(7))) is DensePoly::Coef(_))
  let rev_empty = dmp_reverse(DensePoly::Poly([]))
  guard rev_empty is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_reverse([]) should stay []")
  }

  let empty_dict : Map[Monomial, FieldElem] = Map::new()
  assert_eq(dup_from_dict(empty_dict, Domain::ZZ).length(), 0)
  let bad_uni_dict : Map[Monomial, FieldElem] = Map::new()
  bad_uni_dict.set(Monomial::{ exps: [1, 0] }, db_wb_fe(1))
  let bad_uni_res : Result[Array[FieldElem], PolyError] = try? dup_from_dict(
    bad_uni_dict,
    Domain::ZZ,
  )
  assert_true(bad_uni_res is Err(PolyError::DomainMismatch))

  let empty_raw : Map[Int, FieldElem] = Map::new()
  assert_eq(dup_from_raw_dict(empty_raw, Domain::ZZ).length(), 0)

  let bad_mv_dict : Map[Monomial, FieldElem] = Map::new()
  bad_mv_dict.set(Monomial::{ exps: [2] }, db_wb_fe(1))
  let bad_mv_res : Result[DensePoly, PolyError] = try? dmp_from_dict(
    bad_mv_dict,
    1,
    Domain::ZZ,
  )
  assert_true(bad_mv_res is Err(PolyError::DomainMismatch))

  let td_coef = dmp_to_dict(DensePoly::Coef(db_wb_fe(4)), 1, Domain::ZZ)
  assert_eq(td_coef.length(), 1)
  assert_eq(dmp_to_raw_dict(DensePoly::Coef(db_wb_fe(3)), 1, Domain::ZZ).length(), 0)

  let sw_bad : Result[DensePoly, PolyError] = try? dmp_swap(
    db_wb_poly([db_wb_coef(1)]),
    -1,
    0,
    0,
    Domain::ZZ,
  )
  assert_true(sw_bad is Err(PolyError::BadExponent))
  let sw_same = dmp_swap(db_wb_poly([db_wb_coef(1)]), 0, 0, 0, Domain::ZZ)
  let sw_same_coeffs = dense_to_coeffs(sw_same)
  assert_eq(sw_same_coeffs.length(), 1)

  let perm_bad : Result[DensePoly, PolyError] = try? dmp_permute(
    db_wb_poly([db_wb_coef(1)]),
    [2],
    0,
    Domain::ZZ,
  )
  assert_true(perm_bad is Err(PolyError::BadExponent))

  assert_true(dmp_nest(db_wb_coef(3), 0, Domain::ZZ) is DensePoly::Coef(_))
  let raised_bad : Result[DensePoly, PolyError] = try? dmp_raise(
    db_wb_poly([db_wb_poly([])]),
    1,
    0,
    Domain::ZZ,
  )
  assert_true(raised_bad is Err(PolyError::NotUnivariate))

  let (g0, _) = dup_deflate([db_wb_fe(2)], Domain::ZZ)
  assert_eq(g0, 1)
  let (dz_b, dz_poly) = dmp_deflate(dmp_zero(1), 1, Domain::ZZ)
  assert_true(dz_b.length() == 2 && dmp_zero_p(dz_poly, 1))

  let (md_empty_m, md_empty_out) = dup_multi_deflate([], Domain::ZZ)
  assert_true(md_empty_m == 1 && md_empty_out.length() == 0)
  let (md_const_m, _) = dup_multi_deflate([[db_wb_fe(5)]], Domain::ZZ)
  assert_eq(md_const_m, 1)

  let dmd_empty = dmp_multi_deflate([], 1, Domain::ZZ)
  assert_true(dmd_empty.0.length() == 2 && dmd_empty.1.length() == 0)
  let dmd_u0 = dmp_multi_deflate(
    [dense_from_coeffs([db_wb_fe(1), db_wb_fe(0), db_wb_fe(1)])],
    0,
    Domain::ZZ,
  )
  assert_true(dmd_u0.0.length() == 1 && dmd_u0.1.length() == 1)

  let bad_inflate : Result[Array[FieldElem], PolyError] = try? dup_inflate(
    [db_wb_fe(1)],
    0,
    Domain::ZZ,
  )
  assert_true(bad_inflate is Err(PolyError::BadExponent))
  assert_eq(dup_inflate([db_wb_fe(1)], 1, Domain::ZZ).length(), 1)

  let bad_mvec : Result[DensePoly, PolyError] = try? dmp_inflate(
    db_wb_poly([db_wb_coef(1)]),
    [0, 1],
    1,
    Domain::ZZ,
  )
  assert_true(bad_mvec is Err(PolyError::BadExponent))
  let keep_all_one = dmp_inflate(
    db_wb_poly([db_wb_coef(1)]),
    [1, 1],
    1,
    Domain::ZZ,
  )
  let keep_all_one_dict = dmp_to_dict(keep_all_one, 1, Domain::ZZ)
  assert_eq(keep_all_one_dict.length(), 1)

  guard dpp_zero(-1) is DensePolyPoly::Poly(items) && items.length() == 0 else {
    fail("dpp_zero(-1) should return []")
  }
  let dpp_nonzero_coeff = db_wb_const_poly(1, ["x"], Domain::QQ)
  assert_true(
    !dpp_zero_p(
        DensePolyPoly::Poly([DensePolyPoly::Coef(dpp_nonzero_coeff)]),
      )
  )

  let slice_trim = dup_slice(
    [db_wb_fe(0), db_wb_fe(1), db_wb_fe(2)],
    1,
    3,
    Domain::ZZ,
  )
  assert_true(
    slice_trim.length() >= 2 &&
        fe_is_zero(slice_trim[slice_trim.length() - 1])
  )

  let dmp_ap = dmp_apply_pairs(
    db_wb_coef(2),
    db_wb_poly([db_wb_coef(1), db_wb_coef(3)]),
    db_wb_add_pair,
    [],
    1,
    Domain::ZZ,
  )
  let dmp_ap_dict = dmp_to_dict(dmp_ap, 1, Domain::ZZ)
  assert_true(dmp_ap_dict.length() > 0)

  let dmp_ap2 = dmp_apply_pairs(
    db_wb_poly([db_wb_coef(1)]),
    db_wb_poly([db_wb_coef(2), db_wb_coef(3), db_wb_coef(4)]),
    db_wb_add_pair,
    [],
    1,
    Domain::ZZ,
  )
  let dmp_ap2_dict = dmp_to_dict(dmp_ap2, 1, Domain::ZZ)
  assert_true(dmp_ap2_dict.length() > 0)
}

///|
test "densebasic wb: residual branch sweep (ground/convert/rat/inflate/dpp)" {
  let gf_copy = dup_copy([FieldElem::GFp(5, 2)])
  assert_true(gf_copy.length() == 1 && gf_copy[0].to_string() == "2")

  let non_poly_level : Result[(DensePoly, Int), PolyError] = try? dmp_validate(
    DensePoly::Poly([
      DensePoly::Coef(db_wb_fe(1)),
      DensePoly::Poly([DensePoly::Coef(db_wb_fe(2))]),
    ]),
  )
  assert_true(non_poly_level is Err(PolyError::NonPolynomial))

  let strip_u0 = dense_strip_with_u(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([])]),
    0,
  )
  assert_true(strip_u0 is DensePoly::Poly(_))
  let strip_coef_u2 = dense_strip_with_u(DensePoly::Coef(db_wb_fe(3)), 2)
  assert_true(strip_coef_u2 is DensePoly::Coef(_))

  inspect(dmp_ground_LC(DensePoly::Coef(db_wb_fe(7)), 0), content="7")
  inspect(dmp_ground_LC(DensePoly::Coef(db_wb_fe(7)), 1), content="7")
  inspect(dmp_ground_LC(DensePoly::Poly([]), 1), content="0")
  inspect(dmp_ground_TC(DensePoly::Coef(db_wb_fe(8)), 0), content="8")
  inspect(dmp_ground_TC(DensePoly::Coef(db_wb_fe(8)), 1), content="8")
  inspect(dmp_ground_TC(DensePoly::Poly([]), 1), content="0")

  let lt_coef_depth = dmp_true_LT(DensePoly::Coef(db_wb_fe(2)), 1)
  assert_eq(lt_coef_depth.1.to_string(), "2")
  let lt_empty_depth = dmp_true_LT(DensePoly::Poly([]), 1)
  assert_eq(lt_empty_depth.1.to_string(), "0")
  let lt_coef_u0 = dmp_true_LT(DensePoly::Coef(db_wb_fe(3)), 0)
  assert_eq(lt_coef_u0.1.to_string(), "3")
  let lt_nested_u0 = dmp_true_LT(DensePoly::Poly([DensePoly::Poly([])]), 0)
  assert_eq(lt_nested_u0.1.to_string(), "0")

  inspect(dmp_degree(DensePoly::Coef(db_wb_fe(5)), 0), content="0")
  inspect(dmp_degree_in(DensePoly::Coef(db_wb_fe(0)), 1, 1), content="-1")
  inspect(dmp_degree_in(DensePoly::Coef(db_wb_fe(2)), 1, 1), content="0")

  let norm_u0_nonuni = dmp_normal(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([])]),
    0,
  )
  assert_true(norm_u0_nonuni is DensePoly::Poly(_))
  let norm_coef_u0 = dmp_normal(DensePoly::Coef(db_wb_fe(2)), 0)
  assert_true(norm_coef_u0 is DensePoly::Coef(_))
  let norm_coef_u1 = dmp_normal(DensePoly::Coef(db_wb_fe(2)), 1)
  assert_true(norm_coef_u1 is DensePoly::Coef(_))

  let conv_u0_nonuni = dmp_convert(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([])]),
    0,
    Domain::ZZ,
    Domain::QQ,
  )
  assert_true(conv_u0_nonuni is DensePoly::Poly(_))
  let conv_coef_u0 = dmp_convert(
    DensePoly::Coef(db_wb_fe(1)),
    0,
    Domain::ZZ,
    Domain::QQ,
  )
  assert_true(conv_coef_u0 is DensePoly::Coef(_))
  let conv_coef_u1 = dmp_convert(
    DensePoly::Coef(db_wb_fe(1)),
    1,
    Domain::ZZ,
    Domain::QQ,
  )
  assert_true(conv_coef_u1 is DensePoly::Coef(_))
  let conv_empty = dup_convert([], Domain::ZZ, Domain::QQ)
  assert_eq(conv_empty.length(), 0)
  let gfext_sample = FieldElem::GFExt(5, [1], [1, 0, 1])
  let gfext_keep = dup_convert(
    [gfext_sample],
    Domain::GFExt(5, 2, [1, 0, 1]),
    Domain::GFExt(5, 2, [1, 0, 1]),
  )
  assert_eq(gfext_keep.length(), 1)
  let a_alg = @symcore.symbol("a")
  let minpoly_alg = PolyBuilder::new(["a"], Domain::QQ).from_expr(
    (a_alg ^ @symcore.int(2)) + @symcore.int(1),
  )
  let alg_sample = FieldElem::AlgExt(
    Domain::QQ,
    [FieldElem::QQ(@symnum.BigRational::one())],
    minpoly_alg,
    "a",
  )
  let alg_keep = dup_convert([alg_sample], Domain::QQ, Domain::QQ)
  assert_eq(alg_keep.length(), 1)

  let copy_coef_u1 = dmp_copy(DensePoly::Coef(db_wb_fe(7)), 1)
  assert_true(copy_coef_u1 is DensePoly::Coef(_))

  assert_eq(dup_from_sympy([], Domain::ZZ).length(), 0)
  let rat_coef = dense_rat_to_dense(
    DenseRat::Coef(@symnum.BigRational::from_int(3)),
    0,
    Domain::ZZ,
  )
  assert_true(rat_coef is DensePoly::Poly(_))
  let rat_bad : Result[DensePoly, PolyError] = try? dense_rat_to_dense(
    DenseRat::Poly([DenseRat::Poly([])]),
    0,
    Domain::ZZ,
  )
  assert_true(rat_bad is Err(PolyError::NonPolynomial))
  let rat_coef_u1 = dense_rat_to_dense(
    DenseRat::Coef(@symnum.BigRational::from_int(4)),
    1,
    Domain::ZZ,
  )
  assert_true(rat_coef_u1 is DensePoly::Poly(_))

  let nth_coef0 = dmp_nth(DensePoly::Coef(db_wb_fe(5)), 0, 1)
  assert_true(nth_coef0 is DensePoly::Coef(_))
  let nth_coef_zero = dmp_nth(DensePoly::Coef(db_wb_fe(5)), 1, 1)
  assert_true(dmp_zero_p(nth_coef_zero, 0))

  guard dmp_zero(-1) is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_zero(u<0) should return []")
  }
  assert_true(!dmp_zero_p(DensePoly::Coef(db_wb_fe(0)), 1))

  assert_true(!dmp_ground_p(DensePoly::Coef(db_wb_fe(1)), Some(db_wb_fe(1)), 1))
  assert_true(dmp_ground_p(DensePoly::Coef(db_wb_fe(1)), None, 0))
  assert_true(
    !dmp_ground_p(
        DensePoly::Poly([DensePoly::Poly([])]),
        Some(db_wb_fe(1)),
        0,
      )
  )
  assert_true(dmp_ground_p(DensePoly::Coef(db_wb_fe(1)), Some(db_wb_fe(1)), 0))

  inspect(
    dmp_ground_nth(DensePoly::Coef(db_wb_fe(2)), [0], 0, Domain::ZZ),
    content="2",
  )
  inspect(
    dmp_ground_nth(DensePoly::Coef(db_wb_fe(2)), [1], 0, Domain::ZZ),
    content="0",
  )
  inspect(dmp_ground_nth(DensePoly::Poly([]), [], 0, Domain::ZZ), content="0")
  inspect(
    dmp_ground_nth(
      DensePoly::Poly([
        DensePoly::Coef(db_wb_fe(1)),
        DensePoly::Coef(db_wb_fe(2)),
      ]),
      [],
      0,
      Domain::ZZ,
    ),
    content="0",
  )
  inspect(
    dmp_ground_nth(
      DensePoly::Poly([DensePoly::Coef(db_wb_fe(9))]),
      [],
      0,
      Domain::ZZ,
    ),
    content="9",
  )
  inspect(
    dmp_ground_nth(DensePoly::Poly([DensePoly::Poly([])]), [], 0, Domain::ZZ),
    content="0",
  )

  assert_true(
    dmp_nest(DensePoly::Coef(db_wb_fe(5)), 2, Domain::ZZ)
        is DensePoly::Poly(_)
  )
  let raise_coef_u0 = dmp_raise(DensePoly::Coef(db_wb_fe(3)), 1, 0, Domain::ZZ)
  assert_true(raise_coef_u0 is DensePoly::Poly(_))
  let raise_coef_u1 = dmp_raise(DensePoly::Coef(db_wb_fe(3)), 1, 1, Domain::ZZ)
  assert_true(raise_coef_u1 is DensePoly::Poly(_))

  let (g_hit1, _) = dup_deflate(
    [db_wb_fe(1), db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)],
    Domain::ZZ,
  )
  assert_eq(g_hit1, 1)
  let (g_le1, _) = dup_deflate(
    [db_wb_fe(0), db_wb_fe(0), db_wb_fe(0), db_wb_fe(1)],
    Domain::ZZ,
  )
  assert_eq(g_le1, 1)

  let def_map : Map[Monomial, FieldElem] = Map::new()
  def_map.set(Monomial::{ exps: [1, 1] }, db_wb_fe(1))
  def_map.set(Monomial::{ exps: [0, 0] }, db_wb_fe(1))
  let def_dense = dmp_from_dict(def_map, 1, Domain::ZZ)
  let def_all_one = dmp_deflate(def_dense, 1, Domain::ZZ)
  assert_true(
    def_all_one.0.length() == 2 &&
        def_all_one.0[0] == 1 &&
        def_all_one.0[1] == 1
  )
  let def_need_fill_map : Map[Monomial, FieldElem] = Map::new()
  def_need_fill_map.set(Monomial::{ exps: [2, 0] }, db_wb_fe(1))
  def_need_fill_map.set(Monomial::{ exps: [0, 0] }, db_wb_fe(1))
  let def_need_fill = dmp_deflate(
    dmp_from_dict(def_need_fill_map, 1, Domain::ZZ),
    1,
    Domain::ZZ,
  )
  assert_true(
    def_need_fill.0.length() == 2 &&
        def_need_fill.0[0] == 2 &&
        def_need_fill.0[1] == 1
  )

  let (g_early1, _) = dup_multi_deflate(
    [[db_wb_fe(1), db_wb_fe(1), db_wb_fe(0)]],
    Domain::ZZ,
  )
  assert_eq(g_early1, 1)
  let (g_all_mix, _) = dup_multi_deflate(
    [
      [db_wb_fe(1), db_wb_fe(0), db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)],
      [
        db_wb_fe(1),
        db_wb_fe(0),
        db_wb_fe(0),
        db_wb_fe(1),
        db_wb_fe(0),
        db_wb_fe(0),
        db_wb_fe(0),
      ],
    ],
    Domain::ZZ,
  )
  assert_eq(g_all_mix, 1)
  let (g_all_zeroish, _) = dup_multi_deflate(
    [
      [db_wb_fe(0), db_wb_fe(0), db_wb_fe(1)],
      [db_wb_fe(0), db_wb_fe(0), db_wb_fe(0), db_wb_fe(2)],
    ],
    Domain::ZZ,
  )
  assert_eq(g_all_zeroish, 1)

  let dmd_map : Map[Monomial, FieldElem] = Map::new()
  dmd_map.set(Monomial::{ exps: [1, 0] }, db_wb_fe(1))
  dmd_map.set(Monomial::{ exps: [0, 1] }, db_wb_fe(1))
  dmd_map.set(Monomial::{ exps: [0, 0] }, db_wb_fe(1))
  let dmd_poly = dmp_from_dict(dmd_map, 1, Domain::ZZ)
  let dmd_all_one = dmp_multi_deflate([dmd_poly], 1, Domain::ZZ)
  assert_true(dmd_all_one.0[0] == 1 && dmd_all_one.0[1] == 1)

  let rec_empty = rec_inflate(DensePoly::Poly([]), [2, 2], 1, 0, Domain::ZZ)
  guard rec_empty is DensePoly::Poly(items) && items.length() == 0 else {
    fail("rec_inflate should preserve empty mapped branches")
  }
  let rec_coef = rec_inflate(
    DensePoly::Coef(db_wb_fe(2)),
    [2, 2],
    1,
    0,
    Domain::ZZ,
  )
  assert_true(rec_coef is DensePoly::Poly(_))

  let inflated_u0 = dmp_inflate(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(1)]),
    [2],
    0,
    Domain::ZZ,
  )
  assert_true(inflated_u0 is DensePoly::Poly(_))

  let dpp_merge : Map[Monomial, Poly] = Map::new()
  let px = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    @symcore.symbol("x") + @symcore.int(1),
  )
  let py = PolyBuilder::new(["x"], Domain::QQ).from_expr(
    @symcore.symbol("x") + @symcore.int(2),
  )
  dpp_merge.set(Monomial::{ exps: [2, 1] }, px)
  dpp_merge.set(Monomial::{ exps: [2, 0] }, py)
  let dpp_poly = dpp_from_dict(dpp_merge, 1, ["x"], Domain::QQ)
  assert_true(dpp_poly is DensePolyPoly::Poly(_))
  let dpp_tree = DensePolyPoly::Poly([
    DensePolyPoly::Poly([DensePolyPoly::Coef(px)]),
  ])
  let dpp_tree_map = dpp_to_dict(dpp_tree, 1)
  assert_eq(dpp_tree_map.length(), 1)

  let ex_map : Map[Monomial, FieldElem] = Map::new()
  ex_map.set(Monomial::{ exps: [1, 0] }, db_wb_fe(1))
  ex_map.set(Monomial::{ exps: [0, 1] }, db_wb_fe(1))
  let ex_dense = dmp_from_dict(ex_map, 1, Domain::ZZ)
  let ex_none = dmp_exclude(ex_dense, 1, Domain::ZZ)
  assert_eq(ex_none.0.length(), 0)

  let terms_early = dmp_terms_gcd(
    dense_from_coeffs([db_wb_fe(1)]),
    0,
    Domain::ZZ,
  )
  assert_true(terms_early.0.length() == 1 && terms_early.0[0] == 0)
}
