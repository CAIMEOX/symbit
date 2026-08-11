///|
fn db_wb_fe(n : Int) -> FieldElem {
  QQ(@symnum.BigRational::from_int(n))
}

///|
fn db_wb_coef(n : Int) -> DensePoly {
  Coef(db_wb_fe(n))
}

///|
fn db_wb_poly(xs : Array[DensePoly]) -> DensePoly {
  Poly(xs)
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
    (QQ(lhs), QQ(rhs)) => QQ(lhs.add_r(rhs))
    _ => a
  }
}

///|
test "densebasic wb: dense extraction and coefficient edge branches" {
  let c0 = dense_to_coeffs(Coef(db_wb_fe(0)))
  assert_true(c0.length() == 0)

  let c1 = dense_to_coeffs(Coef(db_wb_fe(3)))
  assert_true(c1.length() == 1 && Show::to_string(c1[0]) == "3")

  sympolys_assert_error(
    fn() raise PolyError { dense_to_coeffs(Poly([Poly([])])) },
    "NotUnivariate",
  )

  let lc = dmp_LC(Coef(db_wb_fe(9)))
  let tc = dmp_TC(Coef(db_wb_fe(8)))
  assert_true(lc is Coef(_) && tc is Coef(_))

  let glc_nested = dmp_ground_LC(db_wb_poly([db_wb_poly([])]), 0)
  let gtc_nested = dmp_ground_TC(db_wb_poly([db_wb_poly([])]), 0)
  assert_true(
    Show::to_string(glc_nested) == "0" && Show::to_string(gtc_nested) == "0",
  )
}

///|
test "densebasic wb: dup_from_list and dup_truncate" {
  let from = dup_from_list(
    [db_wb_fe(0), db_wb_fe(0), db_wb_fe(2), db_wb_fe(1), db_wb_fe(0)],
    ZZ,
  )
  inspect(from.map(c => Show::to_string(c)).join(","), content="2,1,0")

  let truncated = dup_truncate(
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3), db_wb_fe(4), db_wb_fe(5)],
    3,
    ZZ,
  )
  inspect(truncated.map(c => Show::to_string(c)).join(","), content="3,4,5")
}

///|
test "densebasic wb: dup_pretty frontdoor" {
  let f = [db_wb_fe(1), db_wb_fe(0), db_wb_fe(5), db_wb_fe(0), db_wb_fe(7)]
  inspect(dup_pretty(f, "x"), content="x**4 + 5*x**2 + 7")
  inspect(dup_pretty(f, "x", ascending=true), content="7 + 5*x**2 + x**4")
  inspect(
    dup_pretty([db_wb_fe(-1), db_wb_fe(2), db_wb_fe(-3)], "t"),
    content="-t**2 + 2*t - 3",
  )
  inspect(dup_pretty([], "x"), content="0")
}

///|
test "densebasic wb: dpp conversion helper branches" {
  let gens = ["x"]
  let nonzero = db_wb_const_poly(2, gens, QQ)
  let zero = Poly::zero(gens, QQ)

  let empty : Map[Monomial, Poly] = Map([])
  let u0_empty = dpp_from_dict(empty, 0, gens, QQ)
  assert_true(dpp_zero_p(u0_empty))

  let bad_u0 : Map[Monomial, Poly] = Map([])
  bad_u0.set({ exps: [1, 0] }, nonzero)
  sympolys_assert_error(
    fn() raise PolyError { dpp_from_dict(bad_u0, 0, gens, QQ) },
    "DomainMismatch",
  )

  let u1_empty = dpp_from_dict(empty, 1, gens, QQ)
  assert_true(dpp_zero_p(u1_empty))

  let bad_u1 : Map[Monomial, Poly] = Map([])
  bad_u1.set({ exps: [2] }, nonzero)
  sympolys_assert_error(
    fn() raise PolyError { dpp_from_dict(bad_u1, 1, gens, QQ) },
    "DomainMismatch",
  )

  let only_zero : Map[Monomial, Poly] = Map([])
  only_zero.set({ exps: [2, 1] }, zero)
  let only_zero_dpp = dpp_from_dict(only_zero, 1, gens, QQ)
  assert_true(dpp_zero_p(only_zero_dpp))

  let td0 = dpp_to_dict(Coef(nonzero), 0)
  assert_true(td0.length() == 1)

  let bad_nested : DensePolyPoly = Poly([Poly([])])
  sympolys_assert_error(
    fn() raise PolyError { dpp_to_dict(bad_nested, 0) },
    "NonPolynomial",
  )

  let td1 = dpp_to_dict(Coef(nonzero), 1)
  assert_true(td1.length() == 1)
}

///|
test "densebasic wb: inject/eject, terms, pairwise apply, slice/random edges" {
  let wrong_poly = Poly::from_expr(Symbol("z") + @symcore.int(1), ["z"], QQ)
  sympolys_assert_error(
    fn() raise PolyError { dmp_inject(Coef(wrong_poly), 0, ["x"], QQ) },
    "DomainMismatch",
  )

  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let xy_poly = PolyBuilder::new(["x", "y"], QQ).from_expr(
    x + y + @symcore.int(1),
  )
  let dpp = DensePolyPoly::Poly([Coef(xy_poly)])
  let (inj_front, w_front) = dmp_inject(dpp, 0, ["x", "y"], QQ, front=true)
  assert_true(w_front == 2)
  let ejected = dmp_eject(inj_front, w_front, ["x", "y"], QQ, front=true)
  let ejected_dict = dpp_to_dict(ejected, 0)
  assert_true(ejected_dict.length() == 1)

  sympolys_assert_error(
    fn() raise PolyError { dmp_eject(db_wb_poly([]), 0, ["x", "y"], QQ) },
    "BadExponent",
  )

  let (k, trimmed) = dup_terms_gcd([db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)], ZZ)
  assert_true(
    k == 2 && trimmed.length() == 1 && Show::to_string(trimmed[0]) == "1",
  )

  let (exps, reduced) = dmp_terms_gcd(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)]),
    0,
    ZZ,
  )
  assert_true(exps.length() == 1 && exps[0] == 2)
  let reduced_coeffs = dense_to_coeffs(reduced)
  assert_true(
    reduced_coeffs.length() == 1 && Show::to_string(reduced_coeffs[0]) == "1",
  )

  let ap1 = dup_apply_pairs(
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)],
    [db_wb_fe(4)],
    db_wb_add_pair,
    [],
    ZZ,
  )
  assert_true(ap1.length() == 3)
  let ap2 = dup_apply_pairs(
    [db_wb_fe(4)],
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)],
    db_wb_add_pair,
    [],
    ZZ,
  )
  assert_true(ap2.length() == 3)

  let da = dmp_apply_pairs(
    db_wb_poly([db_wb_coef(1), db_wb_coef(2)]),
    db_wb_coef(3),
    db_wb_add_pair,
    [],
    1,
    ZZ,
  )
  let da_dict = dmp_to_dict(da, 1, ZZ)
  assert_true(da_dict.length() > 0)

  let s0 = dup_slice([db_wb_fe(0), db_wb_fe(0)], 2, 0, ZZ)
  assert_true(s0.length() == 0)
  let s1 = dup_slice([db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)], 1, 2, ZZ)
  assert_true(s1.length() > 0 && fe_is_zero(s1[s1.length() - 1]))

  sympolys_assert_error(
    fn() raise PolyError {
      dmp_slice_in(
        dense_from_coeffs([db_wb_fe(1), db_wb_fe(2)]),
        1,
        2,
        2,
        1,
        ZZ,
      )
    },
    "BadExponent",
  )
  let sliced_u0 = dmp_slice_in(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)]),
    1,
    3,
    0,
    0,
    ZZ,
  )
  let sliced_u0_coeffs = dense_to_coeffs(sliced_u0)
  assert_true(sliced_u0_coeffs.length() > 0)

  let rand_fixed = dup_random(3, 0, 0, ZZ)
  assert_true(!fe_is_zero(rand_fixed[0]))
}

///|
test "densebasic wb: remaining branch sweep for deflate/inflate/dict/pairs helpers" {
  inspect(dup_LC([]), content="0")
  inspect(dup_TC([]), content="0")
  assert_true(dup_copy([]).length() == 0)
  inspect(dup_nth([], 0), content="0")

  let z_lc = dmp_LC(Poly([]))
  let z_tc = dmp_TC(Poly([]))
  guard z_lc is Poly(items) && items.length() == 0 else {
    fail("dmp_LC([]) should return []")
  }
  guard z_tc is Poly(items) && items.length() == 0 else {
    fail("dmp_TC([]) should return []")
  }
  assert_true(dmp_strip(Coef(db_wb_fe(7))) is Coef(_))
  let rev_empty = dmp_reverse(Poly([]))
  guard rev_empty is Poly(items) && items.length() == 0 else {
    fail("dmp_reverse([]) should stay []")
  }

  let empty_dict : Map[Monomial, FieldElem] = Map([])
  assert_true(dup_from_dict(empty_dict, ZZ).length() == 0)
  let bad_uni_dict : Map[Monomial, FieldElem] = Map([])
  bad_uni_dict.set({ exps: [1, 0] }, db_wb_fe(1))
  sympolys_assert_error(
    fn() raise PolyError { dup_from_dict(bad_uni_dict, ZZ) },
    "DomainMismatch",
  )

  let empty_raw : Map[Int, FieldElem] = Map([])
  assert_true(dup_from_raw_dict(empty_raw, ZZ).length() == 0)

  let bad_mv_dict : Map[Monomial, FieldElem] = Map([])
  bad_mv_dict.set({ exps: [2] }, db_wb_fe(1))
  sympolys_assert_error(
    fn() raise PolyError { dmp_from_dict(bad_mv_dict, 1, ZZ) },
    "DomainMismatch",
  )

  let td_coef = dmp_to_dict(Coef(db_wb_fe(4)), 1, ZZ)
  assert_true(td_coef.length() == 1)
  assert_true(dmp_to_raw_dict(Coef(db_wb_fe(3)), 1, ZZ).length() == 0)

  sympolys_assert_error(
    fn() raise PolyError { dmp_swap(db_wb_poly([db_wb_coef(1)]), -1, 0, 0, ZZ) },
    "BadExponent",
  )
  let sw_same = dmp_swap(db_wb_poly([db_wb_coef(1)]), 0, 0, 0, ZZ)
  let sw_same_coeffs = dense_to_coeffs(sw_same)
  assert_true(sw_same_coeffs.length() == 1)

  sympolys_assert_error(
    fn() raise PolyError {
      dmp_permute(db_wb_poly([db_wb_coef(1)]), [2], 0, ZZ)
    },
    "BadExponent",
  )

  assert_true(dmp_nest(db_wb_coef(3), 0, ZZ) is Coef(_))
  sympolys_assert_error(
    fn() raise PolyError { dmp_raise(db_wb_poly([db_wb_poly([])]), 1, 0, ZZ) },
    "NotUnivariate",
  )

  let (g0, _) = dup_deflate([db_wb_fe(2)], ZZ)
  assert_true(g0 == 1)
  let (dz_b, dz_poly) = dmp_deflate(dmp_zero(1), 1, ZZ)
  assert_true(dz_b.length() == 2 && dmp_zero_p(dz_poly, 1))

  let (md_empty_m, md_empty_out) = dup_multi_deflate([], ZZ)
  assert_true(md_empty_m == 1 && md_empty_out.length() == 0)
  let (md_const_m, _) = dup_multi_deflate([[db_wb_fe(5)]], ZZ)
  assert_true(md_const_m == 1)

  let dmd_empty = dmp_multi_deflate([], 1, ZZ)
  assert_true(dmd_empty.0.length() == 2 && dmd_empty.1.length() == 0)
  let dmd_u0 = dmp_multi_deflate(
    [dense_from_coeffs([db_wb_fe(1), db_wb_fe(0), db_wb_fe(1)])],
    0,
    ZZ,
  )
  assert_true(dmd_u0.0.length() == 1 && dmd_u0.1.length() == 1)

  sympolys_assert_error(
    fn() raise PolyError { dup_inflate([db_wb_fe(1)], 0, ZZ) },
    "BadExponent",
  )
  assert_true(dup_inflate([db_wb_fe(1)], 1, ZZ).length() == 1)

  sympolys_assert_error(
    fn() raise PolyError {
      dmp_inflate(db_wb_poly([db_wb_coef(1)]), [0, 1], 1, ZZ)
    },
    "BadExponent",
  )
  let keep_all_one = dmp_inflate(db_wb_poly([db_wb_coef(1)]), [1, 1], 1, ZZ)
  let keep_all_one_dict = dmp_to_dict(keep_all_one, 1, ZZ)
  assert_true(keep_all_one_dict.length() == 1)

  guard dpp_zero(-1) is Poly(items) && items.length() == 0 else {
    fail("dpp_zero(-1) should return []")
  }
  let dpp_nonzero_coeff = db_wb_const_poly(1, ["x"], QQ)
  assert_true(!dpp_zero_p(Poly([Coef(dpp_nonzero_coeff)])))

  let slice_trim = dup_slice([db_wb_fe(0), db_wb_fe(1), db_wb_fe(2)], 1, 3, ZZ)
  assert_true(
    slice_trim.length() >= 2 && fe_is_zero(slice_trim[slice_trim.length() - 1]),
  )

  let dmp_ap = dmp_apply_pairs(
    db_wb_coef(2),
    db_wb_poly([db_wb_coef(1), db_wb_coef(3)]),
    db_wb_add_pair,
    [],
    1,
    ZZ,
  )
  let dmp_ap_dict = dmp_to_dict(dmp_ap, 1, ZZ)
  assert_true(dmp_ap_dict.length() > 0)

  let dmp_ap2 = dmp_apply_pairs(
    db_wb_poly([db_wb_coef(1)]),
    db_wb_poly([db_wb_coef(2), db_wb_coef(3), db_wb_coef(4)]),
    db_wb_add_pair,
    [],
    1,
    ZZ,
  )
  let dmp_ap2_dict = dmp_to_dict(dmp_ap2, 1, ZZ)
  assert_true(dmp_ap2_dict.length() > 0)
}

///|
test "densebasic wb: residual branch sweep (ground/convert/rat/inflate/dpp)" {
  let gf_copy = dup_copy([GFp(5, 2)])
  assert_true(gf_copy.length() == 1 && Show::to_string(gf_copy[0]) == "2")

  sympolys_assert_error(
    fn() raise PolyError {
      dmp_validate(Poly([Coef(db_wb_fe(1)), Poly([Coef(db_wb_fe(2))])]))
    },
    "NonPolynomial",
  )

  let strip_u0 = dense_strip_with_u(Poly([Coef(db_wb_fe(1)), Poly([])]), 0)
  assert_true(strip_u0 is Poly(_))
  let strip_coef_u2 = dense_strip_with_u(Coef(db_wb_fe(3)), 2)
  assert_true(strip_coef_u2 is Coef(_))

  inspect(dmp_ground_LC(Coef(db_wb_fe(7)), 0), content="7")
  inspect(dmp_ground_LC(Coef(db_wb_fe(7)), 1), content="7")
  inspect(dmp_ground_LC(Poly([]), 1), content="0")
  inspect(dmp_ground_TC(Coef(db_wb_fe(8)), 0), content="8")
  inspect(dmp_ground_TC(Coef(db_wb_fe(8)), 1), content="8")
  inspect(dmp_ground_TC(Poly([]), 1), content="0")

  let lt_coef_depth = dmp_true_LT(Coef(db_wb_fe(2)), 1)
  assert_true(Show::to_string(lt_coef_depth.1) == "2")
  let lt_empty_depth = dmp_true_LT(Poly([]), 1)
  assert_true(Show::to_string(lt_empty_depth.1) == "0")
  let lt_coef_u0 = dmp_true_LT(Coef(db_wb_fe(3)), 0)
  assert_true(Show::to_string(lt_coef_u0.1) == "3")
  let lt_nested_u0 = dmp_true_LT(Poly([Poly([])]), 0)
  assert_true(Show::to_string(lt_nested_u0.1) == "0")

  inspect(dmp_degree(Coef(db_wb_fe(5)), 0), content="0")
  inspect(dmp_degree_in(Coef(db_wb_fe(0)), 1, 1), content="-1")
  inspect(dmp_degree_in(Coef(db_wb_fe(2)), 1, 1), content="0")

  let norm_u0_nonuni = dmp_normal(Poly([Coef(db_wb_fe(1)), Poly([])]), 0)
  assert_true(norm_u0_nonuni is Poly(_))
  let norm_coef_u0 = dmp_normal(Coef(db_wb_fe(2)), 0)
  assert_true(norm_coef_u0 is Coef(_))
  let norm_coef_u1 = dmp_normal(Coef(db_wb_fe(2)), 1)
  assert_true(norm_coef_u1 is Coef(_))

  let conv_u0_nonuni = dmp_convert(
    Poly([Coef(db_wb_fe(1)), Poly([])]),
    0,
    ZZ,
    QQ,
  )
  assert_true(conv_u0_nonuni is Poly(_))
  let conv_coef_u0 = dmp_convert(Coef(db_wb_fe(1)), 0, ZZ, QQ)
  assert_true(conv_coef_u0 is Coef(_))
  let conv_coef_u1 = dmp_convert(Coef(db_wb_fe(1)), 1, ZZ, QQ)
  assert_true(conv_coef_u1 is Coef(_))
  let conv_empty = dup_convert([], ZZ, QQ)
  assert_true(conv_empty.length() == 0)
  let gfext_sample = FieldElem::GFExt(5, [1], [1, 0, 1])
  let gfext_keep = dup_convert(
    [gfext_sample],
    GFExt(5, 2, [1, 0, 1]),
    GFExt(5, 2, [1, 0, 1]),
  )
  assert_true(gfext_keep.length() == 1)
  let a_alg = @symcore.Expr::Symbol("a")
  let minpoly_alg = PolyBuilder::new(["a"], QQ).from_expr(
    (a_alg ^ @symcore.int(2)) + @symcore.int(1),
  )
  let alg_sample = FieldElem::AlgExt(
    QQ,
    [QQ(@symnum.BigRational::one())],
    minpoly_alg,
    "a",
  )
  let alg_keep = dup_convert([alg_sample], QQ, QQ)
  assert_true(alg_keep.length() == 1)

  let copy_coef_u1 = dmp_copy(Coef(db_wb_fe(7)), 1)
  assert_true(copy_coef_u1 is Coef(_))

  assert_true(dup_from_sympy([], ZZ).length() == 0)
  let rat_coef = dense_rat_to_dense(
    Coef(@symnum.BigRational::from_int(3)),
    0,
    ZZ,
  )
  assert_true(rat_coef is Poly(_))
  sympolys_assert_error(
    fn() raise PolyError { dense_rat_to_dense(Poly([Poly([])]), 0, ZZ) },
    "NonPolynomial",
  )
  let rat_coef_u1 = dense_rat_to_dense(
    Coef(@symnum.BigRational::from_int(4)),
    1,
    ZZ,
  )
  assert_true(rat_coef_u1 is Poly(_))

  let nth_coef0 = dmp_nth(Coef(db_wb_fe(5)), 0, 1)
  assert_true(nth_coef0 is Coef(_))
  let nth_coef_zero = dmp_nth(Coef(db_wb_fe(5)), 1, 1)
  assert_true(dmp_zero_p(nth_coef_zero, 0))

  guard dmp_zero(-1) is Poly(items) && items.length() == 0 else {
    fail("dmp_zero(u<0) should return []")
  }
  assert_true(!dmp_zero_p(Coef(db_wb_fe(0)), 1))

  assert_true(!dmp_ground_p(Coef(db_wb_fe(1)), Some(db_wb_fe(1)), 1))
  assert_true(dmp_ground_p(Coef(db_wb_fe(1)), None, 0))
  assert_true(!dmp_ground_p(Poly([Poly([])]), Some(db_wb_fe(1)), 0))
  assert_true(dmp_ground_p(Coef(db_wb_fe(1)), Some(db_wb_fe(1)), 0))

  inspect(dmp_ground_nth(Coef(db_wb_fe(2)), [0], 0, ZZ), content="2")
  inspect(dmp_ground_nth(Coef(db_wb_fe(2)), [1], 0, ZZ), content="0")
  inspect(dmp_ground_nth(Poly([]), [], 0, ZZ), content="0")
  inspect(
    dmp_ground_nth(Poly([Coef(db_wb_fe(1)), Coef(db_wb_fe(2))]), [], 0, ZZ),
    content="0",
  )
  inspect(dmp_ground_nth(Poly([Coef(db_wb_fe(9))]), [], 0, ZZ), content="9")
  inspect(dmp_ground_nth(Poly([Poly([])]), [], 0, ZZ), content="0")

  assert_true(dmp_nest(Coef(db_wb_fe(5)), 2, ZZ) is Poly(_))
  let raise_coef_u0 = dmp_raise(Coef(db_wb_fe(3)), 1, 0, ZZ)
  assert_true(raise_coef_u0 is Poly(_))
  let raise_coef_u1 = dmp_raise(Coef(db_wb_fe(3)), 1, 1, ZZ)
  assert_true(raise_coef_u1 is Poly(_))

  let (g_hit1, _) = dup_deflate(
    [db_wb_fe(1), db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)],
    ZZ,
  )
  assert_true(g_hit1 == 1)
  let (g_le1, _) = dup_deflate(
    [db_wb_fe(0), db_wb_fe(0), db_wb_fe(0), db_wb_fe(1)],
    ZZ,
  )
  assert_true(g_le1 == 1)

  let def_map : Map[Monomial, FieldElem] = Map([])
  def_map.set({ exps: [1, 1] }, db_wb_fe(1))
  def_map.set({ exps: [0, 0] }, db_wb_fe(1))
  let def_dense = dmp_from_dict(def_map, 1, ZZ)
  let def_all_one = dmp_deflate(def_dense, 1, ZZ)
  assert_true(
    def_all_one.0.length() == 2 &&
    def_all_one.0[0] == 1 &&
    def_all_one.0[1] == 1,
  )
  let def_need_fill_map : Map[Monomial, FieldElem] = Map([])
  def_need_fill_map.set({ exps: [2, 0] }, db_wb_fe(1))
  def_need_fill_map.set({ exps: [0, 0] }, db_wb_fe(1))
  let def_need_fill = dmp_deflate(
    dmp_from_dict(def_need_fill_map, 1, ZZ),
    1,
    ZZ,
  )
  assert_true(
    def_need_fill.0.length() == 2 &&
    def_need_fill.0[0] == 2 &&
    def_need_fill.0[1] == 1,
  )

  let (g_early1, _) = dup_multi_deflate(
    [[db_wb_fe(1), db_wb_fe(1), db_wb_fe(0)]],
    ZZ,
  )
  assert_true(g_early1 == 1)
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
    ZZ,
  )
  assert_true(g_all_mix == 1)
  let (g_all_zeroish, _) = dup_multi_deflate(
    [
      [db_wb_fe(0), db_wb_fe(0), db_wb_fe(1)],
      [db_wb_fe(0), db_wb_fe(0), db_wb_fe(0), db_wb_fe(2)],
    ],
    ZZ,
  )
  assert_true(g_all_zeroish == 1)

  let dmd_map : Map[Monomial, FieldElem] = Map([])
  dmd_map.set({ exps: [1, 0] }, db_wb_fe(1))
  dmd_map.set({ exps: [0, 1] }, db_wb_fe(1))
  dmd_map.set({ exps: [0, 0] }, db_wb_fe(1))
  let dmd_poly = dmp_from_dict(dmd_map, 1, ZZ)
  let dmd_all_one = dmp_multi_deflate([dmd_poly], 1, ZZ)
  assert_true(dmd_all_one.0[0] == 1 && dmd_all_one.0[1] == 1)

  let rec_empty = rec_inflate(Poly([]), [2, 2], 1, 0, ZZ)
  guard rec_empty is Poly(items) && items.length() == 0 else {
    fail("rec_inflate should preserve empty mapped branches")
  }
  let rec_coef = rec_inflate(Coef(db_wb_fe(2)), [2, 2], 1, 0, ZZ)
  assert_true(rec_coef is Poly(_))

  let inflated_u0 = dmp_inflate(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(1)]),
    [2],
    0,
    ZZ,
  )
  assert_true(inflated_u0 is Poly(_))

  let dpp_merge : Map[Monomial, Poly] = Map([])
  let px = PolyBuilder::new(["x"], QQ).from_expr(Symbol("x") + @symcore.int(1))
  let py = PolyBuilder::new(["x"], QQ).from_expr(Symbol("x") + @symcore.int(2))
  dpp_merge.set({ exps: [2, 1] }, px)
  dpp_merge.set({ exps: [2, 0] }, py)
  let dpp_poly = dpp_from_dict(dpp_merge, 1, ["x"], QQ)
  assert_true(dpp_poly is Poly(_))
  let dpp_tree = DensePolyPoly::Poly([Poly([Coef(px)])])
  let dpp_tree_map = dpp_to_dict(dpp_tree, 1)
  assert_true(dpp_tree_map.length() == 1)

  let ex_map : Map[Monomial, FieldElem] = Map([])
  ex_map.set({ exps: [1, 0] }, db_wb_fe(1))
  ex_map.set({ exps: [0, 1] }, db_wb_fe(1))
  let ex_dense = dmp_from_dict(ex_map, 1, ZZ)
  let ex_none = dmp_exclude(ex_dense, 1, ZZ)
  assert_true(ex_none.0.length() == 0)

  let terms_early = dmp_terms_gcd(dense_from_coeffs([db_wb_fe(1)]), 0, ZZ)
  assert_true(terms_early.0.length() == 1 && terms_early.0[0] == 0)
}
