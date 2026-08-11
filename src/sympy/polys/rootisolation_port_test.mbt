///|
test "rootisolation: cauchy/mignotte bounds parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  let ours_upper = Show::to_string(@sympolys.dup_cauchy_upper_bound(f, QQ))
  let oracle_upper = dup_cauchy_upper_bound(dup_to_rats(f), domain="QQ")
  assert_eq(ours_upper, oracle_upper)
  let ours_lower = Show::to_string(@sympolys.dup_cauchy_lower_bound(f, QQ))
  let oracle_lower = dup_cauchy_lower_bound(dup_to_rats(f), domain="QQ")
  assert_eq(ours_lower, oracle_lower)
  let ours_m = Show::to_string(@sympolys.dup_mignotte_sep_bound_squared(f, QQ))
  let oracle_m = dup_mignotte_sep_bound_squared(dup_to_rats(f), domain="QQ")
  assert_eq(ours_m, oracle_m)
}

///|
fn dup_list_repr(polys : Array[Array[FieldElem]]) -> String {
  let parts = polys.map(p => dup_repr(p)).join(",")
  "[\{parts}]"
}

///|
test "rootisolation: dup_sturm parity" {
  let f = [feqq(1, 1), feqq(-2, 1), feqq(3, 1), feqq(-5, 1)] // x^3 - 2*x^2 + 3*x - 5
  let ours = dup_list_repr(@sympolys.dup_sturm(f, QQ))
  let oracle = dup_sturm(dup_to_rats(f), domain="QQ")
  assert_eq(ours, oracle)
}

///|
fn interval_repr(a : @symnum.BigRational, b : @symnum.BigRational) -> String {
  "(\{Show::to_string(a)},\{Show::to_string(b)})"
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
) -> String raise {
  match (steps, eps, disjoint) {
    (None, None, None) => {
      let (a, b) = @sympolys.dup_refine_real_root(coeffs, s, t, QQ)
      interval_repr(a, b)
    }
    (Some(k), None, None) => {
      let (a, b) = @sympolys.dup_refine_real_root(coeffs, s, t, QQ, steps=k)
      interval_repr(a, b)
    }
    (None, Some(e), None) => {
      let (a, b) = @sympolys.dup_refine_real_root(coeffs, s, t, QQ, eps=e)
      interval_repr(a, b)
    }
    (None, None, Some(d)) => {
      let (a, b) = @sympolys.dup_refine_real_root(coeffs, s, t, QQ, disjoint=d)
      interval_repr(a, b)
    }
    (Some(k), Some(e), None) => {
      let (a, b) = @sympolys.dup_refine_real_root(
        coeffs,
        s,
        t,
        QQ,
        steps=k,
        eps=e,
      )
      interval_repr(a, b)
    }
    (Some(k), None, Some(d)) => {
      let (a, b) = @sympolys.dup_refine_real_root(
        coeffs,
        s,
        t,
        QQ,
        steps=k,
        disjoint=d,
      )
      interval_repr(a, b)
    }
    (None, Some(e), Some(d)) => {
      let (a, b) = @sympolys.dup_refine_real_root(
        coeffs,
        s,
        t,
        QQ,
        eps=e,
        disjoint=d,
      )
      interval_repr(a, b)
    }
    (Some(k), Some(e), Some(d)) => {
      let (a, b) = @sympolys.dup_refine_real_root(
        coeffs,
        s,
        t,
        QQ,
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
  let oracle0 = dup_refine_real_root(dup_to_rats(f), s, t, steps=0, domain="QQ")
  assert_eq(ours0, oracle0)
  let ours1 = refine_repr(f, s, t, steps=1)
  let oracle1 = dup_refine_real_root(dup_to_rats(f), s, t, steps=1, domain="QQ")
  assert_eq(ours1, oracle1)
  let ours2 = refine_repr(f, s, t, steps=2)
  let oracle2 = dup_refine_real_root(dup_to_rats(f), s, t, steps=2, domain="QQ")
  assert_eq(ours2, oracle2)
  let ours4 = refine_repr(f, s, t, steps=4)
  let oracle4 = dup_refine_real_root(dup_to_rats(f), s, t, steps=4, domain="QQ")
  assert_eq(ours4, oracle4)
  let eps = br_rat(1, 100)
  let ours_eps = refine_repr(f, s, t, eps~)
  let oracle_eps = dup_refine_real_root(dup_to_rats(f), s, t, eps~, domain="QQ")
  assert_eq(ours_eps, oracle_eps)
  let ours_dis = refine_repr(f, s, t, disjoint=br_rat(4, 3))
  let oracle_dis = dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    disjoint=br_rat(4, 3),
    domain="QQ",
  )
  assert_eq(ours_dis, oracle_dis)
}

///|
test "rootisolation: dup_refine_real_root parity (negative)" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)]
  let s = br_int(-2)
  let t = br_int(-1)
  let ours = refine_repr(f, s, t, disjoint=br_rat(-4, 3))
  let oracle = dup_refine_real_root(
    dup_to_rats(f),
    s,
    t,
    disjoint=br_rat(-4, 3),
    domain="QQ",
  )
  assert_eq(ours, oracle)
}

///|
test "rootisolation: compatibility frontdoor parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  let s = br_int(1)
  let t = br_int(2)
  let (a, b) = @sympolys.dup_outer_refine_real_root(f, s, t, QQ, steps=2)
  assert_eq(
    interval_repr(a, b),
    dup_outer_refine_real_root(dup_to_rats(f), s, t, domain="QQ", steps=2),
  )
  assert_eq(
    interval_list_repr(@sympolys.dup_inner_isolate_real_roots(f, QQ)),
    dup_inner_isolate_real_roots(dup_to_rats(f), domain="QQ"),
  )
  assert_eq(
    interval_list_repr(@sympolys.dup_inner_isolate_positive_roots(f, QQ)),
    dup_inner_isolate_positive_roots(dup_to_rats(f), domain="QQ"),
  )
  assert_eq(
    interval_list_repr(@sympolys.dup_inner_isolate_negative_roots(f, QQ)),
    dup_inner_isolate_negative_roots(dup_to_rats(f), domain="QQ"),
  )
}

///|
test "rootisolation: dup_isolate_real_roots_sqf parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  let ours = interval_list_repr(@sympolys.dup_isolate_real_roots_sqf(f, QQ))
  let oracle = dup_isolate_real_roots_sqf(dup_to_rats(f), domain="QQ")
  assert_eq(ours, oracle)
  let g = [feqq(1, 1), feqq(0, 1), feqq(-1, 1)] // x^2 - 1
  let ours_g = interval_list_repr(@sympolys.dup_isolate_real_roots_sqf(g, QQ))
  let oracle_g = dup_isolate_real_roots_sqf(dup_to_rats(g), domain="QQ")
  assert_eq(ours_g, oracle_g)
  let h = [feqq(1, 1), feqq(-6, 1), feqq(11, 1), feqq(-6, 1)] // (x-1)(x-2)(x-3)
  let ours_h = interval_list_repr(@sympolys.dup_isolate_real_roots_sqf(h, QQ))
  let oracle_h = dup_isolate_real_roots_sqf(dup_to_rats(h), domain="QQ")
  assert_eq(ours_h, oracle_h)
  let k = [feqq(1, 1), feqq(0, 1), feqq(-5, 1)] // x^2 - 5
  let ours_k = interval_list_repr(@sympolys.dup_isolate_real_roots_sqf(k, QQ))
  let oracle_k = dup_isolate_real_roots_sqf(dup_to_rats(k), domain="QQ")
  assert_eq(ours_k, oracle_k)
  let m = [feqq(1, 1), feqq(0, 1), feqq(0, 1), feqq(-5, 1)] // x^3 - 5
  let ours_m = interval_list_repr(@sympolys.dup_isolate_real_roots_sqf(m, QQ))
  let oracle_m = dup_isolate_real_roots_sqf(dup_to_rats(m), domain="QQ")
  assert_eq(ours_m, oracle_m)
  let n = [feqq(1, 1), feqq(0, 1), feqq(-5, 1), feqq(0, 1), feqq(4, 1)] // x^4 - 5*x^2 + 4
  let ours_n = interval_list_repr(@sympolys.dup_isolate_real_roots_sqf(n, QQ))
  let oracle_n = dup_isolate_real_roots_sqf(dup_to_rats(n), domain="QQ")
  assert_eq(ours_n, oracle_n)
}

///|
fn interval_mult_list_repr(
  intervals : Array[((@symnum.BigRational, @symnum.BigRational), Int)],
) -> String {
  let parts : Array[String] = Array::new()
  for entry in intervals {
    let ((a, b), mult) = entry
    parts.push("((\{Show::to_string(a)},\{Show::to_string(b)}),\{mult})")
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
fn all_roots_sqf_repr(
  value : (
    Array[@sympolys.RealRootInterval],
    Array[@sympolys.ComplexRootRectangle],
  ),
) -> String {
  let real_part = interval_list_repr(value.0)
  let complex_part = value.1
    .map(rect => {
      "(\{interval_repr(rect.0.0, rect.0.1)},\{interval_repr(rect.1.0, rect.1.1)})"
    })
    .join(",")
  "(\{real_part},[\{complex_part}])"
}

///|
fn all_roots_repr(
  value : (
    Array[(@sympolys.RealRootInterval, Int)],
    Array[(@sympolys.ComplexRootRectangle, Int)],
  ),
) -> String {
  let real_parts : Array[String] = []
  for item in value.0 {
    real_parts.push("(\{interval_repr(item.0.0, item.0.1)},\{item.1})")
  }
  let complex_parts : Array[String] = []
  for item in value.1 {
    let rect = item.0
    complex_parts.push(
      "((\{interval_repr(rect.0.0, rect.0.1)},\{interval_repr(rect.1.0, rect.1.1)}),\{item.1})",
    )
  }
  let real_text = real_parts.join(",")
  let complex_text = complex_parts.join(",")
  "([\{real_text}],[\{complex_text}])"
}

///|
test "rootisolation: dup_isolate_real_roots parity with multiplicities" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-3, 1), feqq(2, 1)] // (x-1)^2*(x+2)
  let ours = interval_mult_list_repr(@sympolys.dup_isolate_real_roots(f, QQ))
  let oracle = dup_isolate_real_roots(dup_to_rats(f), domain="QQ")
  assert_eq(ours, oracle)
}

///|
test "rootisolation: dup_count_real_roots parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-3, 1), feqq(2, 1)] // (x-1)^2*(x+2)
  let ours_all = @sympolys.dup_count_real_roots(f, QQ).to_string()
  let oracle_all = dup_count_real_roots(dup_to_rats(f), domain="QQ")
  assert_eq(ours_all, oracle_all)
  let ours_range = @sympolys.dup_count_real_roots(
    f,
    QQ,
    inf=br_int(0),
    sup=br_int(2),
  ).to_string()
  let oracle_range = dup_count_real_roots(
    dup_to_rats(f),
    domain="QQ",
    inf=br_int(0),
    sup=br_int(2),
  )
  assert_eq(ours_range, oracle_range)
}

///|
test "rootisolation: complex and all-root frontdoors parity on all-real input" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-2, 1)] // x^2 - 2
  assert_eq(
    @sympolys.dup_count_complex_roots(f, QQ).to_string(),
    dup_count_complex_roots(dup_to_rats(f), domain="QQ"),
  )
  assert_eq(
    @sympolys.dup_isolate_complex_roots_sqf(f, QQ).length().to_string(),
    "0",
  )
  assert_eq("[]", dup_isolate_complex_roots_sqf(dup_to_rats(f), domain="QQ"))
  assert_eq(
    all_roots_sqf_repr(@sympolys.dup_isolate_all_roots_sqf(f, QQ)),
    dup_isolate_all_roots_sqf(dup_to_rats(f), domain="QQ"),
  )

  let repeated = [feqq(1, 1), feqq(0, 1), feqq(-4, 1), feqq(0, 1), feqq(4, 1)] // (x^2 - 2)^2
  assert_eq(
    all_roots_repr(@sympolys.dup_isolate_all_roots(repeated, QQ)),
    dup_isolate_all_roots(dup_to_rats(repeated), domain="QQ"),
  )
}
