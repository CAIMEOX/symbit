///|
test "rootisolation: cauchy/mignotte bounds parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  let ours_upper = dup_cauchy_upper_bound(f, Domain::QQ).to_string()
  let oracle_upper = @sympy_polys.dup_cauchy_upper_bound(
    dup_to_rats(f),
    domain="QQ",
  )
  guard ours_upper == oracle_upper else { fail("cauchy upper mismatch") }
  let ours_lower = dup_cauchy_lower_bound(f, Domain::QQ).to_string()
  let oracle_lower = @sympy_polys.dup_cauchy_lower_bound(
    dup_to_rats(f),
    domain="QQ",
  )
  guard ours_lower == oracle_lower else { fail("cauchy lower mismatch") }
  let ours_m = dup_mignotte_sep_bound_squared(f, Domain::QQ).to_string()
  let oracle_m = @sympy_polys.dup_mignotte_sep_bound_squared(
    dup_to_rats(f),
    domain="QQ",
  )
  guard ours_m == oracle_m else { fail("mignotte bound mismatch") }
}

///|
fn dup_list_repr(polys : Array[Array[FieldElem]]) -> String {
  let parts = polys.map(p => dup_repr(p)).join(",")
  "[\{parts}]"
}

///|
test "rootisolation: dup_sturm parity" {
  let f = [feqq(1, 1), feqq(-2, 1), feqq(3, 1), feqq(-5, 1)] // x^3 - 2*x^2 + 3*x - 5
  let ours = dup_list_repr(dup_sturm(f, Domain::QQ))
  let oracle = @sympy_polys.dup_sturm(dup_to_rats(f), domain="QQ")
  guard ours == oracle else { fail("dup_sturm mismatch") }
}

///|
fn interval_repr(a : @symnum.BigRational, b : @symnum.BigRational) -> String {
  "(\{a.to_string()},\{b.to_string()})"
}

///|
fn interval_list_repr(
  intervals : Array[(@symnum.BigRational, @symnum.BigRational)],
) -> String {
  let parts : Array[String] = Array::new()
  for pair in intervals {
    let (a, b) = pair
    parts.push(interval_repr(a, b))
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn refine_repr(
  coeffs : Array[FieldElem],
  s : @symnum.BigRational,
  t : @symnum.BigRational,
  steps? : Int,
  eps? : @symnum.BigRational,
  disjoint? : @symnum.BigRational,
) -> String {
  match (steps, eps, disjoint) {
    (None, None, None) => {
      let (a, b) = try! dup_refine_real_root(coeffs, s, t, Domain::QQ)
      interval_repr(a, b)
    }
    (Some(k), None, None) => {
      let (a, b) = try! dup_refine_real_root(coeffs, s, t, Domain::QQ, steps=k)
      interval_repr(a, b)
    }
    (None, Some(e), None) => {
      let (a, b) = try! dup_refine_real_root(coeffs, s, t, Domain::QQ, eps=e)
      interval_repr(a, b)
    }
    (None, None, Some(d)) => {
      let (a, b) = try! dup_refine_real_root(
        coeffs,
        s,
        t,
        Domain::QQ,
        disjoint=d,
      )
      interval_repr(a, b)
    }
    (Some(k), Some(e), None) => {
      let (a, b) = try! dup_refine_real_root(
        coeffs,
        s,
        t,
        Domain::QQ,
        steps=k,
        eps=e,
      )
      interval_repr(a, b)
    }
    (Some(k), None, Some(d)) => {
      let (a, b) = try! dup_refine_real_root(
        coeffs,
        s,
        t,
        Domain::QQ,
        steps=k,
        disjoint=d,
      )
      interval_repr(a, b)
    }
    (None, Some(e), Some(d)) => {
      let (a, b) = try! dup_refine_real_root(
        coeffs,
        s,
        t,
        Domain::QQ,
        eps=e,
        disjoint=d,
      )
      interval_repr(a, b)
    }
    (Some(k), Some(e), Some(d)) => {
      let (a, b) = try! dup_refine_real_root(
        coeffs,
        s,
        t,
        Domain::QQ,
        steps=k,
        eps=e,
        disjoint=d,
      )
      interval_repr(a, b)
    }
  }
}

///|
test "rootisolation: dup_refine_real_root parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  let s = br_int(1)
  let t = br_int(2)
  let ours0 = refine_repr(f, s, t, steps=0)
  let oracle0 = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    steps=0,
    domain="QQ",
  )
  guard ours0 == oracle0 else { fail("refine steps=0 mismatch") }
  let ours1 = refine_repr(f, s, t, steps=1)
  let oracle1 = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    steps=1,
    domain="QQ",
  )
  guard ours1 == oracle1 else { fail("refine steps=1 mismatch") }
  let ours2 = refine_repr(f, s, t, steps=2)
  let oracle2 = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    steps=2,
    domain="QQ",
  )
  guard ours2 == oracle2 else { fail("refine steps=2 mismatch") }
  let ours4 = refine_repr(f, s, t, steps=4)
  let oracle4 = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    steps=4,
    domain="QQ",
  )
  guard ours4 == oracle4 else { fail("refine steps=4 mismatch") }
  let eps = br_rat(1, 100)
  let ours_eps = refine_repr(f, s, t, eps~)
  let oracle_eps = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    eps~,
    domain="QQ",
  )
  guard ours_eps == oracle_eps else { fail("refine eps mismatch") }
  let ours_dis = refine_repr(f, s, t, disjoint=br_rat(4, 3))
  let oracle_dis = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    disjoint=br_rat(4, 3),
    domain="QQ",
  )
  guard ours_dis == oracle_dis else {
    fail("refine disjoint mismatch: ours=\{ours_dis}, oracle=\{oracle_dis}")
  }
}

///|
test "rootisolation: dup_refine_real_root parity (negative)" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)]
  let s = br_int(-2)
  let t = br_int(-1)
  let ours = refine_repr(f, s, t, disjoint=br_rat(-4, 3))
  let oracle = @sympy_polys.dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    disjoint=br_rat(-4, 3),
    domain="QQ",
  )
  guard ours == oracle else {
    fail("refine negative disjoint mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "rootisolation: dup_isolate_real_roots_sqf parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  let ours = interval_list_repr(dup_isolate_real_roots_sqf(f, Domain::QQ))
  let oracle = @sympy_polys.dup_isolate_real_roots_sqf(
    dup_to_rats(f),
    domain="QQ",
  )
  guard ours == oracle else { fail("isolate x^2-2 mismatch") }
  let g = [feqq(1, 1), feqq(0, 1), feqq(-1, 1)] // x^2 - 1
  let ours_g = interval_list_repr(dup_isolate_real_roots_sqf(g, Domain::QQ))
  let oracle_g = @sympy_polys.dup_isolate_real_roots_sqf(
    dup_to_rats(g),
    domain="QQ",
  )
  guard ours_g == oracle_g else { fail("isolate x^2-1 mismatch") }
  let h = [feqq(1, 1), feqq(-6, 1), feqq(11, 1), feqq(-6, 1)] // (x-1)(x-2)(x-3)
  let ours_h = interval_list_repr(dup_isolate_real_roots_sqf(h, Domain::QQ))
  let oracle_h = @sympy_polys.dup_isolate_real_roots_sqf(
    dup_to_rats(h),
    domain="QQ",
  )
  guard ours_h == oracle_h else {
    fail("isolate cubic mismatch: ours=\{ours_h}, oracle=\{oracle_h}")
  }
  let k = [feqq(1, 1), feqq(0, 1), feqq(-5, 1)] // x^2 - 5
  let ours_k = interval_list_repr(dup_isolate_real_roots_sqf(k, Domain::QQ))
  let oracle_k = @sympy_polys.dup_isolate_real_roots_sqf(
    dup_to_rats(k),
    domain="QQ",
  )
  guard ours_k == oracle_k else { fail("isolate x^2-5 mismatch") }
  let m = [feqq(1, 1), feqq(0, 1), feqq(0, 1), feqq(-5, 1)] // x^3 - 5
  let ours_m = interval_list_repr(dup_isolate_real_roots_sqf(m, Domain::QQ))
  let oracle_m = @sympy_polys.dup_isolate_real_roots_sqf(
    dup_to_rats(m),
    domain="QQ",
  )
  guard ours_m == oracle_m else { fail("isolate x^3-5 mismatch") }
  let n = [feqq(1, 1), feqq(0, 1), feqq(-5, 1), feqq(0, 1), feqq(4, 1)] // x^4 - 5*x^2 + 4
  let ours_n = interval_list_repr(dup_isolate_real_roots_sqf(n, Domain::QQ))
  let oracle_n = @sympy_polys.dup_isolate_real_roots_sqf(
    dup_to_rats(n),
    domain="QQ",
  )
  guard ours_n == oracle_n else { fail("isolate quartic mismatch") }
}
