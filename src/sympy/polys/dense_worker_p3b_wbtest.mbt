///|
fn p3b_int(value : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(value)
}

///|
fn p3b_rat(numerator : Int, denominator : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_ints(numerator, denominator) catch {
    _ => abort("P3b test rational expects a nonzero denominator")
  }
}

///|
test "polys P3b worker preserves root-refinement option presence" {
  let coeffs = [p3b_int(1), p3b_int(0), p3b_int(-2)]
  let base_args = [
    DupCoeffs(coeffs),
    DomainNumber(p3b_int(1)),
    DomainNumber(p3b_int(2)),
    DomainObject,
  ]
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_refine_real_root",
      base_args,
      "QQ",
      kwargs={ "steps": CallInt(0) },
    ),
    "(1,2)",
  )
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_refine_real_root",
      base_args,
      "QQ",
      kwargs={ "eps": DomainNumber(p3b_rat(1, 100)) },
    ),
    "(24/17,17/12)",
  )
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_refine_real_root",
      base_args,
      "QQ",
      kwargs={ "disjoint": DomainNumber(p3b_rat(4, 3)) },
    ),
    "(4/3,3/2)",
  )
}

///|
test "polys P3b worker preserves independent root-count endpoints" {
  let args = [DupCoeffs([p3b_int(1), p3b_int(0), p3b_int(-2)]), DomainObject]
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_count_real_roots",
      args,
      "QQ",
      result_kind=ScalarResult,
    ),
    "2",
  )
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_count_real_roots",
      args,
      "QQ",
      kwargs={ "inf": DomainNumber(p3b_int(0)) },
      result_kind=ScalarResult,
    ),
    "1",
  )
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_count_real_roots",
      args,
      "QQ",
      kwargs={ "sup": DomainNumber(p3b_int(0)) },
      result_kind=ScalarResult,
    ),
    "1",
  )
}

///|
test "polys P3b worker renders nested complex root rectangles" {
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_isolate_complex_roots_sqf",
      [DupCoeffs([p3b_int(1), p3b_int(0), p3b_int(1)]), DomainObject],
      "QQ",
    ),
    "[((0,-2),(2,0)),((0,0),(2,2))]",
  )
}

///|
test "polys P3b worker renders dense Fateman triples" {
  assert_eq(
    polys_prefix_recipe_call(
      "specialpolys",
      "dmp_fateman_poly_F_1",
      [CallInt(1), DomainObject],
      "ZZ",
    ),
    "([[1],[2,3],[1,3,2]],[[-3,0],[],[-3,1,-3,-1],[],[1,0,0,0,-1]],[[1]])",
  )
}

///|
test "polys P3b worker converts orthogonal polynomial parameters" {
  assert_eq(
    polys_prefix_recipe_call(
      "orthopolys",
      "dup_jacobi",
      [
        CallInt(1),
        DomainNumber(p3b_int(1)),
        DomainNumber(p3b_int(2)),
        DomainObject,
      ],
      "QQ",
    ),
    "[5/2,-1/2]",
  )
  assert_eq(
    polys_prefix_recipe_call(
      "orthopolys",
      "dup_spherical_bessel_fn_minus",
      [CallInt(4), DomainObject],
      "ZZ",
    ),
    "[-15,0,1,0]",
  )
}

///|
test "polys P3b worker renders Appell sequence coefficients" {
  assert_eq(
    polys_prefix_recipe_call(
      "appellseqs",
      "dup_bernoulli",
      [CallInt(1), DomainObject],
      "QQ",
    ),
    "[1,-1/2]",
  )
  assert_eq(
    polys_prefix_recipe_call(
      "appellseqs",
      "dup_genocchi",
      [CallInt(5), DomainObject],
      "ZZ",
    ),
    "[-5,10,0,-5,0]",
  )
}

///|
test "polys P3b worker rejects None then recovers" {
  let rejected = try {
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_root_upper_bound",
      [DupCoeffs([]), DomainObject],
      "ZZ",
    )
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(
    polys_prefix_recipe_call(
      "rootisolation",
      "dup_root_upper_bound",
      [DupCoeffs([p3b_int(1), p3b_int(0), p3b_int(-2)]), DomainObject],
      "ZZ",
    ),
    "4",
  )
}
