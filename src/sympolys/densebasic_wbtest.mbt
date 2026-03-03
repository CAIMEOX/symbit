///|
fn db_wb_fe(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
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
fn db_wb_add_pair(a : FieldElem, b : FieldElem, _args : Array[FieldElem]) -> FieldElem {
  try! fe_add(a, b)
}

///|
test "densebasic wb: dense extraction and coefficient edge branches" {
  let c0 = try! dense_to_coeffs(DensePoly::Coef(db_wb_fe(0)))
  guard c0.length() == 0 else {
    fail("dense_to_coeffs(Coef(0)) should strip to []")
  }

  let c1 = try! dense_to_coeffs(DensePoly::Coef(db_wb_fe(3)))
  guard c1.length() == 1 && c1[0].to_string() == "3" else {
    fail("dense_to_coeffs(Coef(3)) mismatch")
  }

  let non_uni : Result[Array[FieldElem], PolyError] = try? dense_to_coeffs(
    DensePoly::Poly([DensePoly::Poly([])]),
  )
  guard non_uni is Err(PolyError::NotUnivariate) else {
    fail("dense_to_coeffs nested poly should raise NotUnivariate")
  }

  let lc = dmp_LC(DensePoly::Coef(db_wb_fe(9)))
  let tc = dmp_TC(DensePoly::Coef(db_wb_fe(8)))
  guard lc is DensePoly::Coef(_) && tc is DensePoly::Coef(_) else {
    fail("dmp_LC/dmp_TC on Coef should stay Coef")
  }

  let glc_nested = try! dmp_ground_LC(db_wb_poly([db_wb_poly([])]), 0)
  let gtc_nested = try! dmp_ground_TC(db_wb_poly([db_wb_poly([])]), 0)
  guard glc_nested.to_string() == "0" && gtc_nested.to_string() == "0" else {
    fail("dmp_ground_LC/TC nested non-univariate branch mismatch")
  }
}

///|
test "densebasic wb: dpp conversion helper branches" {
  let gens = ["x"]
  let nonzero = try! db_wb_const_poly(2, gens, Domain::QQ)
  let zero = Poly::zero(gens, Domain::QQ)

  let empty : Map[Monomial, Poly] = Map::new()
  let u0_empty = try! dpp_from_dict(empty, 0, gens, Domain::QQ)
  guard dpp_zero_p(u0_empty) else {
    fail("dpp_from_dict(u=0, empty) should be zero")
  }

  let bad_u0 : Map[Monomial, Poly] = Map::new()
  bad_u0.set(Monomial::{ exps: [1, 0] }, nonzero)
  let bad_u0_res : Result[DensePolyPoly, PolyError] = try? dpp_from_dict(
    bad_u0,
    0,
    gens,
    Domain::QQ,
  )
  guard bad_u0_res is Err(PolyError::DomainMismatch) else {
    fail("dpp_from_dict(u=0) should reject monomial arity != 1")
  }

  let u1_empty = try! dpp_from_dict(empty, 1, gens, Domain::QQ)
  guard dpp_zero_p(u1_empty) else {
    fail("dpp_from_dict(u>0, empty) should be dpp_zero")
  }

  let bad_u1 : Map[Monomial, Poly] = Map::new()
  bad_u1.set(Monomial::{ exps: [2] }, nonzero)
  let bad_u1_res : Result[DensePolyPoly, PolyError] = try? dpp_from_dict(
    bad_u1,
    1,
    gens,
    Domain::QQ,
  )
  guard bad_u1_res is Err(PolyError::DomainMismatch) else {
    fail("dpp_from_dict(u>0) should reject monomial arity mismatch")
  }

  let only_zero : Map[Monomial, Poly] = Map::new()
  only_zero.set(Monomial::{ exps: [2, 1] }, zero)
  let only_zero_dpp = try! dpp_from_dict(only_zero, 1, gens, Domain::QQ)
  guard dpp_zero_p(only_zero_dpp) else {
    fail("dpp_from_dict should strip all-leading zero Poly coefficients")
  }

  let td0 = try! dpp_to_dict(DensePolyPoly::Coef(nonzero), 0)
  guard td0.length() == 1 else {
    fail("dpp_to_dict(Coef, u=0) should emit exponent 0 entry")
  }

  let bad_nested : DensePolyPoly = DensePolyPoly::Poly([DensePolyPoly::Poly([])])
  let bad_nested_res : Result[Map[Monomial, Poly], PolyError] = try? dpp_to_dict(
    bad_nested,
    0,
  )
  guard bad_nested_res is Err(PolyError::NonPolynomial) else {
    fail("dpp_to_dict(u=0) should reject nested DensePolyPoly::Poly")
  }

  let td1 = try! dpp_to_dict(DensePolyPoly::Coef(nonzero), 1)
  guard td1.length() == 1 else {
    fail("dpp_to_dict(Coef, u>0) should emit zero monomial")
  }
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
  guard bad_inject is Err(PolyError::DomainMismatch) else {
    fail("dmp_inject should reject mismatched inner poly generators")
  }

  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let xy_poly = PolyBuilder::new(["x", "y"], Domain::QQ).from_expr(x + y + @symcore.int(1))
  let dpp = DensePolyPoly::Poly([DensePolyPoly::Coef(xy_poly)])
  let (inj_front, w_front) = try! dmp_inject(
    dpp,
    0,
    ["x", "y"],
    Domain::QQ,
    front=true,
  )
  guard w_front == 2 else { fail("dmp_inject front width mismatch") }
  let ejected = try! dmp_eject(inj_front, w_front, ["x", "y"], Domain::QQ, front=true)
  let ejected_dict = try! dpp_to_dict(ejected, 0)
  guard ejected_dict.length() == 1 else {
    fail("dmp_eject front roundtrip should keep one coefficient poly")
  }

  let bad_eject : Result[DensePolyPoly, PolyError] = try? dmp_eject(
    db_wb_poly([]),
    0,
    ["x", "y"],
    Domain::QQ,
  )
  guard bad_eject is Err(PolyError::BadExponent) else {
    fail("dmp_eject should validate u+1 >= len(gens)")
  }

  let (k, trimmed) = try! dup_terms_gcd([db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)], Domain::ZZ)
  guard k == 2 && trimmed.length() == 1 && trimmed[0].to_string() == "1" else {
    fail("dup_terms_gcd should strip trailing term gcd")
  }

  let (exps, reduced) = try! dmp_terms_gcd(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)]),
    0,
    Domain::ZZ,
  )
  guard exps.length() == 1 && exps[0] == 2 else {
    fail("dmp_terms_gcd exponent vector mismatch")
  }
  let reduced_coeffs = try! dense_to_coeffs(reduced)
  guard reduced_coeffs.length() == 1 && reduced_coeffs[0].to_string() == "1" else {
    fail("dmp_terms_gcd reduced polynomial mismatch")
  }

  let ap1 = try! dup_apply_pairs(
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)],
    [db_wb_fe(4)],
    db_wb_add_pair,
    [],
    Domain::ZZ,
  )
  guard ap1.length() == 3 else { fail("dup_apply_pairs n>m padding mismatch") }
  let ap2 = try! dup_apply_pairs(
    [db_wb_fe(4)],
    [db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)],
    db_wb_add_pair,
    [],
    Domain::ZZ,
  )
  guard ap2.length() == 3 else { fail("dup_apply_pairs n<m padding mismatch") }

  let da = try! dmp_apply_pairs(
    db_wb_poly([db_wb_coef(1), db_wb_coef(2)]),
    db_wb_coef(3),
    db_wb_add_pair,
    [],
    1,
    Domain::ZZ,
  )
  let da_dict = try! dmp_to_dict(da, 1, Domain::ZZ)
  guard da_dict.length() > 0 else { fail("dmp_apply_pairs should produce non-empty output") }

  let s0 = try! dup_slice([db_wb_fe(0), db_wb_fe(0)], 2, 0, Domain::ZZ)
  guard s0.length() == 0 else {
    fail("dup_slice all-zero slice should return []")
  }
  let s1 = try! dup_slice([db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)], 1, 2, Domain::ZZ)
  guard s1.length() > 0 && fe_is_zero(s1[s1.length() - 1]) else {
    fail("dup_slice should append m trailing zeros")
  }

  let bad_slice : Result[DensePoly, PolyError] = try? dmp_slice_in(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(2)]),
    1,
    2,
    2,
    1,
    Domain::ZZ,
  )
  guard bad_slice is Err(PolyError::BadExponent) else {
    fail("dmp_slice_in should validate variable index")
  }
  let sliced_u0 = try! dmp_slice_in(
    dense_from_coeffs([db_wb_fe(1), db_wb_fe(2), db_wb_fe(3)]),
    1,
    3,
    0,
    0,
    Domain::ZZ,
  )
  let sliced_u0_coeffs = try! dense_to_coeffs(sliced_u0)
  guard sliced_u0_coeffs.length() > 0 else {
    fail("dmp_slice_in u=0 branch should delegate to dup_slice")
  }

  let rand_fixed = try! dup_random(3, 0, 0, Domain::ZZ)
  guard !fe_is_zero(rand_fixed[0]) else {
    fail("dup_random should force nonzero leading coefficient")
  }
}

///|
test "densebasic wb: remaining branch sweep for deflate/inflate/dict/pairs helpers" {
  inspect(dup_LC([]), content="0")
  inspect(dup_TC([]), content="0")
  guard (try! dup_copy([])).length() == 0 else { fail("dup_copy([]) should stay empty") }
  inspect(try! dup_nth([], 0), content="0")

  let z_lc = dmp_LC(DensePoly::Poly([]))
  let z_tc = dmp_TC(DensePoly::Poly([]))
  guard z_lc is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_LC([]) should return []")
  }
  guard z_tc is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_TC([]) should return []")
  }
  guard dmp_strip(DensePoly::Coef(db_wb_fe(7))) is DensePoly::Coef(_) else {
    fail("dmp_strip(Coef) should be identity")
  }
  let rev_empty = try! dmp_reverse(DensePoly::Poly([]))
  guard rev_empty is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_reverse([]) should stay []")
  }

  let empty_dict : Map[Monomial, FieldElem] = Map::new()
  guard (try! dup_from_dict(empty_dict, Domain::ZZ)).length() == 0 else {
    fail("dup_from_dict(empty) should return []")
  }
  let bad_uni_dict : Map[Monomial, FieldElem] = Map::new()
  bad_uni_dict.set(Monomial::{ exps: [1, 0] }, db_wb_fe(1))
  let bad_uni_res : Result[Array[FieldElem], PolyError] = try? dup_from_dict(
    bad_uni_dict,
    Domain::ZZ,
  )
  guard bad_uni_res is Err(PolyError::DomainMismatch) else {
    fail("dup_from_dict should reject exponent arity != 1")
  }

  let empty_raw : Map[Int, FieldElem] = Map::new()
  guard (try! dup_from_raw_dict(empty_raw, Domain::ZZ)).length() == 0 else {
    fail("dup_from_raw_dict(empty) should return []")
  }

  let bad_mv_dict : Map[Monomial, FieldElem] = Map::new()
  bad_mv_dict.set(Monomial::{ exps: [2] }, db_wb_fe(1))
  let bad_mv_res : Result[DensePoly, PolyError] = try? dmp_from_dict(
    bad_mv_dict,
    1,
    Domain::ZZ,
  )
  guard bad_mv_res is Err(PolyError::DomainMismatch) else {
    fail("dmp_from_dict should reject wrong monomial length")
  }

  let td_coef = try! dmp_to_dict(DensePoly::Coef(db_wb_fe(4)), 1, Domain::ZZ)
  guard td_coef.length() == 1 else {
    fail("dmp_to_dict(Coef, u>0) should emit zero-exponent monomial")
  }
  guard dmp_to_raw_dict(DensePoly::Coef(db_wb_fe(3)), 1, Domain::ZZ).length() == 0 else {
    fail("dmp_to_raw_dict(Coef) should be empty")
  }

  let sw_bad : Result[DensePoly, PolyError] = try? dmp_swap(
    db_wb_poly([db_wb_coef(1)]),
    -1,
    0,
    0,
    Domain::ZZ,
  )
  guard sw_bad is Err(PolyError::BadExponent) else {
    fail("dmp_swap should validate indices")
  }
  let sw_same = try! dmp_swap(db_wb_poly([db_wb_coef(1)]), 0, 0, 0, Domain::ZZ)
  let sw_same_coeffs = try! dense_to_coeffs(sw_same)
  guard sw_same_coeffs.length() == 1 else {
    fail("dmp_swap(i==j) should be identity")
  }

  let perm_bad : Result[DensePoly, PolyError] = try? dmp_permute(
    db_wb_poly([db_wb_coef(1)]),
    [2],
    0,
    Domain::ZZ,
  )
  guard perm_bad is Err(PolyError::BadExponent) else {
    fail("dmp_permute should reject out-of-range permutation entries")
  }

  guard dmp_nest(db_wb_coef(3), 0, Domain::ZZ) is DensePoly::Coef(_) else {
    fail("dmp_nest with l<=0 should be identity")
  }
  let raised_bad : Result[DensePoly, PolyError] = try? dmp_raise(
    db_wb_poly([db_wb_poly([])]),
    1,
    0,
    Domain::ZZ,
  )
  guard raised_bad is Err(PolyError::NotUnivariate) else {
    fail("dmp_raise(u=0) should reject nested non-univariate coefficients")
  }

  let (g0, _) = dup_deflate([db_wb_fe(2)], Domain::ZZ)
  guard g0 == 1 else { fail("dup_deflate degree<=0 should return multiplier 1") }
  let (dz_b, dz_poly) = try! dmp_deflate(dmp_zero(1), 1, Domain::ZZ)
  guard dz_b.length() == 2 && dmp_zero_p(dz_poly, 1) else {
    fail("dmp_deflate(zero) should return identity multipliers")
  }

  let (md_empty_m, md_empty_out) = dup_multi_deflate([], Domain::ZZ)
  guard md_empty_m == 1 && md_empty_out.length() == 0 else {
    fail("dup_multi_deflate([]) should return identity")
  }
  let (md_const_m, _) = dup_multi_deflate([[db_wb_fe(5)]], Domain::ZZ)
  guard md_const_m == 1 else {
    fail("dup_multi_deflate constant input should short-circuit")
  }

  let dmd_empty = try! dmp_multi_deflate([], 1, Domain::ZZ)
  guard dmd_empty.0.length() == 2 && dmd_empty.1.length() == 0 else {
    fail("dmp_multi_deflate([]) should return identity multipliers")
  }
  let dmd_u0 = try! dmp_multi_deflate(
    [dense_from_coeffs([db_wb_fe(1), db_wb_fe(0), db_wb_fe(1)])],
    0,
    Domain::ZZ,
  )
  guard dmd_u0.0.length() == 1 && dmd_u0.1.length() == 1 else {
    fail("dmp_multi_deflate(u=0) should delegate to dup_multi_deflate")
  }

  let bad_inflate : Result[Array[FieldElem], PolyError] = try? dup_inflate(
    [db_wb_fe(1)],
    0,
    Domain::ZZ,
  )
  guard bad_inflate is Err(PolyError::BadExponent) else {
    fail("dup_inflate should reject non-positive exponent")
  }
  guard (try! dup_inflate([db_wb_fe(1)], 1, Domain::ZZ)).length() == 1 else {
    fail("dup_inflate(m=1) should be identity")
  }

  let bad_mvec : Result[DensePoly, PolyError] = try? dmp_inflate(
    db_wb_poly([db_wb_coef(1)]),
    [0, 1],
    1,
    Domain::ZZ,
  )
  guard bad_mvec is Err(PolyError::BadExponent) else {
    fail("dmp_inflate should validate each inflation exponent")
  }
  let keep_all_one = try! dmp_inflate(db_wb_poly([db_wb_coef(1)]), [1, 1], 1, Domain::ZZ)
  let keep_all_one_dict = try! dmp_to_dict(keep_all_one, 1, Domain::ZZ)
  guard keep_all_one_dict.length() == 1 else {
    fail("dmp_inflate all-one vector should be identity")
  }

  guard dpp_zero(-1) is DensePolyPoly::Poly(items) && items.length() == 0 else {
    fail("dpp_zero(-1) should return []")
  }
  let dpp_nonzero_coeff = try! db_wb_const_poly(1, ["x"], Domain::QQ)
  guard !dpp_zero_p(DensePolyPoly::Poly([DensePolyPoly::Coef(dpp_nonzero_coeff)])) else {
    fail("dpp_zero_p should detect non-zero coefficient polynomials")
  }

  let slice_trim = try! dup_slice([db_wb_fe(0), db_wb_fe(1), db_wb_fe(2)], 1, 3, Domain::ZZ)
  guard slice_trim.length() >= 2 && fe_is_zero(slice_trim[slice_trim.length() - 1]) else {
    fail("dup_slice should trim leading zeros in slice before appending")
  }

  let dmp_ap = try! dmp_apply_pairs(
    db_wb_coef(2),
    db_wb_poly([db_wb_coef(1), db_wb_coef(3)]),
    db_wb_add_pair,
    [],
    1,
    Domain::ZZ,
  )
  let dmp_ap_dict = try! dmp_to_dict(dmp_ap, 1, Domain::ZZ)
  guard dmp_ap_dict.length() > 0 else {
    fail("dmp_apply_pairs should handle Coef-vs-Poly padding")
  }

  let dmp_ap2 = try! dmp_apply_pairs(
    db_wb_poly([db_wb_coef(1)]),
    db_wb_poly([db_wb_coef(2), db_wb_coef(3), db_wb_coef(4)]),
    db_wb_add_pair,
    [],
    1,
    Domain::ZZ,
  )
  let dmp_ap2_dict = try! dmp_to_dict(dmp_ap2, 1, Domain::ZZ)
  guard dmp_ap2_dict.length() > 0 else {
    fail("dmp_apply_pairs should handle n<m padding branch")
  }
}

///|
test "densebasic wb: residual branch sweep (ground/convert/rat/inflate/dpp)" {
  let gf_copy = try! dup_copy([FieldElem::GFp(5, 2)])
  guard gf_copy.length() == 1 && gf_copy[0].to_string() == "2" else {
    fail("dup_copy should keep GFp elements")
  }

  let non_poly_level : Result[(DensePoly, Int), PolyError] = try? dmp_validate(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([DensePoly::Coef(db_wb_fe(2))])]),
  )
  guard non_poly_level is Err(PolyError::NonPolynomial) else {
    fail("dmp_validate should reject mixed-depth dense structures")
  }

  let strip_u0 = try! dense_strip_with_u(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([])]),
    0,
  )
  guard strip_u0 is DensePoly::Poly(_) else {
    fail("dense_strip_with_u(u=0) should preserve non-univariate items")
  }
  let strip_coef_u2 = try! dense_strip_with_u(DensePoly::Coef(db_wb_fe(3)), 2)
  guard strip_coef_u2 is DensePoly::Coef(_) else {
    fail("dense_strip_with_u should keep Coef for u>0")
  }

  inspect(try! dmp_ground_LC(DensePoly::Coef(db_wb_fe(7)), 0), content="7")
  inspect(try! dmp_ground_LC(DensePoly::Coef(db_wb_fe(7)), 1), content="7")
  inspect(try! dmp_ground_LC(DensePoly::Poly([]), 1), content="0")
  inspect(try! dmp_ground_TC(DensePoly::Coef(db_wb_fe(8)), 0), content="8")
  inspect(try! dmp_ground_TC(DensePoly::Coef(db_wb_fe(8)), 1), content="8")
  inspect(try! dmp_ground_TC(DensePoly::Poly([]), 1), content="0")

  let lt_coef_depth = try! dmp_true_LT(DensePoly::Coef(db_wb_fe(2)), 1)
  guard lt_coef_depth.1.to_string() == "2" else {
    fail("dmp_true_LT should return coefficient when encountering Coef before depth end")
  }
  let lt_empty_depth = try! dmp_true_LT(DensePoly::Poly([]), 1)
  guard lt_empty_depth.1.to_string() == "0" else {
    fail("dmp_true_LT should return zero for empty branch")
  }
  let lt_coef_u0 = try! dmp_true_LT(DensePoly::Coef(db_wb_fe(3)), 0)
  guard lt_coef_u0.1.to_string() == "3" else {
    fail("dmp_true_LT(u=0, Coef) mismatch")
  }
  let lt_nested_u0 = try! dmp_true_LT(DensePoly::Poly([DensePoly::Poly([])]), 0)
  guard lt_nested_u0.1.to_string() == "0" else {
    fail("dmp_true_LT should return zero for nested non-coef terminal")
  }

  inspect(dmp_degree(DensePoly::Coef(db_wb_fe(5)), 0), content="0")
  inspect(try! dmp_degree_in(DensePoly::Coef(db_wb_fe(0)), 1, 1), content="-1")
  inspect(try! dmp_degree_in(DensePoly::Coef(db_wb_fe(2)), 1, 1), content="0")

  let norm_u0_nonuni = try! dmp_normal(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([])]),
    0,
  )
  guard norm_u0_nonuni is DensePoly::Poly(_) else {
    fail("dmp_normal(u=0) should tolerate nested items via zero fill")
  }
  let norm_coef_u0 = try! dmp_normal(DensePoly::Coef(db_wb_fe(2)), 0)
  guard norm_coef_u0 is DensePoly::Coef(_) else {
    fail("dmp_normal(u=0, Coef) should be identity")
  }
  let norm_coef_u1 = try! dmp_normal(DensePoly::Coef(db_wb_fe(2)), 1)
  guard norm_coef_u1 is DensePoly::Coef(_) else {
    fail("dmp_normal(u>0, Coef) should be identity")
  }

  let conv_u0_nonuni = try! dmp_convert(
    DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Poly([])]),
    0,
    Domain::ZZ,
    Domain::QQ,
  )
  guard conv_u0_nonuni is DensePoly::Poly(_) else {
    fail("dmp_convert(u=0) should tolerate nested items via zero fill")
  }
  let conv_coef_u0 = try! dmp_convert(DensePoly::Coef(db_wb_fe(1)), 0, Domain::ZZ, Domain::QQ)
  guard conv_coef_u0 is DensePoly::Coef(_) else {
    fail("dmp_convert(u=0, Coef) should convert Coef")
  }
  let conv_coef_u1 = try! dmp_convert(DensePoly::Coef(db_wb_fe(1)), 1, Domain::ZZ, Domain::QQ)
  guard conv_coef_u1 is DensePoly::Coef(_) else {
    fail("dmp_convert(u>0, Coef) should convert Coef")
  }
  let conv_empty = try! dup_convert([], Domain::ZZ, Domain::QQ)
  guard conv_empty.length() == 0 else {
    fail("dup_convert([]) should return []")
  }
  let gfext_sample = FieldElem::GFExt(5, [1], [1, 0, 1])
  let gfext_keep = try! dup_convert(
    [gfext_sample],
    Domain::GFExt(5, 2, [1, 0, 1]),
    Domain::GFExt(5, 2, [1, 0, 1]),
  )
  guard gfext_keep.length() == 1 else {
    fail("dup_convert should handle GFExt sample zero-like initialization")
  }

  let copy_coef_u1 = dmp_copy(DensePoly::Coef(db_wb_fe(7)), 1)
  guard copy_coef_u1 is DensePoly::Coef(_) else {
    fail("dmp_copy(u>0, Coef) should keep coefficient")
  }

  guard (try! dup_from_sympy([], Domain::ZZ)).length() == 0 else {
    fail("dup_from_sympy([]) should return []")
  }
  let rat_coef = try! dense_rat_to_dense(DenseRat::Coef(@symnum.BigRational::from_int(3)), 0, Domain::ZZ)
  guard rat_coef is DensePoly::Poly(_) else {
    fail("dense_rat_to_dense(u=0, Coef) should create dense poly")
  }
  let rat_bad : Result[DensePoly, PolyError] = try? dense_rat_to_dense(
    DenseRat::Poly([DenseRat::Poly([])]),
    0,
    Domain::ZZ,
  )
  guard rat_bad is Err(PolyError::NonPolynomial) else {
    fail("dense_rat_to_dense(u=0) should reject nested dense-rat structures")
  }
  let rat_coef_u1 = try! dense_rat_to_dense(
    DenseRat::Coef(@symnum.BigRational::from_int(4)),
    1,
    Domain::ZZ,
  )
  guard rat_coef_u1 is DensePoly::Poly(_) else {
    fail("dense_rat_to_dense(u>0, Coef) should lift to ground polynomial")
  }

  let nth_coef0 = try! dmp_nth(DensePoly::Coef(db_wb_fe(5)), 0, 1)
  guard nth_coef0 is DensePoly::Coef(_) else {
    fail("dmp_nth(Coef,0) should return Coef")
  }
  let nth_coef_zero = try! dmp_nth(DensePoly::Coef(db_wb_fe(5)), 1, 1)
  guard dmp_zero_p(nth_coef_zero, 0) else {
    fail("dmp_nth(Coef,n>0) should return zero")
  }

  guard dmp_zero(-1) is DensePoly::Poly(items) && items.length() == 0 else {
    fail("dmp_zero(u<0) should return []")
  }
  guard !dmp_zero_p(DensePoly::Coef(db_wb_fe(0)), 1) else {
    fail("dmp_zero_p(u>0, Coef) should be false")
  }

  guard !(try! dmp_ground_p(DensePoly::Coef(db_wb_fe(1)), Some(db_wb_fe(1)), 1)) else {
    fail("dmp_ground_p should reject insufficient nesting when u>0")
  }
  guard (try! dmp_ground_p(DensePoly::Coef(db_wb_fe(1)), None, 0)) else {
    fail("dmp_ground_p(None, Coef) should be true")
  }
  guard !(try! dmp_ground_p(DensePoly::Poly([DensePoly::Poly([])]), Some(db_wb_fe(1)), 0)) else {
    fail("dmp_ground_p(Some) should reject non-coef singleton at u=0")
  }
  guard (try! dmp_ground_p(DensePoly::Coef(db_wb_fe(1)), Some(db_wb_fe(1)), 0)) else {
    fail("dmp_ground_p(Some, Coef) equality branch mismatch")
  }

  inspect(try! dmp_ground_nth(DensePoly::Coef(db_wb_fe(2)), [0], 0, Domain::ZZ), content="2")
  inspect(try! dmp_ground_nth(DensePoly::Coef(db_wb_fe(2)), [1], 0, Domain::ZZ), content="0")
  inspect(try! dmp_ground_nth(DensePoly::Poly([]), [], 0, Domain::ZZ), content="0")
  inspect(
    try! dmp_ground_nth(DensePoly::Poly([DensePoly::Coef(db_wb_fe(1)), DensePoly::Coef(db_wb_fe(2))]), [], 0, Domain::ZZ),
    content="0",
  )
  inspect(
    try! dmp_ground_nth(DensePoly::Poly([DensePoly::Coef(db_wb_fe(9))]), [], 0, Domain::ZZ),
    content="9",
  )

  guard dmp_nest(DensePoly::Coef(db_wb_fe(5)), 2, Domain::ZZ) is DensePoly::Poly(_) else {
    fail("dmp_nest should wrap Coef when l>0")
  }
  let raise_coef_u0 = try! dmp_raise(DensePoly::Coef(db_wb_fe(3)), 1, 0, Domain::ZZ)
  guard raise_coef_u0 is DensePoly::Poly(_) else {
    fail("dmp_raise(u=0, Coef) should lift coefficient")
  }
  let raise_coef_u1 = try! dmp_raise(DensePoly::Coef(db_wb_fe(3)), 1, 1, Domain::ZZ)
  guard raise_coef_u1 is DensePoly::Poly(_) else {
    fail("dmp_raise(u>0, Coef) should lift coefficient")
  }

  let (g_hit1, _) = dup_deflate([db_wb_fe(1), db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)], Domain::ZZ)
  guard g_hit1 == 1 else {
    fail("dup_deflate should early return when gcd of nonzero exponents is 1")
  }
  let (g_le1, _) = dup_deflate([db_wb_fe(0), db_wb_fe(0), db_wb_fe(0), db_wb_fe(1)], Domain::ZZ)
  guard g_le1 == 1 else { fail("dup_deflate g<=1 branch mismatch") }

  let def_map : Map[Monomial, FieldElem] = Map::new()
  def_map.set(Monomial::{ exps: [1, 1] }, db_wb_fe(1))
  def_map.set(Monomial::{ exps: [0, 0] }, db_wb_fe(1))
  let def_dense = try! dmp_from_dict(def_map, 1, Domain::ZZ)
  let def_all_one = try! dmp_deflate(def_dense, 1, Domain::ZZ)
  guard def_all_one.0.length() == 2 && def_all_one.0[0] == 1 && def_all_one.0[1] == 1 else {
    fail("dmp_deflate all-one branch mismatch")
  }
  let def_need_fill_map : Map[Monomial, FieldElem] = Map::new()
  def_need_fill_map.set(Monomial::{ exps: [2, 0] }, db_wb_fe(1))
  def_need_fill_map.set(Monomial::{ exps: [0, 0] }, db_wb_fe(1))
  let def_need_fill = try! dmp_deflate(try! dmp_from_dict(def_need_fill_map, 1, Domain::ZZ), 1, Domain::ZZ)
  guard def_need_fill.0.length() == 2 && def_need_fill.0[0] == 2 && def_need_fill.0[1] == 1 else {
    fail("dmp_deflate should fill zero gcd entries with 1")
  }

  let (g_early1, _) = dup_multi_deflate(
    [[db_wb_fe(1), db_wb_fe(1), db_wb_fe(0)]],
    Domain::ZZ,
  )
  guard g_early1 == 1 else { fail("dup_multi_deflate g==1 early return mismatch") }
  let (g_all_mix, _) = dup_multi_deflate(
    [
      [db_wb_fe(1), db_wb_fe(0), db_wb_fe(1), db_wb_fe(0), db_wb_fe(0)],
      [db_wb_fe(1), db_wb_fe(0), db_wb_fe(0), db_wb_fe(1), db_wb_fe(0), db_wb_fe(0), db_wb_fe(0)],
    ],
    Domain::ZZ,
  )
  guard g_all_mix == 1 else { fail("dup_multi_deflate g_all==1 branch mismatch") }
  let (g_all_zeroish, _) = dup_multi_deflate(
    [
      [db_wb_fe(0), db_wb_fe(0), db_wb_fe(1)],
      [db_wb_fe(0), db_wb_fe(0), db_wb_fe(0), db_wb_fe(2)],
    ],
    Domain::ZZ,
  )
  guard g_all_zeroish == 1 else { fail("dup_multi_deflate g_all<=1 tail branch mismatch") }

  let dmd_map : Map[Monomial, FieldElem] = Map::new()
  dmd_map.set(Monomial::{ exps: [1, 0] }, db_wb_fe(1))
  dmd_map.set(Monomial::{ exps: [0, 1] }, db_wb_fe(1))
  dmd_map.set(Monomial::{ exps: [0, 0] }, db_wb_fe(1))
  let dmd_poly = try! dmp_from_dict(dmd_map, 1, Domain::ZZ)
  let dmd_all_one = try! dmp_multi_deflate([dmd_poly], 1, Domain::ZZ)
  guard dmd_all_one.0[0] == 1 && dmd_all_one.0[1] == 1 else {
    fail("dmp_multi_deflate all-one short-circuit mismatch")
  }

  let rec_empty = try! rec_inflate(DensePoly::Poly([]), [2, 2], 1, 0, Domain::ZZ)
  guard rec_empty is DensePoly::Poly(items) && items.length() == 0 else {
    fail("rec_inflate should preserve empty mapped branches")
  }
  let rec_coef = try! rec_inflate(DensePoly::Coef(db_wb_fe(2)), [2, 2], 1, 0, Domain::ZZ)
  guard rec_coef is DensePoly::Poly(_) else {
    fail("rec_inflate on Coef should lift to ground polynomial")
  }

  let inflated_u0 = try! dmp_inflate(dense_from_coeffs([db_wb_fe(1), db_wb_fe(1)]), [2], 0, Domain::ZZ)
  guard inflated_u0 is DensePoly::Poly(_) else {
    fail("dmp_inflate(u=0) should delegate to dup_inflate")
  }

  let dpp_merge : Map[Monomial, Poly] = Map::new()
  let px = PolyBuilder::new(["x"], Domain::QQ).from_expr(@symcore.symbol("x") + @symcore.int(1))
  let py = PolyBuilder::new(["x"], Domain::QQ).from_expr(@symcore.symbol("x") + @symcore.int(2))
  dpp_merge.set(Monomial::{ exps: [2, 1] }, px)
  dpp_merge.set(Monomial::{ exps: [2, 0] }, py)
  let dpp_poly = try! dpp_from_dict(dpp_merge, 1, ["x"], Domain::QQ)
  guard dpp_poly is DensePolyPoly::Poly(_) else {
    fail("dpp_from_dict should keep non-empty stripped tree")
  }
  let dpp_tree = DensePolyPoly::Poly([DensePolyPoly::Poly([DensePolyPoly::Coef(px)])])
  let dpp_tree_map = try! dpp_to_dict(dpp_tree, 1)
  guard dpp_tree_map.length() == 1 else {
    fail("dpp_to_dict(u>0, Poly) should prepend outer exponents")
  }

  let ex_map : Map[Monomial, FieldElem] = Map::new()
  ex_map.set(Monomial::{ exps: [1, 0] }, db_wb_fe(1))
  ex_map.set(Monomial::{ exps: [0, 1] }, db_wb_fe(1))
  let ex_dense = try! dmp_from_dict(ex_map, 1, Domain::ZZ)
  let ex_none = try! dmp_exclude(ex_dense, 1, Domain::ZZ)
  guard ex_none.0.length() == 0 else {
    fail("dmp_exclude should return empty jlist when all levels are used")
  }

  let terms_early = try! dmp_terms_gcd(dense_from_coeffs([db_wb_fe(1)]), 0, Domain::ZZ)
  guard terms_early.0.length() == 1 && terms_early.0[0] == 0 else {
    fail("dmp_terms_gcd early-return branch mismatch")
  }
}
