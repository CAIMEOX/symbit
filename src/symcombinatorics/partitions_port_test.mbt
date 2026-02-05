///|
test "combinatorics integer partitions parity" {
  let ip = IntegerPartition::new([6, 3, 3, 2, 1])
  assert_oracle(try? @sympy_combinatorics.integer_partition_conjugate_equiv(
    ip.partition,
    ip.conjugate(),
  ))

  let ip2 = IntegerPartition::new([3, 1])
  let nxt = ip2.next_lex().partition
  let prv = ip2.prev_lex().partition
  assert_oracle(try? @sympy_combinatorics.integer_partition_next_prev_equiv(
    ip2.partition,
    nxt,
    prv,
  ))
}

///|
test "combinatorics rgs parity" {
  let rgs = [0, 1, 2, 1, 3]
  assert_oracle(try? @sympy_combinatorics.rgs_rank_equiv(rgs, rgs_rank(rgs)))
  let unranked = rgs_unrank(4, 7)
  assert_oracle(try? @sympy_combinatorics.rgs_unrank_equiv(4, 7, unranked))
}

///|
test "combinatorics partition parity" {
  let blocks = [[1, 2], [3], [4, 5]]
  let p = Partition::new(blocks)
  assert_oracle(try? @sympy_combinatorics.partition_rgs_equiv(
    blocks,
    p.rgs(),
    p.rank(),
  ))
}
