///|
fn ri_wb_rat(n : Int, d : Int) -> @symnum.BigRational {
  try! @symnum.BigRational::new(BigInt::from_int(n), BigInt::from_int(d))
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
  guard empty_to_poly is Err(PolyError::NonPolynomial) else {
    fail("dup_to_poly([]) should raise NonPolynomial")
  }

  let cauchy_short : Result[FieldElem, PolyError] = try? dup_cauchy_lower_bound(
    [ri_wb_feqq(1, 1)],
    Domain::QQ,
  )
  guard cauchy_short is Err(PolyError::BadExponent) else {
    fail("dup_cauchy_lower_bound short input should raise BadExponent")
  }

  let mignotte_short : Result[FieldElem, PolyError] = try? dup_mignotte_sep_bound_squared(
    [ri_wb_feqq(1, 1)],
    Domain::QQ,
  )
  guard mignotte_short is Err(PolyError::BadExponent) else {
    fail("dup_mignotte_sep_bound_squared short input should raise BadExponent")
  }

  let sturm_const = try! dup_sturm([ri_wb_feqq(7, 1)], Domain::QQ)
  guard sturm_const.length() == 1 else { fail("constant sturm size mismatch") }
  guard sturm_const[0].length() == 1 && sturm_const[0][0].to_string() == "1" else {
    fail("constant sturm should return [[1]]")
  }

  guard ceil_pos_rational(ri_wb_rat(3, 2)) == 2 else {
    fail("ceil_pos_rational should round 3/2 to 2")
  }
  guard rat_mid(ri_wb_rat(1, 3), ri_wb_rat(2, 3)).to_string() == "1/2" else {
    fail("rat_mid non-integral branch mismatch")
  }
  guard interval_small(ri_wb_rat(1, 3), ri_wb_rat(2, 3)) else {
    fail("interval_small non-integral branch should be true")
  }
}

///|
test "rootisolation wb: refine edge branches" {
  let f = [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(-2, 1)] // x^2 - 2

  let empty_refine : Result[(@symnum.BigRational, @symnum.BigRational), PolyError] =
    try? dup_refine_real_root([], ri_wb_rat(1, 1), ri_wb_rat(2, 1), Domain::QQ)
  guard empty_refine is Err(PolyError::NonPolynomial) else {
    fail("refine([]) should raise NonPolynomial")
  }

  let same = try! dup_refine_real_root(
    f,
    ri_wb_rat(1, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
  )
  guard ri_wb_iv_repr(same) == "(1,1)" else { fail("refine s==t mismatch") }

  let swapped = try! dup_refine_real_root(
    f,
    ri_wb_rat(2, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
    steps=0,
  )
  guard swapped.0.compare(swapped.1) <= 0 else { fail("refine should reorder bounds") }

  let with_root_left = try! dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(-1, 1)], // x^2 - 1
    ri_wb_rat(1, 1),
    ri_wb_rat(2, 1),
    Domain::QQ,
  )
  guard ri_wb_iv_repr(with_root_left) == "(1,1)" else {
    fail("refine left-endpoint root mismatch")
  }

  let with_root_right = try! dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(-1, 1)], // x^2 - 1
    ri_wb_rat(0, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
  )
  guard ri_wb_iv_repr(with_root_right) == "(1,1)" else {
    fail("refine right-endpoint root mismatch")
  }

  let no_root = try! dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(0, 1), ri_wb_feqq(1, 1)], // x^2 + 1
    ri_wb_rat(-1, 1),
    ri_wb_rat(1, 1),
    Domain::QQ,
  )
  guard ri_wb_iv_repr(no_root) == "(-1,1)" else {
    fail("refine no-root interval should be returned unchanged")
  }

  let mediant_root = try! dup_refine_real_root(
    [ri_wb_feqq(1, 1), ri_wb_feqq(-1, 1)], // x - 1
    ri_wb_rat(1, 2),
    ri_wb_rat(3, 2),
    Domain::QQ,
    steps=5,
  )
  guard ri_wb_iv_repr(mediant_root) == "(1,1)" else {
    fail("refine mediant-root branch mismatch")
  }

  let default_refine = try! dup_refine_real_root(
    f,
    ri_wb_rat(1, 1),
    ri_wb_rat(2, 1),
    Domain::QQ,
  )
  guard default_refine.0.compare(default_refine.1) <= 0 else {
    fail("default refine should return a valid interval")
  }
}

///|
test "rootisolation wb: isolate_sturm endpoint handling and empty isolates" {
  let f = [ri_wb_feqq(1, 1), ri_wb_feqq(-1, 1), ri_wb_feqq(0, 1)] // x*(x-1)
  let seq = try! dup_sturm(f, Domain::QQ)
  let intervals : Array[(@symnum.BigRational, @symnum.BigRational)] = Array::new()
  try! isolate_sturm(
    f,
    seq,
    ri_wb_rat(0, 1),
    ri_wb_rat(1, 1),
    intervals,
    true,
    true,
  )
  let rendered = intervals.map(iv => ri_wb_iv_repr(iv)).join(",")
  guard rendered.contains("(0,0)") && rendered.contains("(1,1)") else {
    fail("isolate_sturm should keep endpoint roots when included")
  }

  let sqf_empty = try! dup_isolate_real_roots_sqf([ri_wb_feqq(3, 1)], Domain::QQ)
  guard sqf_empty.length() == 0 else {
    fail("dup_isolate_real_roots_sqf(constant) should be empty")
  }
  let full_empty = try! dup_isolate_real_roots([ri_wb_feqq(3, 1)], Domain::QQ)
  guard full_empty.length() == 0 else {
    fail("dup_isolate_real_roots(constant) should be empty")
  }
}
