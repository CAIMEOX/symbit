///|
fn ri_wb_rat(n : Int, d : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(n, d) catch {
    _ => abort("whitebox test rational expects a nonzero denominator")
  }
}

///|
fn ri_wb_feqq(n : Int, d : Int) -> FieldElem {
  FieldElem::QQ(ri_wb_rat(n, d))
}

///|
fn ri_wb_iv_repr(iv : (@symnum.BigRational, @symnum.BigRational)) -> String {
  let (a, b) = iv
  "(\{a.to_string()},\{b.to_string()})"
}

///|
test "rootisolation wb: helper/error branches" {
  let empty_to_poly : Result[Poly, PolyError] = try? dup_to_poly([], Domain::QQ)
  assert_true(empty_to_poly is Err(PolyError::NonPolynomial))

  let cauchy_short : Result[FieldElem, PolyError] = try? dup_cauchy_lower_bound(
    [ri_wb_feqq(1, 1)],
    Domain::QQ,
  )
  assert_true(cauchy_short is Err(PolyError::BadExponent))

  let mignotte_short : Result[FieldElem, PolyError] = try? dup_mignotte_sep_bound_squared(
    [ri_wb_feqq(1, 1)],
    Domain::QQ,
  )
  assert_true(mignotte_short is Err(PolyError::BadExponent))

  let sturm_const = dup_sturm([ri_wb_feqq(7, 1)], Domain::QQ)
  assert_eq(sturm_const.length(), 1)
  assert_true(
    sturm_const[0].length() == 1 && sturm_const[0][0].to_string() == "1",
  )

  assert_eq(ceil_pos_rational(ri_wb_rat(3, 2)), 2)
  assert_eq(rat_mid(ri_wb_rat(1, 3), ri_wb_rat(2, 3)).to_string(), "1/2")
  assert_true(interval_small(ri_wb_rat(1, 3), ri_wb_rat(2, 3)))
}

///|
test "rootisolation wb: refine edge branches" {
  let f = [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(-2, 1)] // x^2 - 2

  let empty_refine : Result[
    (@symnum.BigRational, @symnum.BigRational),
    PolyError,
  ] = try? dup_refine_real_root(
    [],
    ri_wb_rat(1, 1),
    ri_wb_rat(2, 1),
    Domain::QQ,
  )
  assert_true(empty_refine is Err(PolyError::NonPolynomial))

  let same = dup_refine_real_root(
    f,
    ri_wb_rat(1, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
  )
  assert_eq(ri_wb_iv_repr(same), "(1,1)")

  let swapped = dup_refine_real_root(
    f,
    ri_wb_rat(2, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
    steps=0,
  )
  assert_true(swapped.0.compare(swapped.1) <= 0)

  let with_root_left = dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(-1, 1)], // x^2 - 1
    ri_wb_rat(1, 1),
    ri_wb_rat(2, 1),
    Domain::QQ,
  )
  assert_eq(ri_wb_iv_repr(with_root_left), "(1,1)")

  let with_root_right = dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(-1, 1)], // x^2 - 1
    ri_wb_rat(0, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
  )
  assert_eq(ri_wb_iv_repr(with_root_right), "(1,1)")

  let no_root = dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(1, 1)], // x^2 + 1
    ri_wb_rat(-1, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
  )
  assert_eq(ri_wb_iv_repr(no_root), "(-1,1)")

  let mediant_root = dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(-1, 1)], // x - 1
    ri_wb_rat(1, 2),
    ri_wb_rat(3, 2),
    Domain::QQ,
    steps=5,
  )
  assert_eq(ri_wb_iv_repr(mediant_root), "(1,1)")

  let default_refine = dup_refine_real_root(
    f,
    ri_wb_rat(1, 1),
    ri_wb_rat(2, 1),
    Domain::QQ,
  )
  assert_true(default_refine.0.compare(default_refine.1) <= 0)
}

///|
test "rootisolation wb: isolate_sturm endpoint handling and empty isolates" {
  let f = [ri_wb_feqq(1, 1), ri_wb_feqq(-1, 1), ri_wb_feqq(0, 1)] // x*(x-1)
  let seq = dup_sturm(f, Domain::QQ)
  let intervals : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  isolate_sturm(f, seq, ri_wb_rat(0, 1), ri_wb_rat(1, 1), intervals, true, true)
  let rendered = intervals.map(iv => ri_wb_iv_repr(iv)).join(",")
  assert_true(rendered.contains("(0,0)") && rendered.contains("(1,1)"))

  let sqf_empty = dup_isolate_real_roots_sqf([ri_wb_feqq(3, 1)], Domain::QQ)
  assert_eq(sqf_empty.length(), 0)
  let full_empty = dup_isolate_real_roots([ri_wb_feqq(3, 1)], Domain::QQ)
  assert_eq(full_empty.length(), 0)
}
