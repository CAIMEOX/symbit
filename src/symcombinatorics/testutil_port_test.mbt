///|
test "testutil cmp perm lists" {
  let a = Permutation::from_array([1, 0])
  let b = Permutation::from_array([0, 1])
  assert_true(_cmp_perm_lists([a, b], [b, a]))
}

///|
test "testutil verify centralizer/normal closure" {
  let g = cyclic_group(3)
  assert_true(_verify_centralizer(g, g))
  assert_true(_verify_normal_closure(g, g))
}
