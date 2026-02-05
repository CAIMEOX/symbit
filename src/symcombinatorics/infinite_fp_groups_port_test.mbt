///|
test "free group isomorphism by rank" {
  let (g1, _) = free_group("a, b")
  let (g2, _) = free_group("x")
  assert_true(is_isomorphic(HomGroup::FreeGroup(g1), HomGroup::FreeGroup(g1)))
  assert_true(!is_isomorphic(HomGroup::FreeGroup(g1), HomGroup::FreeGroup(g2)))
}

///|
test "free group vs abelian fp group not isomorphic" {
  let (f, gens) = free_group("a, b")
  let a = gens[0]
  let b = gens[1]
  let free_fp = vfp_group(f, [])
  let comm = a.mul(b).mul(a.inverse()).mul(b.inverse())
  let abelian_fp = vfp_group(f, [comm])
  assert_true(
    !is_isomorphic(HomGroup::FpGroup(free_fp), HomGroup::FpGroup(abelian_fp)),
  )
}

///|
test "abelian fp group isomorphism via invariants" {
  let (f1, gens1) = free_group("a, b")
  let a = gens1[0]
  let b = gens1[1]
  let comm1 = a.mul(b).mul(a.inverse()).mul(b.inverse())
  let g1 = vfp_group(f1, [comm1])
  let (f2, gens2) = free_group("x, y")
  let x = gens2[0]
  let y = gens2[1]
  let comm2 = x.mul(y).mul(x.inverse()).mul(y.inverse())
  let g2 = vfp_group(f2, [comm2])
  let (ok, _) = group_isomorphism(HomGroup::FpGroup(g1), HomGroup::FpGroup(g2))
  assert_true(ok)
}
