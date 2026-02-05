///|
test "combinatorics subsets parity" {
  let subset = [2, 3]
  let superset = [1, 2, 3, 4]
  let s = Subset::new(subset, superset)
  assert_oracle(
    try? @sympy_combinatorics.subset_rank_equiv(
      subset,
      superset,
      s.rank_binary(),
      s.rank_lexicographic(),
      s.rank_gray(),
    ),
  )
  let next = s.next_binary().subset()
  let prev = s.prev_binary().subset()
  assert_oracle(
    try? @sympy_combinatorics.subset_next_prev_equiv(
      subset, superset, next, prev,
    ),
  )
  let ks = ksubsets([1, 2, 3, 4], 2)
  assert_oracle(try? @sympy_combinatorics.ksubsets_equiv([1, 2, 3, 4], 2, ks))
}
