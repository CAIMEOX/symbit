///|
test "combinatorics prufer parity" {
  let seq = [1, 0, 0]
  let p = Prufer::from_sequence(seq)
  let tree = p.tree_repr()
  assert_oracle(try? @sympy_combinatorics.prufer_equiv_tree(seq, tree))
  assert_oracle(try? @sympy_combinatorics.prufer_rank_equiv(seq, p.rank()))

  let edges = [[0, 3], [1, 3], [2, 3], [3, 4], [4, 5]]
  let p2 = Prufer::from_edges(edges)
  let seq2 = p2.prufer_repr()
  assert_oracle(try? @sympy_combinatorics.prufer_equiv_sequence(edges, seq2))
}
