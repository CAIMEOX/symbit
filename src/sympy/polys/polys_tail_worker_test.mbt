///|
test "polys P6g matrix HNF preserves empty shapes and rejects ragged rows" {
  assert_eq(matrix_hnf_code([]), "")
  assert_eq(matrix_hnf_code([[]]), "")
  assert_eq(
    matrix_hnf_code([[12, 6, 4], [3, 9, 6], [2, 16, 14]]),
    "10,0,2;0,15,3;0,0,2",
  )
  let rejected = try {
    matrix_hnf_code([[1], [2, 3]]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(matrix_hnf_code([[1]]), "1")
}

///|
test "polys P6g DomainScalar preserves construct-domain shape" {
  assert_eq(domainscalar_from_expr("1/2"), "1/2@QQ")
  assert_eq(domainscalar_from_expr("x + 1"), "x + 1@ZZ[x]")
  let rejected = try {
    domainscalar_from_expr("None") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(domainscalar_from_expr("3"), "3@ZZ")
}

///|
test "polys P6g construct domain keeps expression data and shared identity" {
  assert_eq(construct_domain_domain([]), "ZZ")
  assert_eq(construct_domain_domain([Symbol("x y,z")]), "ZZ[x y,z]")
  let dummy = @symcore.Expr::Dummy("d", 2601)
  assert_eq(construct_domain_domain([dummy, dummy]), "ZZ[_d]")
}

///|
test "polys P6g sorts singleton factors with compact codecs" {
  assert_eq(sort_factors([]), "[]")
  assert_eq(sort_factors([[3, 2, 1]]), "[[3,2,1]]")
  assert_eq(sort_factors([[2], [1, 0], [1]]), "[[1],[2],[1,0]]")
}

///|
test "polys P6g sorts factors with multiplicities" {
  assert_eq(sort_factors_multiple([]), "[]")
  assert_eq(
    sort_factors_multiple([([1, 0], 2), ([2], 3), ([1], 1)]),
    "[([1],1),([2],3),([1,0],2)]",
  )
}

///|
test "polys P6g normal ANP preserves domain and normalized shape" {
  assert_eq(
    init_normal_ANP([0, 1, 0], [1, 0, -2]),
    "ANP([1, 0], [1, 0, -2], QQ)",
  )
  assert_eq(
    init_normal_ANP([0, 1, 0], [1, 0, -2], domain="ZZ"),
    "ANP([1, 0], [1, 0, -2], ZZ)",
  )
  let rejected = try {
    init_normal_ANP([1], [1, 0, -2], domain="missing domain") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(init_normal_ANP([1], [1, 0, -2]), "ANP([1], [1, 0, -2], QQ)")
}

///|
test "polys P6g factor repr rejects malformed None and recovers" {
  assert_eq(
    sympy_sort_factor_repr("(1, [(x - 1, 1), (x + 1, 2)])"),
    "(1, [(x + 1, 2),(x - 1, 1)])",
  )
  for malformed in ["None", "1", "(1, [()])", "(1, [(x, None)])"] {
    let rejected = try {
      sympy_sort_factor_repr(malformed) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_eq(sympy_sort_factor_repr("(2, [])"), "(2, [])")
}
